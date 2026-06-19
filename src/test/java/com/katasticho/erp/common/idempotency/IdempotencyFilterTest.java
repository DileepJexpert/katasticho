package com.katasticho.erp.common.idempotency;

import com.katasticho.erp.common.context.TenantContext;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class IdempotencyFilterTest {

    @Mock
    private IdempotencyRecordRepository repository;
    @Mock
    private FilterChain chain;

    private IdempotencyFilter filter;
    private UUID orgId;

    @BeforeEach
    void setUp() {
        filter = new IdempotencyFilter(repository);
        orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private MockHttpServletRequest post(String key) {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/v1/sales-receipts");
        if (key != null) {
            request.addHeader(IdempotencyFilter.HEADER, key);
        }
        return request;
    }

    private IdempotencyRecord completedRecord(String key) {
        return IdempotencyRecord.builder()
                .id(UUID.randomUUID()).orgId(orgId).idempotencyKey(key)
                .requestMethod("POST").requestPath("/api/v1/sales-receipts")
                .status(IdempotencyRecord.STATUS_COMPLETED)
                .responseStatus(200).responseBody("{\"success\":true,\"data\":{\"id\":\"abc\"}}")
                .createdAt(Instant.now()).expiresAt(Instant.now().plusSeconds(3600))
                .build();
    }

    @Test
    void requestWithoutHeaderPassesThroughUntouched() throws Exception {
        MockHttpServletResponse response = new MockHttpServletResponse();
        filter.doFilterInternal(post(null), response, chain);

        verify(chain).doFilter(any(), any());
        verifyNoInteractions(repository);
    }

    @Test
    void getRequestIsNeverIntercepted() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/invoices");
        request.addHeader(IdempotencyFilter.HEADER, "key-1");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilterInternal(request, response, chain);

        verify(chain).doFilter(any(), any());
        verifyNoInteractions(repository);
    }

    @Test
    void duplicateKeyReplaysStoredResponseWithoutExecuting() throws Exception {
        when(repository.findByOrgIdAndIdempotencyKey(orgId, "dup-1"))
                .thenReturn(Optional.of(completedRecord("dup-1")));
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilterInternal(post("dup-1"), response, chain);

        verify(chain, never()).doFilter(any(), any());
        assertEquals(200, response.getStatus());
        assertEquals("true", response.getHeader("X-Idempotency-Replay"));
        assertTrue(response.getContentAsString().contains("\"id\":\"abc\""));
    }

    @Test
    void inProgressKeyReturnsConflict() throws Exception {
        IdempotencyRecord inProgress = completedRecord("busy-1");
        inProgress.setStatus(IdempotencyRecord.STATUS_IN_PROGRESS);
        when(repository.findByOrgIdAndIdempotencyKey(orgId, "busy-1")).thenReturn(Optional.of(inProgress));
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilterInternal(post("busy-1"), response, chain);

        verify(chain, never()).doFilter(any(), any());
        assertEquals(409, response.getStatus());
    }

    @Test
    void firstRequestExecutesAndStoresResponse() throws Exception {
        when(repository.findByOrgIdAndIdempotencyKey(orgId, "new-1")).thenReturn(Optional.empty());
        when(repository.saveAndFlush(any())).thenAnswer(inv -> inv.getArgument(0));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        org.mockito.Mockito.doAnswer(inv -> {
            jakarta.servlet.http.HttpServletResponse res = inv.getArgument(1);
            res.setStatus(201);
            res.getWriter().write("{\"success\":true}");
            return null;
        }).when(chain).doFilter(any(), any());

        MockHttpServletResponse response = new MockHttpServletResponse();
        filter.doFilterInternal(post("new-1"), response, chain);

        assertEquals(201, response.getStatus());
        assertEquals("{\"success\":true}", response.getContentAsString());

        org.mockito.ArgumentCaptor<IdempotencyRecord> captor =
                org.mockito.ArgumentCaptor.forClass(IdempotencyRecord.class);
        verify(repository).save(captor.capture());
        assertEquals(IdempotencyRecord.STATUS_COMPLETED, captor.getValue().getStatus());
        assertEquals(201, captor.getValue().getResponseStatus());
        assertEquals("{\"success\":true}", captor.getValue().getResponseBody());
    }

    @Test
    void serverErrorReleasesKeySoCallerCanRetry() throws Exception {
        when(repository.findByOrgIdAndIdempotencyKey(orgId, "err-1")).thenReturn(Optional.empty());
        when(repository.saveAndFlush(any())).thenAnswer(inv -> inv.getArgument(0));

        org.mockito.Mockito.doAnswer(inv -> {
            jakarta.servlet.http.HttpServletResponse res = inv.getArgument(1);
            res.setStatus(500);
            return null;
        }).when(chain).doFilter(any(), any());

        MockHttpServletResponse response = new MockHttpServletResponse();
        filter.doFilterInternal(post("err-1"), response, chain);

        verify(repository).delete(any(IdempotencyRecord.class));
        verify(repository, never()).save(any(IdempotencyRecord.class));
    }

    @Test
    void concurrentInsertCollisionReturnsConflict() throws Exception {
        when(repository.findByOrgIdAndIdempotencyKey(orgId, "race-1")).thenReturn(Optional.empty());
        when(repository.saveAndFlush(any())).thenThrow(new DataIntegrityViolationException("dup"));
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilterInternal(post("race-1"), response, chain);

        verify(chain, never()).doFilter(any(), any());
        assertEquals(409, response.getStatus());
    }

    @Test
    void expiredRecordIsDeletedAndRequestReExecutes() throws Exception {
        IdempotencyRecord expired = completedRecord("old-1");
        expired.setExpiresAt(Instant.now().minusSeconds(60));
        when(repository.findByOrgIdAndIdempotencyKey(orgId, "old-1")).thenReturn(Optional.of(expired));
        when(repository.saveAndFlush(any())).thenAnswer(inv -> inv.getArgument(0));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        MockHttpServletResponse response = new MockHttpServletResponse();
        filter.doFilterInternal(post("old-1"), response, chain);

        verify(repository).delete(expired);
        verify(chain).doFilter(any(), any());
    }
}
