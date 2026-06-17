package com.katasticho.erp.transport.service;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.ap.dto.CreatePurchaseBillRequest;
import com.katasticho.erp.ap.dto.PurchaseBillResponse;
import com.katasticho.erp.ap.service.PurchaseBillService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.transport.dto.TransportDtos.*;
import com.katasticho.erp.transport.entity.LorryReceipt;
import com.katasticho.erp.transport.repository.LorryReceiptRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class LorryReceiptServiceTest {

    @Mock private LorryReceiptRepository repository;
    @Mock private FreightRateCardService rateCardService;
    @Mock private PurchaseBillService purchaseBillService;
    @Mock private AccountRepository accountRepository;
    @Mock private OrgSettingsService orgSettingsService;
    private LorryReceiptService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID transporter = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new LorryReceiptService(repository, rateCardService, purchaseBillService,
                accountRepository, orgSettingsService);
        TenantContext.setCurrentOrgId(orgId);
        when(repository.save(any(LorryReceipt.class))).thenAnswer(inv -> {
            LorryReceipt lr = inv.getArgument(0);
            if (lr.getId() == null) lr.setId(UUID.randomUUID());
            return lr;
        });
        when(orgSettingsService.getAll(orgId)).thenReturn(new HashMap<>());
        Account acc = new Account();
        acc.setCode("5240");
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "5240"))
                .thenReturn(Optional.of(acc));
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    private CreateLorryReceiptRequest req(BigDecimal freight, String basis, String gst) {
        return new CreateLorryReceiptRequest(LocalDate.of(2026, 6, 17), transporter, null,
                null, null, null, "MH12AB1234", "Ramesh", "9811111111",
                "Mumbai", "Pune", new BigDecimal("150"), "ROAD", 5, new BigDecimal("100"),
                new BigDecimal("50000"), freight, basis, gst, new BigDecimal("5"), null);
    }

    @Test
    void create_autoFillsFreightFromRateCardWhenAbsent() {
        when(rateCardService.resolveRate(eq(transporter), eq("Mumbai"), eq("Pune"), eq("ROAD"), any()))
                .thenReturn(new RateQuoteResponse(true, UUID.randomUUID(),
                        new BigDecimal("800"), "8/kg × 100", "ok"));

        LorryReceiptResponse r = service.create(req(null, "TO_BE_BILLED", "RCM"));

        assertThat(r.freightAmount()).isEqualByComparingTo("800");
        assertThat(r.lrNumber()).startsWith("LR-");
        assertThat(r.status()).isEqualTo("DRAFT");
    }

    @Test
    void create_keepsExplicitFreight() {
        LorryReceiptResponse r = service.create(req(new BigDecimal("1200"), "PAID", "FORWARD"));
        assertThat(r.freightAmount()).isEqualByComparingTo("1200");
        verify(rateCardService, never()).resolveRate(any(), any(), any(), any(), any());
    }

    @Test
    void billFreight_rcm_raisesDraftBillWithReverseChargeAndGtaHsn() {
        LorryReceipt lr = LorryReceipt.builder()
                .lrNumber("LR-00001").lrDate(LocalDate.of(2026, 6, 17))
                .transporterContactId(transporter).origin("Mumbai").destination("Pune")
                .freightAmount(new BigDecimal("800")).freightBasis("TO_BE_BILLED")
                .gstTreatment("RCM").freightGstRate(new BigDecimal("5")).status("ISSUED").build();
        lr.setId(UUID.randomUUID());
        lr.setOrgId(orgId);
        when(repository.findByIdAndOrgIdAndIsDeletedFalse(lr.getId(), orgId)).thenReturn(Optional.of(lr));

        PurchaseBillResponse bill = mock(PurchaseBillResponse.class);
        when(bill.id()).thenReturn(UUID.randomUUID());
        when(bill.billNumber()).thenReturn("PB-00007");
        when(purchaseBillService.createBill(any())).thenReturn(bill);

        BillFreightResult result = service.billFreight(lr.getId());

        assertThat(result.reverseCharge()).isTrue();
        assertThat(result.billNumber()).isEqualTo("PB-00007");
        assertThat(lr.getFreightBillId()).isNotNull();

        ArgumentCaptor<CreatePurchaseBillRequest> cap =
                ArgumentCaptor.forClass(CreatePurchaseBillRequest.class);
        verify(purchaseBillService).createBill(cap.capture());
        CreatePurchaseBillRequest br = cap.getValue();
        assertThat(br.contactId()).isEqualTo(transporter);
        assertThat(br.reverseCharge()).isTrue();
        assertThat(br.lines()).hasSize(1);
        var line = br.lines().get(0);
        assertThat(line.lineType()).isEqualTo("SERVICE");
        assertThat(line.hsnCode()).isEqualTo("9965");           // GTA
        assertThat(line.accountCode()).isEqualTo("5240");        // resolved freight account
        assertThat(line.unitPrice()).isEqualByComparingTo("800");
        assertThat(line.gstRate()).isEqualByComparingTo("5");
    }

    @Test
    void billFreight_toPay_isRejected() {
        LorryReceipt lr = LorryReceipt.builder()
                .lrNumber("LR-00002").lrDate(LocalDate.now()).transporterContactId(transporter)
                .freightAmount(new BigDecimal("800")).freightBasis("TO_PAY")
                .gstTreatment("FORWARD").status("ISSUED").build();
        lr.setId(UUID.randomUUID());
        lr.setOrgId(orgId);
        when(repository.findByIdAndOrgIdAndIsDeletedFalse(lr.getId(), orgId)).thenReturn(Optional.of(lr));

        assertThatThrownBy(() -> service.billFreight(lr.getId()))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo("LR_NOT_BILLABLE");
        verify(purchaseBillService, never()).createBill(any());
    }

    @Test
    void billFreight_twice_isRejected() {
        LorryReceipt lr = LorryReceipt.builder()
                .lrNumber("LR-00003").lrDate(LocalDate.now()).transporterContactId(transporter)
                .freightAmount(new BigDecimal("800")).freightBasis("PAID")
                .gstTreatment("RCM").freightBillId(UUID.randomUUID()).status("ISSUED").build();
        lr.setId(UUID.randomUUID());
        lr.setOrgId(orgId);
        when(repository.findByIdAndOrgIdAndIsDeletedFalse(lr.getId(), orgId)).thenReturn(Optional.of(lr));

        assertThatThrownBy(() -> service.billFreight(lr.getId()))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo("LR_ALREADY_BILLED");
    }

    @Test
    void lifecycle_draftToIssuedToDelivered() {
        LorryReceipt lr = LorryReceipt.builder().lrNumber("LR-1").lrDate(LocalDate.now())
                .transporterContactId(transporter).status("DRAFT").build();
        lr.setId(UUID.randomUUID());
        lr.setOrgId(orgId);
        when(repository.findByIdAndOrgIdAndIsDeletedFalse(lr.getId(), orgId)).thenReturn(Optional.of(lr));

        assertThat(service.issue(lr.getId()).status()).isEqualTo("ISSUED");
        assertThat(service.markDelivered(lr.getId()).status()).isEqualTo("DELIVERED");
    }
}
