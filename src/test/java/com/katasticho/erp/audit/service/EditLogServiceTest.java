package com.katasticho.erp.audit.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.audit.entity.EditLog;
import com.katasticho.erp.audit.repository.EditLogRepository;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;

@ExtendWith(MockitoExtension.class)
class EditLogServiceTest {

    @Mock
    private EditLogRepository editLogRepository;
    @Mock
    private AppUserRepository appUserRepository;

    private EditLogService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new EditLogService(editLogRepository, appUserRepository, new ObjectMapper());
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private AppUser user(UUID id, String name) {
        AppUser user = AppUser.builder().fullName(name).build();
        user.setId(id);
        return user;
    }

    @Test
    void list_mapsRowsParsesDiffJsonAndResolvesUserNames() {
        EditLog row = EditLog.builder()
                .id(UUID.randomUUID())
                .orgId(orgId)
                .entityType("INVOICE")
                .entityId(UUID.randomUUID())
                .action("UPDATE")
                .entityLabel("INV-42")
                .fieldChanges("{\"status\":{\"from\":\"DRAFT\",\"to\":\"POSTED\"}}")
                .changedBy(userId)
                .changedAt(Instant.parse("2026-07-01T10:00:00Z"))
                .build();
        when(editLogRepository.findAll(any(Specification.class), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(row)));
        when(appUserRepository.findAllById(anyCollection()))
                .thenReturn(List.of(user(userId, "Asha Accountant")));

        Page<EditLogService.EditLogEntryResponse> page = service.list(
                "invoice", null, null, null, LocalDate.of(2026, 6, 1), LocalDate.of(2026, 7, 2),
                PageRequest.of(0, 50));

        assertThat(page.getContent()).hasSize(1);
        EditLogService.EditLogEntryResponse entry = page.getContent().get(0);
        assertThat(entry.entityType()).isEqualTo("INVOICE");
        assertThat(entry.entityLabel()).isEqualTo("INV-42");
        assertThat(entry.changedByName()).isEqualTo("Asha Accountant");
        assertThat(entry.fieldChanges()).containsKey("status");
        assertThat((Map<String, Object>) entry.fieldChanges().get("status"))
                .containsEntry("from", "DRAFT").containsEntry("to", "POSTED");
    }

    @Test
    void summary_aggregatesActionAndTypeCountsAndTopUsers() {
        UUID otherUser = UUID.randomUUID();
        when(editLogRepository.countByTypeAndAction(eq(orgId), any(), any())).thenReturn(List.of(
                new Object[]{"INVOICE", "CREATE", 3L},
                new Object[]{"INVOICE", "UPDATE", 2L},
                new Object[]{"CONTACT", "UPDATE", 1L}));
        when(editLogRepository.countByUser(eq(orgId), any(), any())).thenReturn(List.of(
                new Object[]{userId, 4L},
                new Object[]{otherUser, 2L}));
        when(appUserRepository.findAllById(anyCollection())).thenReturn(List.of(
                user(userId, "Asha Accountant"), user(otherUser, "Om Operator")));

        Map<String, Object> summary = service.summary(LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 30));

        assertThat(summary.get("totalChanges")).isEqualTo(6L);
        assertThat((Map<String, Long>) summary.get("byAction"))
                .containsEntry("CREATE", 3L).containsEntry("UPDATE", 3L);
        assertThat((Map<String, Long>) summary.get("byEntityType"))
                .containsEntry("INVOICE", 5L).containsEntry("CONTACT", 1L);
        List<Map<String, Object>> topUsers = (List<Map<String, Object>>) summary.get("topUsers");
        assertThat(topUsers).hasSize(2);
        assertThat(topUsers.get(0)).containsEntry("name", "Asha Accountant").containsEntry("count", 4L);
    }

    @Test
    void list_toleratesUnparseableDiffJson() {
        EditLog row = EditLog.builder()
                .id(UUID.randomUUID())
                .orgId(orgId)
                .entityType("ITEM")
                .entityId(UUID.randomUUID())
                .action("CREATE")
                .fieldChanges("not-json{{")
                .changedAt(Instant.now())
                .build();
        when(editLogRepository.findAll(any(Specification.class), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(row)));

        Page<EditLogService.EditLogEntryResponse> page = service.list(
                null, null, null, null, null, null, PageRequest.of(0, 50));

        assertThat(page.getContent().get(0).fieldChanges()).isNull();
        assertThat(page.getContent().get(0).changedByName()).isNull();
    }
}
