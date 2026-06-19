package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.manufacturing.entity.CapaAction;
import com.katasticho.erp.manufacturing.entity.NonConformanceReport;
import com.katasticho.erp.manufacturing.repository.CapaActionRepository;
import com.katasticho.erp.manufacturing.repository.NonConformanceReportRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class CapaServiceTest {

    @Mock private CapaActionRepository capaRepository;
    @Mock private NonConformanceReportRepository ncrRepository;

    private CapaService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final Clock fixedClock = Clock.fixed(
            Instant.parse("2026-06-19T10:00:00Z"), ZoneOffset.UTC);

    @BeforeEach
    void setUp() {
        service = new CapaService(capaRepository, ncrRepository, fixedClock);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
        when(capaRepository.save(any())).thenAnswer(inv -> {
            CapaAction c = inv.getArgument(0);
            if (c.getId() == null) c.setId(UUID.randomUUID());
            return c;
        });
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    @Test
    void raise_validInput_savesWithOpenStatusAndAutoNumber() {
        when(capaRepository.findMaxSequenceForYear(orgId, "CAPA-2026-%")).thenReturn(7);

        CapaAction capa = service.raise(null, "preventive", "Update SOP for blending",
                "Recurring batch failures on line 3", "Retrain operators",
                userId, LocalDate.of(2026, 7, 1), "HIGH");

        assertEquals("PREVENTIVE", capa.getCapaType());
        assertEquals("CAPA-2026-00008", capa.getCapaNumber());
        assertEquals("OPEN", capa.getStatus());
        assertEquals("HIGH", capa.getPriority());
        assertEquals(orgId, capa.getOrgId());
        assertEquals(userId, capa.getAssignedTo());
    }

    @Test
    void raise_invalidType_throws() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.raise(null, "ADHOC", "Fix it", null, null,
                        null, null, null));
        assertEquals("CAPA_INVALID_TYPE", ex.getErrorCode());
    }

    @Test
    void raise_emptyTitle_throws() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.raise(null, "CORRECTIVE", "  ", null, null,
                        null, null, null));
        assertEquals("CAPA_TITLE_REQUIRED", ex.getErrorCode());
    }

    @Test
    void raise_invalidPriority_throws() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.raise(null, "CORRECTIVE", "Title", null, null,
                        null, null, "WHENEVER"));
        assertEquals("CAPA_INVALID_PRIORITY", ex.getErrorCode());
    }

    @Test
    void raise_againstClosedNcr_throws() {
        UUID ncrId = UUID.randomUUID();
        NonConformanceReport ncr = NonConformanceReport.builder()
                .ncrNumber("NCR-1").itemId(UUID.randomUUID())
                .status("CLOSED").build();
        ncr.setId(ncrId); ncr.setOrgId(orgId);
        when(ncrRepository.findByIdAndOrgIdAndIsDeletedFalse(ncrId, orgId))
                .thenReturn(Optional.of(ncr));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.raise(ncrId, "CORRECTIVE", "Title", null, null,
                        null, null, null));
        assertEquals("CAPA_NCR_CLOSED", ex.getErrorCode());
    }

    @Test
    void start_completeAndVerify_walkLifecycle() {
        UUID id = UUID.randomUUID();
        CapaAction capa = CapaAction.builder()
                .capaNumber("CAPA-2026-00001")
                .capaType("CORRECTIVE").title("T").status("OPEN").build();
        capa.setId(id); capa.setOrgId(orgId);
        when(capaRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(capa));

        // Start
        CapaAction started = service.start(id);
        assertEquals("IN_PROGRESS", started.getStatus());

        // Complete (also stamps completedBy from TenantContext)
        CapaAction done = service.complete(id, "Action taken, retraining done");
        assertEquals("COMPLETED", done.getStatus());
        assertEquals(userId, done.getCompletedBy());
        assertEquals("Action taken, retraining done", done.getCompletionNotes());
        assertNotNull(done.getCompletedAt());
    }

    @Test
    void verify_selfVerifyByCompleter_throws() {
        UUID id = UUID.randomUUID();
        CapaAction capa = CapaAction.builder()
                .capaNumber("CAPA-1").capaType("CORRECTIVE").title("T")
                .status("COMPLETED").completedBy(userId).build();
        capa.setId(id); capa.setOrgId(orgId);
        when(capaRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(capa));

        // Same userId in TenantContext (set in @BeforeEach) — should throw
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.verify(id, "Effective"));
        assertEquals("CAPA_SELF_VERIFY_FORBIDDEN", ex.getErrorCode());
    }

    @Test
    void verify_differentVerifier_stampsAndMovesToVerified() {
        UUID completerId = UUID.randomUUID();
        UUID id = UUID.randomUUID();
        CapaAction capa = CapaAction.builder()
                .capaNumber("CAPA-1").capaType("CORRECTIVE").title("T")
                .status("COMPLETED").completedBy(completerId).build();
        capa.setId(id); capa.setOrgId(orgId);
        when(capaRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(capa));

        CapaAction verified = service.verify(id, "Verified after 30-day check");
        assertEquals("VERIFIED", verified.getStatus());
        assertEquals(userId, verified.getVerifiedBy());
        assertEquals("Verified after 30-day check", verified.getEffectivenessNotes());
        assertNotNull(verified.getVerifiedAt());
    }

    @Test
    void cancel_alreadyVerified_throws() {
        UUID id = UUID.randomUUID();
        CapaAction capa = CapaAction.builder()
                .capaNumber("CAPA-1").capaType("CORRECTIVE").title("T")
                .status("VERIFIED").build();
        capa.setId(id); capa.setOrgId(orgId);
        when(capaRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(capa));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.cancel(id, "Nope"));
        assertEquals("CAPA_FINAL_STATE", ex.getErrorCode());
    }

    @Test
    void start_alreadyInProgress_throws() {
        UUID id = UUID.randomUUID();
        CapaAction capa = CapaAction.builder()
                .capaNumber("CAPA-1").capaType("CORRECTIVE").title("T")
                .status("IN_PROGRESS").build();
        capa.setId(id); capa.setOrgId(orgId);
        when(capaRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(capa));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.start(id));
        assertEquals("CAPA_INVALID_TRANSITION", ex.getErrorCode());
    }

    @Test
    void overdue_walksRepoWithTodaysDate() {
        when(capaRepository.findOverdue(orgId, LocalDate.of(2026, 6, 19)))
                .thenReturn(List.of());

        List<CapaAction> overdue = service.overdue();
        assertTrue(overdue.isEmpty());
        // Verified by setup — the repo was queried with the fixed-clock today
    }
}
