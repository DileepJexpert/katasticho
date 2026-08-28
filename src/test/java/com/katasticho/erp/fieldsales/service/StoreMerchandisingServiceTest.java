package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.fieldsales.dto.MerchandisingSummaryResponse;
import com.katasticho.erp.fieldsales.dto.StoreMerchandisingAuditRequest;
import com.katasticho.erp.fieldsales.dto.StoreMerchandisingAuditResponse;
import com.katasticho.erp.fieldsales.entity.*;
import com.katasticho.erp.fieldsales.repository.FieldVisitRepository;
import com.katasticho.erp.fieldsales.repository.RouteExecutionRepository;
import com.katasticho.erp.fieldsales.repository.StoreMerchandisingAuditRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class StoreMerchandisingServiceTest {

    @Mock private StoreMerchandisingAuditRepository auditRepository;
    @Mock private FieldVisitRepository fieldVisitRepository;
    @Mock private RouteExecutionRepository routeExecutionRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private AppUserRepository appUserRepository;

    private StoreMerchandisingService service;
    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
        service = new StoreMerchandisingService(
                auditRepository,
                fieldVisitRepository,
                routeExecutionRepository,
                contactRepository,
                appUserRepository
        );
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void recordAudit_success() {
        UUID visitId = UUID.randomUUID();
        UUID executionId = UUID.randomUUID();
        UUID contactId = UUID.randomUUID();

        FieldVisit visit = FieldVisit.builder()
                .id(visitId)
                .orgId(orgId)
                .routeExecutionId(executionId)
                .contactId(contactId)
                .build();

        RouteExecution execution = RouteExecution.builder()
                .salespersonId(userId)
                .build();
        execution.setId(executionId);
        execution.setOrgId(orgId);

        Contact contact = Contact.builder()
                .displayName("Apollo Pharmacy #12")
                .build();
        contact.setId(contactId);

        AppUser user = AppUser.builder()
                .fullName("Rajesh Kumar")
                .build();
        user.setId(userId);

        when(fieldVisitRepository.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId)).thenReturn(Optional.of(visit));
        when(routeExecutionRepository.findByIdAndOrgIdAndIsDeletedFalse(executionId, orgId)).thenReturn(Optional.of(execution));
        when(contactRepository.findById(contactId)).thenReturn(Optional.of(contact));
        when(appUserRepository.findById(userId)).thenReturn(Optional.of(user));

        when(auditRepository.save(any(StoreMerchandisingAudit.class))).thenAnswer(inv -> {
            StoreMerchandisingAudit a = inv.getArgument(0);
            a.setId(UUID.randomUUID());
            return a;
        });

        StoreMerchandisingAuditRequest req = new StoreMerchandisingAuditRequest(
                visitId,
                executionId,
                contactId,
                MerchandisingAuditType.PRIMARY_SHELF,
                "https://storage.googleapis.com/erp-photos/shelf-001.jpg",
                new BigDecimal("65.50"),
                12,
                false,
                "Brand X, Brand Y",
                PlanogramCompliance.COMPLIANT,
                "Eye-level placement confirmed"
        );

        StoreMerchandisingAuditResponse res = service.recordAudit(req);

        assertThat(res).isNotNull();
        assertThat(res.customerName()).isEqualTo("Apollo Pharmacy #12");
        assertThat(res.salespersonName()).isEqualTo("Rajesh Kumar");
        assertThat(res.shelfSharePct()).isEqualByComparingTo(new BigDecimal("65.50"));
        assertThat(res.facingCount()).isEqualTo(12);
        assertThat(res.planogramCompliance()).isEqualTo(PlanogramCompliance.COMPLIANT);
        assertThat(visit.getPhotoUrl()).isEqualTo("https://storage.googleapis.com/erp-photos/shelf-001.jpg");
        verify(fieldVisitRepository).save(visit);
    }

    @Test
    void recordAudit_visitNotFound_throwsException() {
        UUID visitId = UUID.randomUUID();
        UUID executionId = UUID.randomUUID();
        UUID contactId = UUID.randomUUID();

        when(fieldVisitRepository.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId)).thenReturn(Optional.empty());

        StoreMerchandisingAuditRequest req = new StoreMerchandisingAuditRequest(
                visitId, executionId, contactId,
                MerchandisingAuditType.PRIMARY_SHELF, null, null, null, false, null, null, null
        );

        assertThatThrownBy(() -> service.recordAudit(req))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("FieldVisit not found");
    }

    @Test
    void getSummary_calculatesMetricsCorrectly() {
        Instant now = Instant.now();
        Instant from = now.minusSeconds(86400 * 7);

        StoreMerchandisingAudit a1 = StoreMerchandisingAudit.builder()
                .auditType(MerchandisingAuditType.PRIMARY_SHELF)
                .shelfSharePct(new BigDecimal("60.00"))
                .planogramCompliance(PlanogramCompliance.COMPLIANT)
                .photoUrl("https://example.com/p1.jpg")
                .isStockOut(false)
                .build();
        a1.setId(UUID.randomUUID());

        StoreMerchandisingAudit a2 = StoreMerchandisingAudit.builder()
                .auditType(MerchandisingAuditType.SECONDARY_DISPLAY)
                .shelfSharePct(new BigDecimal("40.00"))
                .planogramCompliance(PlanogramCompliance.NON_COMPLIANT)
                .photoUrl("https://example.com/p2.jpg")
                .isStockOut(true)
                .build();
        a2.setId(UUID.randomUUID());

        when(auditRepository.findByOrgIdAndAuditedAtBetweenAndIsDeletedFalseOrderByAuditedAtDesc(eq(orgId), any(), any()))
                .thenReturn(List.of(a1, a2));

        MerchandisingSummaryResponse summary = service.getSummary(from, now);

        assertThat(summary.totalAudits()).isEqualTo(2);
        assertThat(summary.totalPhotosCaptured()).isEqualTo(2);
        assertThat(summary.averageShelfSharePct()).isEqualByComparingTo(new BigDecimal("50.00"));
        assertThat(summary.complianceRatePct()).isEqualTo(50.0);
        assertThat(summary.stockOutCount()).isEqualTo(1);
        assertThat(summary.auditsByType().get(MerchandisingAuditType.PRIMARY_SHELF)).isEqualTo(1);
        assertThat(summary.auditsByCompliance().get(PlanogramCompliance.COMPLIANT)).isEqualTo(1);
    }
}
