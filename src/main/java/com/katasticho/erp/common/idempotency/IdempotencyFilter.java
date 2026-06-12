package com.katasticho.erp.common.idempotency;

import com.katasticho.erp.common.context.TenantContext;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingResponseWrapper;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

/**
 * Replays duplicate command requests instead of re-executing them.
 *
 * <p>External callers (the Katixo hospital service, MCP agents, integrations)
 * send an {@code Idempotency-Key} header on POST/PUT/PATCH commands that create
 * invoices, receipts or payments. The first request executes normally and its
 * response is stored; a retry with the same key (same org) gets the ORIGINAL
 * response back, so a network timeout can never double-create a document.
 *
 * <p>Runs AFTER the auth filters (needs {@code TenantContext} org scoping).
 * Requests without the header — the entire existing UI traffic — pass through
 * completely untouched.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class IdempotencyFilter extends OncePerRequestFilter {

    public static final String HEADER = "Idempotency-Key";
    /** Keys older than this are forgotten; a retry after that re-executes. */
    private static final Duration TTL = Duration.ofHours(48);

    private final IdempotencyRecordRepository repository;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String key = request.getHeader(HEADER);
        UUID orgId = TenantContext.getCurrentOrgId();

        if (key == null || key.isBlank() || orgId == null || !isCommand(request)) {
            filterChain.doFilter(request, response);
            return;
        }
        key = key.trim();

        Optional<IdempotencyRecord> existing = repository.findByOrgIdAndIdempotencyKey(orgId, key);
        if (existing.isPresent() && !existing.get().isExpired()) {
            IdempotencyRecord record = existing.get();
            if (IdempotencyRecord.STATUS_COMPLETED.equals(record.getStatus())) {
                replay(response, record);
            } else {
                conflict(response, "A request with this Idempotency-Key is still being processed");
            }
            return;
        }
        existing.filter(IdempotencyRecord::isExpired).ifPresent(repository::delete);

        IdempotencyRecord record;
        try {
            record = repository.saveAndFlush(IdempotencyRecord.builder()
                    .orgId(orgId)
                    .idempotencyKey(key)
                    .requestMethod(request.getMethod())
                    .requestPath(request.getRequestURI())
                    .status(IdempotencyRecord.STATUS_IN_PROGRESS)
                    .createdAt(Instant.now())
                    .expiresAt(Instant.now().plus(TTL))
                    .build());
        } catch (DataIntegrityViolationException e) {
            // Concurrent duplicate beat us to the insert.
            conflict(response, "A request with this Idempotency-Key is already in progress");
            return;
        }

        ContentCachingResponseWrapper wrapped = new ContentCachingResponseWrapper(response);
        boolean completed = false;
        try {
            filterChain.doFilter(request, wrapped);
            completed = true;
        } finally {
            if (completed && wrapped.getStatus() < 500) {
                record.setStatus(IdempotencyRecord.STATUS_COMPLETED);
                record.setResponseStatus(wrapped.getStatus());
                record.setResponseBody(new String(wrapped.getContentAsByteArray(), StandardCharsets.UTF_8));
                try {
                    repository.save(record);
                } catch (Exception e) {
                    log.error("Failed to store idempotency response for key {}: {}", key, e.getMessage());
                }
            } else {
                // 5xx or exception: forget the key so the caller can retry the command.
                try {
                    repository.delete(record);
                } catch (Exception e) {
                    log.error("Failed to release idempotency key {}: {}", key, e.getMessage());
                }
            }
            wrapped.copyBodyToResponse();
        }
    }

    private boolean isCommand(HttpServletRequest request) {
        String method = request.getMethod();
        return "POST".equals(method) || "PUT".equals(method) || "PATCH".equals(method);
    }

    private void replay(HttpServletResponse response, IdempotencyRecord record) throws IOException {
        response.setStatus(record.getResponseStatus() == null ? 200 : record.getResponseStatus());
        response.setContentType("application/json");
        response.setHeader("X-Idempotency-Replay", "true");
        if (record.getResponseBody() != null) {
            response.getWriter().write(record.getResponseBody());
        }
    }

    private void conflict(HttpServletResponse response, String message) throws IOException {
        response.setStatus(409);
        response.setContentType("application/json");
        response.getWriter().write("{\"success\":false,\"message\":\"" + message + "\"}");
    }
}
