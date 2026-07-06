package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.fieldsales.entity.RcpaAudit;
import com.katasticho.erp.fieldsales.entity.RcpaLine;
import com.katasticho.erp.fieldsales.repository.RcpaAuditRepository;
import com.katasticho.erp.fieldsales.repository.RcpaLineRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RcpaServiceTest {

    @Mock private RcpaAuditRepository auditRepo;
    @Mock private RcpaLineRepository lineRepo;
    @Mock private ContactRepository contactRepo;

    private RcpaService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID chemistId = UUID.randomUUID();
    private final LocalDate day = LocalDate.of(2026, 5, 10);

    @BeforeEach
    void setUp() {
        service = new RcpaService(auditRepo, lineRepo, contactRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private RcpaLine line(String product, String brand, String competitor, String qty, String value) {
        return RcpaLine.builder()
                .orgId(orgId).productName(product).brandType(brand).competitorName(competitor)
                .quantity(new BigDecimal(qty)).value(new BigDecimal(value)).build();
    }

    @Test
    void record_updateByNonOwnerOperator_throwsAndDoesNotMutate() {
        // An audit owned by MR "A"; a different OPERATOR "B" must not overwrite it.
        UUID auditId = UUID.randomUUID();
        UUID ownerA = UUID.randomUUID();
        RcpaAudit existing = RcpaAudit.builder().id(auditId).orgId(orgId).salespersonId(ownerA).build();
        when(contactRepo.findByIdAndOrgIdAndIsDeletedFalse(chemistId, orgId))
                .thenReturn(Optional.of(com.katasticho.erp.contact.entity.Contact.builder().build()));
        when(auditRepo.findByIdAndOrgIdAndIsDeletedFalse(auditId, orgId)).thenReturn(Optional.of(existing));

        TenantContext.setCurrentUserId(UUID.randomUUID()); // caller B, not the owner
        TenantContext.setCurrentRole("OPERATOR");

        var ex = assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.record(auditId, chemistId, day, null, "tampered", List.of()));
        assertEquals("RCPA_NOT_OWNER", ex.getErrorCode());
        verify(lineRepo, never()).deleteByOrgIdAndAuditId(any(), any());
        verify(auditRepo, never()).save(any());
    }

    @Test
    void record_updateByAdmin_isAllowedOnForeignAudit() {
        UUID auditId = UUID.randomUUID();
        RcpaAudit existing = RcpaAudit.builder().id(auditId).orgId(orgId)
                .salespersonId(UUID.randomUUID()).build();
        when(contactRepo.findByIdAndOrgIdAndIsDeletedFalse(chemistId, orgId))
                .thenReturn(Optional.of(com.katasticho.erp.contact.entity.Contact.builder().build()));
        when(auditRepo.findByIdAndOrgIdAndIsDeletedFalse(auditId, orgId)).thenReturn(Optional.of(existing));
        when(auditRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        TenantContext.setCurrentUserId(UUID.randomUUID());
        TenantContext.setCurrentRole("ADMIN");

        service.record(auditId, chemistId, day, null, "admin edit", List.of());
        verify(auditRepo).save(any());
    }

    @Test
    @SuppressWarnings("unchecked")
    void record_stampsSalespersonAndNormalisesBrandType() {
        when(contactRepo.findByIdAndOrgIdAndIsDeletedFalse(chemistId, orgId))
                .thenReturn(Optional.of(mock(Contact.class)));
        when(auditRepo.save(any())).thenAnswer(inv -> {
            RcpaAudit a = inv.getArgument(0);
            if (a.getId() == null) a.setId(UUID.randomUUID());
            return a;
        });
        when(lineRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        var lines = List.of(
                new RcpaService.LineInput("Dolo 650", "own", null, null,
                        new BigDecimal("40"), new BigDecimal("400")),
                new RcpaService.LineInput("Calpol", "competitor", "GSK", null,
                        new BigDecimal("10"), new BigDecimal("120")));

        Map<String, Object> result = service.record(null, chemistId, day, null, "monthly", lines);

        RcpaAudit audit = (RcpaAudit) result.get("audit");
        assertEquals(userId, audit.getSalespersonId());
        List<RcpaLine> saved = (List<RcpaLine>) result.get("lines");
        assertEquals("OWN", saved.get(0).getBrandType());
        assertEquals("COMPETITOR", saved.get(1).getBrandType());
        assertEquals("GSK", saved.get(1).getCompetitorName());
        verify(lineRepo).deleteByOrgIdAndAuditId(eq(orgId), any());
    }

    @Test
    void shareReport_computesOwnVsCompetitorShare() {
        RcpaAudit a = RcpaAudit.builder().id(UUID.randomUUID()).build();
        when(auditRepo.findByOrgIdAndAuditDateBetweenAndIsDeletedFalse(eq(orgId), any(), any()))
                .thenReturn(List.of(a));
        when(lineRepo.findByOrgIdAndAuditIdInAndIsDeletedFalse(eq(orgId), any()))
                .thenReturn(List.of(
                        line("Dolo 650", "OWN", null, "60", "600"),
                        line("Calpol", "COMPETITOR", "GSK", "40", "400")));

        Map<String, Object> r = service.shareReport(day, day);

        assertEquals(0, ((BigDecimal) r.get("ownValue")).compareTo(new BigDecimal("600")));
        assertEquals(0, ((BigDecimal) r.get("competitorValue")).compareTo(new BigDecimal("400")));
        // 600 / (600+400) = 60.0%
        assertEquals(0, ((BigDecimal) r.get("ownShareByValuePct")).compareTo(new BigDecimal("60.0")));
        assertEquals(0, ((BigDecimal) r.get("ownShareByQtyPct")).compareTo(new BigDecimal("60.0")));
    }

    @Test
    void competitorBrands_aggregatesAndSortsByValue() {
        RcpaAudit a = RcpaAudit.builder().id(UUID.randomUUID()).build();
        when(auditRepo.findByOrgIdAndAuditDateBetweenAndIsDeletedFalse(eq(orgId), any(), any()))
                .thenReturn(List.of(a));
        when(lineRepo.findByOrgIdAndAuditIdInAndIsDeletedFalse(eq(orgId), any()))
                .thenReturn(List.of(
                        line("Dolo 650", "OWN", null, "60", "600"),       // ignored (own)
                        line("Calpol", "COMPETITOR", "GSK", "10", "120"),
                        line("Calpol", "COMPETITOR", "GSK", "5", "60"),    // merges with above
                        line("Crocin", "COMPETITOR", "GSK", "30", "300")));

        List<Map<String, Object>> rows = service.competitorBrands(day, day);

        assertEquals(2, rows.size());
        // Crocin (300) ranks above Calpol (180)
        assertEquals("Crocin", rows.get(0).get("productName"));
        assertEquals(0, ((BigDecimal) rows.get(1).get("quantity")).compareTo(new BigDecimal("15")));
        assertEquals(0, ((BigDecimal) rows.get(1).get("value")).compareTo(new BigDecimal("180")));
    }
}
