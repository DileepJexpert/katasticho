package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.dto.runway.CashRunwayReportResponse;
import com.katasticho.erp.accounting.dto.runway.CashRunwaySimulationRequest;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.repository.JournalLineRepository;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.payroll.repository.PayrollRunRepository;
import com.katasticho.erp.procurement.repository.PurchaseOrderRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CashRunwayServiceTest {

    @Mock private AccountRepository accountRepository;
    @Mock private JournalLineRepository journalLineRepository;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private PurchaseBillRepository purchaseBillRepository;
    @Mock private PurchaseOrderRepository purchaseOrderRepository;
    @Mock private PayrollRunRepository payrollRunRepository;
    @Mock private OrganisationRepository organisationRepository;

    @InjectMocks
    private CashRunwayService cashRunwayService;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        Organisation org = new Organisation();
        org.setId(orgId);
        org.setBaseCurrency("INR");
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void generates13ConsecutiveWeeklyBucketsWithContinuousBalance() {
        when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId)).thenReturn(Collections.emptyList());
        when(invoiceRepository.findOutstandingInvoices(orgId)).thenReturn(Collections.emptyList());
        when(purchaseBillRepository.findOutstandingBills(orgId)).thenReturn(Collections.emptyList());
        when(purchaseOrderRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId)).thenReturn(Collections.emptyList());
        when(payrollRunRepository.findByOrgIdAndStatusAndPeriodStartBetweenOrderByPeriodStart(eq(orgId), any(), any(), any()))
                .thenReturn(Collections.emptyList());

        LocalDate today = LocalDate.of(2026, 9, 2);
        CashRunwayReportResponse response = cashRunwayService.generate13WeekRunway(today, null);

        assertThat(response).isNotNull();
        assertThat(response.weeklyBuckets()).hasSize(13);
        assertThat(response.baseCurrency()).isEqualTo("INR");
        assertThat(response.currentLiquidCash()).isEqualByComparingTo(BigDecimal.ZERO);

        // Verify continuity of opening and closing balances across weeks
        for (int i = 0; i < 12; i++) {
            var current = response.weeklyBuckets().get(i);
            var next = response.weeklyBuckets().get(i + 1);
            assertThat(next.openingBalance()).isEqualByComparingTo(current.closingBalance());
            assertThat(current.netCashFlow()).isEqualByComparingTo(current.totalInflows().subtract(current.totalOutflows()));
        }
    }

    @Test
    void simulationAdjustsRunwayAndInflowsCorrectly() {
        when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId)).thenReturn(Collections.emptyList());
        when(invoiceRepository.findOutstandingInvoices(orgId)).thenReturn(Collections.emptyList());
        when(purchaseBillRepository.findOutstandingBills(orgId)).thenReturn(Collections.emptyList());
        when(purchaseOrderRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId)).thenReturn(Collections.emptyList());
        when(payrollRunRepository.findByOrgIdAndStatusAndPeriodStartBetweenOrderByPeriodStart(eq(orgId), any(), any(), any()))
                .thenReturn(Collections.emptyList());

        LocalDate today = LocalDate.of(2026, 9, 2);
        Map<Integer, BigDecimal> capex = Map.of(3, BigDecimal.valueOf(500000));
        CashRunwaySimulationRequest req = new CashRunwaySimulationRequest(15, 10, 0.8, -10.0, capex);

        CashRunwayReportResponse simulated = cashRunwayService.generate13WeekRunway(today, req);

        assertThat(simulated).isNotNull();
        assertThat(simulated.weeklyBuckets()).hasSize(13);
        // Week 3 should reflect capex outflow of 500,000
        assertThat(simulated.weeklyBuckets().get(2).plannedCapex()).isEqualByComparingTo(BigDecimal.valueOf(500000));
    }
}
