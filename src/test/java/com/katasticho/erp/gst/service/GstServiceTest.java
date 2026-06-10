package com.katasticho.erp.gst.service;

import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ar.repository.CreditNoteRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.entity.HsnGstMaster;
import com.katasticho.erp.inventory.repository.HsnGstMasterRepository;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.pos.entity.SalesReceipt;
import com.katasticho.erp.pos.entity.SalesReceiptLine;
import com.katasticho.erp.pos.repository.SalesReceiptRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Covers the POS-receipt inclusion in GSTR-1 (B2CS + HSN) and GSTR-3B outward. */
class GstServiceTest {

    private final InvoiceRepository invoiceRepository = mock(InvoiceRepository.class);
    private final CreditNoteRepository creditNoteRepository = mock(CreditNoteRepository.class);
    private final PurchaseBillRepository purchaseBillRepository = mock(PurchaseBillRepository.class);
    private final TaxLineItemRepository taxLineItemRepository = mock(TaxLineItemRepository.class);
    private final ContactRepository contactRepository = mock(ContactRepository.class);
    private final OrganisationRepository organisationRepository = mock(OrganisationRepository.class);
    private final SalesReceiptRepository salesReceiptRepository = mock(SalesReceiptRepository.class);
    private final HsnGstMasterRepository hsnGstMasterRepository = mock(HsnGstMasterRepository.class);

    private final GstService service = new GstService(
            invoiceRepository, creditNoteRepository, purchaseBillRepository,
            taxLineItemRepository, contactRepository, organisationRepository,
            salesReceiptRepository, hsnGstMasterRepository);

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        when(invoiceRepository.findPostedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of());
        when(creditNoteRepository
                .findByOrgIdAndIsDeletedFalseAndCreditNoteDateBetweenAndStatusNot(
                        eq(orgId), any(), any(), anyString()))
                .thenReturn(List.of());
        when(purchaseBillRepository.findPostedByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of());
        when(organisationRepository.findById(orgId)).thenReturn(Optional.empty());
        when(contactRepository.findAllById(any())).thenReturn(List.of());

        HsnGstMaster hsn = new HsnGstMaster();
        hsn.setHsnCode("3004");
        hsn.setGstRate(new BigDecimal("12.00"));
        when(hsnGstMasterRepository.findByHsnCodeAndActiveTrue("3004"))
                .thenReturn(Optional.of(hsn));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    @SuppressWarnings("unchecked")
    void gstr1IncludesPosReceiptsInB2csAndHsnSummary() {
        when(salesReceiptRepository.findByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of(intraStateReceipt()));

        Map<String, Object> gstr1 = service.generateGstr1(2026, 5);

        List<Map<String, Object>> b2cs = (List<Map<String, Object>>) gstr1.get("b2cs");
        assertThat(b2cs).hasSize(1);
        Map<String, Object> row = b2cs.get(0);
        assertThat(row.get("sply_tp")).isEqualTo("INTRA");
        // 112 inclusive at 12% → 100 taxable, 6 CGST + 6 SGST.
        assertThat((BigDecimal) row.get("txval")).isEqualByComparingTo("100.00");
        assertThat((BigDecimal) row.get("camt")).isEqualByComparingTo("6.00");
        assertThat((BigDecimal) row.get("samt")).isEqualByComparingTo("6.00");
        assertThat((BigDecimal) row.get("iamt")).isEqualByComparingTo("0");

        List<Map<String, Object>> hsn = (List<Map<String, Object>>) gstr1.get("hsnsac");
        assertThat(hsn).extracting(m -> m.get("hsn_sc")).contains("3004");
        Map<String, Object> hsnRow = hsn.stream()
                .filter(m -> "3004".equals(m.get("hsn_sc"))).findFirst().orElseThrow();
        assertThat((BigDecimal) hsnRow.get("tot_tx")).isEqualByComparingTo("12.00");

        Map<String, Object> meta = (Map<String, Object>) gstr1.get("_meta");
        assertThat(meta.get("posReceiptCount")).isEqualTo(1);
    }

    @Test
    void gstr3bIncludesPosReceiptsInOutwardSupplies() {
        when(salesReceiptRepository.findByOrgAndDateRange(eq(orgId), any(), any()))
                .thenReturn(List.of(intraStateReceipt()));
        when(taxLineItemRepository.findByOrgAndSourceTypesAndRegimeAndSourceIds(
                any(), any(), any(), any())).thenReturn(List.of());

        Map<String, Object> gstr3b = service.generateGstr3b(2026, 5);

        assertThat((BigDecimal) gstr3b.get("totalTaxable")).isEqualByComparingTo("100");
        assertThat((BigDecimal) gstr3b.get("totalCgst")).isEqualByComparingTo("6");
        assertThat((BigDecimal) gstr3b.get("totalSgst")).isEqualByComparingTo("6");
        assertThat((BigDecimal) gstr3b.get("totalTax")).isEqualByComparingTo("12");
        // No purchase bills → no ITC → everything payable.
        assertThat((BigDecimal) gstr3b.get("netPayable")).isEqualByComparingTo("12");
        assertThat(gstr3b.get("posReceiptCount")).isEqualTo(1);
    }

    private SalesReceipt intraStateReceipt() {
        SalesReceipt receipt = SalesReceipt.builder()
                .receiptNumber("RCT-001")
                .receiptDate(LocalDate.of(2026, 5, 10))
                .subtotal(new BigDecimal("100"))
                .taxAmount(new BigDecimal("12"))
                .cgst(new BigDecimal("6"))
                .sgst(new BigDecimal("6"))
                .igst(BigDecimal.ZERO)
                .total(new BigDecimal("112"))
                .build();
        receipt.setOrgId(orgId);
        receipt.addLine(SalesReceiptLine.builder()
                .lineNumber(1)
                .description("Crocin 500mg")
                .quantity(BigDecimal.ONE)
                .rate(new BigDecimal("112"))
                .hsnCode("3004")
                .amount(new BigDecimal("112"))
                .build());
        return receipt;
    }
}
