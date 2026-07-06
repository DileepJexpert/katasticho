package com.katasticho.erp.pharma.register;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.pharma.entity.PrescriptionRecord;
import com.katasticho.erp.pharma.repository.PrescriptionRecordRepository;
import com.katasticho.erp.pos.entity.SalesReceipt;
import com.katasticho.erp.pos.entity.SalesReceiptLine;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
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
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class StatutoryRegisterServiceTest {

    @Mock private StatutoryRegisterRepository registerRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private StockBatchRepository stockBatchRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private PrescriptionRecordRepository prescriptionRepository;
    @Mock private OrgSettingsService orgSettingsService;

    private StatutoryRegisterService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID receiptId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new StatutoryRegisterService(
                registerRepository, itemRepository, stockBatchRepository,
                contactRepository, prescriptionRepository, orgSettingsService);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
        lenient().when(registerRepository.save(any())).thenAnswer(i -> i.getArgument(0));
    }

    @AfterEach
    void clear() { TenantContext.clear(); }

    // ── Retention math per schedule type ─────────────────────────

    @Test
    void h1_sale_creates_entry_with_three_year_retention() {
        Item h1Item = pharmaItem("Augmentin 625", "H1");
        SalesReceipt receipt = receiptOf(LocalDate.of(2026, 3, 15), line(h1Item, "5"));

        when(orgSettingsService.get(orgId, "pharma.h1_strict", "false")).thenReturn("false");
        when(prescriptionRepository.findByReceiptIdAndOrgIdAndIsDeletedFalse(receiptId, orgId))
                .thenReturn(Optional.empty());

        List<StatutoryRegisterEntry> rows = service.recordSaleEntries(receipt, Map.of(h1Item.getId(), h1Item));

        assertEquals(1, rows.size());
        StatutoryRegisterEntry r = rows.get(0);
        assertEquals(RegisterType.H1, r.getRegisterType());
        assertEquals(LocalDate.of(2029, 3, 15), r.getRetentionUntil());
        assertEquals("Augmentin 625", r.getDrugName());
        assertEquals(new BigDecimal("5"), r.getQuantity());
    }

    @Test
    void schedule_x_sale_creates_entry_with_two_year_retention() {
        Item xItem = pharmaItem("Pentazocine", "SCHEDULE_X");
        SalesReceipt receipt = receiptOf(LocalDate.of(2026, 6, 1), line(xItem, "2"));

        when(orgSettingsService.get(orgId, "pharma.h1_strict", "false")).thenReturn("false");

        List<StatutoryRegisterEntry> rows = service.recordSaleEntries(receipt, Map.of(xItem.getId(), xItem));

        assertEquals(1, rows.size());
        assertEquals(RegisterType.SCHEDULE_X, rows.get(0).getRegisterType());
        assertEquals(LocalDate.of(2028, 6, 1), rows.get(0).getRetentionUntil());
    }

    @Test
    void narcotics_sale_creates_entry_with_two_year_retention() {
        Item narc = pharmaItem("Morphine Sulphate", "NARCOTICS");
        SalesReceipt receipt = receiptOf(LocalDate.of(2026, 6, 20), line(narc, "1"));

        when(orgSettingsService.get(orgId, "pharma.h1_strict", "false")).thenReturn("false");

        List<StatutoryRegisterEntry> rows = service.recordSaleEntries(receipt, Map.of(narc.getId(), narc));

        assertEquals(1, rows.size());
        assertEquals(RegisterType.NARCOTICS, rows.get(0).getRegisterType());
        assertEquals(LocalDate.of(2028, 6, 20), rows.get(0).getRetentionUntil());
    }

    // ── Selective recording: only scheduled drugs ─────────────────

    @Test
    void non_scheduled_item_creates_no_register_entry() {
        Item normal = pharmaItem("Paracetamol 500", null);
        Item generalH = pharmaItem("Random Schedule H", "H");   // Schedule H (general) is NOT tracked here
        SalesReceipt receipt = receiptOf(LocalDate.now(), line(normal, "10"), line(generalH, "1"));

        when(orgSettingsService.get(orgId, "pharma.h1_strict", "false")).thenReturn("false");

        List<StatutoryRegisterEntry> rows = service.recordSaleEntries(receipt,
                Map.of(normal.getId(), normal, generalH.getId(), generalH));

        assertTrue(rows.isEmpty(), "non-scheduled items should never write to the H1/X/NARCOTICS register");
        verify(registerRepository, never()).save(any());
    }

    // ── Prescriber + patient linkage ─────────────────────────────

    @Test
    void linked_prescription_populates_prescriber_fields() {
        Item h1Item = pharmaItem("Augmentin 625", "H1");
        UUID contactId = UUID.randomUUID();
        SalesReceipt receipt = receiptOf(LocalDate.now(), line(h1Item, "3"));
        receipt.setContactId(contactId);

        Contact patient = new Contact();
        patient.setDisplayName("Asha Patel");
        patient.setMobile("9876543210");
        patient.setBillingAddressLine1("12 MG Road");
        patient.setBillingCity("Pune");
        patient.setBillingState("Maharashtra");

        PrescriptionRecord rx = PrescriptionRecord.builder()
                .doctorName("Dr. R. Sharma")
                .doctorRegNumber("MMC-44219")
                .notes("Clinic at Shivajinagar")
                .receiptId(receiptId)
                .build();

        when(orgSettingsService.get(orgId, "pharma.h1_strict", "false")).thenReturn("false");
        when(prescriptionRepository.findByReceiptIdAndOrgIdAndIsDeletedFalse(receiptId, orgId))
                .thenReturn(Optional.of(rx));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(patient));

        List<StatutoryRegisterEntry> rows = service.recordSaleEntries(receipt, Map.of(h1Item.getId(), h1Item));

        assertEquals(1, rows.size());
        StatutoryRegisterEntry r = rows.get(0);
        assertEquals("Dr. R. Sharma", r.getPrescriberName());
        assertEquals("MMC-44219", r.getPrescriberRegNumber());
        assertEquals("Clinic at Shivajinagar", r.getPrescriberAddress());
        assertEquals("Asha Patel", r.getPatientName());
        assertEquals("9876543210", r.getPatientPhone());
        assertTrue(r.getPatientAddress().contains("MG Road"));
        assertTrue(r.getPatientAddress().contains("Pune"));
    }

    // ── h1_strict mode ────────────────────────────────────────────

    @Test
    void no_rx_in_non_strict_mode_records_entry_with_null_prescriber() {
        Item h1Item = pharmaItem("Augmentin 625", "H1");
        SalesReceipt receipt = receiptOf(LocalDate.now(), line(h1Item, "1"));

        when(orgSettingsService.get(orgId, "pharma.h1_strict", "false")).thenReturn("false");
        when(prescriptionRepository.findByReceiptIdAndOrgIdAndIsDeletedFalse(receiptId, orgId))
                .thenReturn(Optional.empty());

        List<StatutoryRegisterEntry> rows = service.recordSaleEntries(receipt, Map.of(h1Item.getId(), h1Item));

        assertEquals(1, rows.size());
        assertNull(rows.get(0).getPrescriberName());
        assertNull(rows.get(0).getPrescriberRegNumber());
    }

    @Test
    void no_rx_in_strict_mode_throws_rx_prescription_required() {
        Item h1Item = pharmaItem("Augmentin 625", "H1");
        SalesReceipt receipt = receiptOf(LocalDate.now(), line(h1Item, "1"));

        when(orgSettingsService.get(orgId, "pharma.h1_strict", "false")).thenReturn("true");
        when(prescriptionRepository.findByReceiptIdAndOrgIdAndIsDeletedFalse(receiptId, orgId))
                .thenReturn(Optional.empty());

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.recordSaleEntries(receipt, Map.of(h1Item.getId(), h1Item)));
        assertEquals("RX_PRESCRIPTION_REQUIRED", ex.getErrorCode());
        verify(registerRepository, never()).save(any());
    }

    @Test
    void inline_prescriber_satisfies_strict_mode_and_populates_columns() {
        // The Rx is normally created AFTER the sale, so strict mode must be
        // satisfiable by prescriber details captured inline at the counter.
        Item h1Item = pharmaItem("Augmentin 625", "H1");
        SalesReceipt receipt = receiptOf(LocalDate.now(), line(h1Item, "1"));

        when(orgSettingsService.get(orgId, "pharma.h1_strict", "false")).thenReturn("true");
        when(prescriptionRepository.findByReceiptIdAndOrgIdAndIsDeletedFalse(receiptId, orgId))
                .thenReturn(Optional.empty());

        var ctx = new StatutoryRegisterService.PrescriberContext(
                "RX-9001", "Dr. K. Menon", "TNMC-77821", "Anna Nagar Clinic, Chennai");

        List<StatutoryRegisterEntry> rows =
                service.recordSaleEntries(receipt, Map.of(h1Item.getId(), h1Item), ctx);

        assertEquals(1, rows.size(), "inline prescriber must let an H1 sale complete under strict mode");
        StatutoryRegisterEntry r = rows.get(0);
        assertEquals("Dr. K. Menon", r.getPrescriberName());
        assertEquals("TNMC-77821", r.getPrescriberRegNumber());
        assertEquals("Anna Nagar Clinic, Chennai", r.getPrescriberAddress());
    }

    @Test
    void inline_prescriber_takes_precedence_over_linked_rx() {
        Item h1Item = pharmaItem("Augmentin 625", "H1");
        SalesReceipt receipt = receiptOf(LocalDate.now(), line(h1Item, "1"));

        PrescriptionRecord rx = PrescriptionRecord.builder()
                .doctorName("Dr. Linked")
                .doctorRegNumber("LINK-1")
                .notes("Linked clinic")
                .receiptId(receiptId)
                .build();

        when(orgSettingsService.get(orgId, "pharma.h1_strict", "false")).thenReturn("false");
        when(prescriptionRepository.findByReceiptIdAndOrgIdAndIsDeletedFalse(receiptId, orgId))
                .thenReturn(Optional.of(rx));

        var ctx = new StatutoryRegisterService.PrescriberContext(
                null, "Dr. Inline", "INLINE-9", null);

        List<StatutoryRegisterEntry> rows =
                service.recordSaleEntries(receipt, Map.of(h1Item.getId(), h1Item), ctx);

        StatutoryRegisterEntry r = rows.get(0);
        assertEquals("Dr. Inline", r.getPrescriberName(), "inline name wins");
        assertEquals("INLINE-9", r.getPrescriberRegNumber(), "inline reg wins");
        // address absent inline -> falls back to the linked Rx notes
        assertEquals("Linked clinic", r.getPrescriberAddress());
    }

    @Test
    void backfill_prescriber_fills_blank_columns_only() {
        StatutoryRegisterEntry blank = StatutoryRegisterEntry.builder()
                .registerType(RegisterType.H1)
                .saleReceiptId(receiptId)
                .itemId(UUID.randomUUID())
                .drugName("Augmentin 625")
                .quantity(BigDecimal.ONE)
                .saleDate(LocalDate.now())
                .retentionUntil(LocalDate.now().plusYears(3))
                .build();
        StatutoryRegisterEntry alreadyCaptured = StatutoryRegisterEntry.builder()
                .registerType(RegisterType.H1)
                .saleReceiptId(receiptId)
                .itemId(UUID.randomUUID())
                .drugName("Zithromax 500")
                .quantity(BigDecimal.ONE)
                .saleDate(LocalDate.now())
                .retentionUntil(LocalDate.now().plusYears(3))
                .prescriberName("Dr. Counter")     // fully captured inline at sale time
                .prescriberRegNumber("COUNTER-1")
                .prescriberAddress("Counter clinic")
                .build();

        when(registerRepository.findByOrgIdAndSaleReceiptIdAndIsDeletedFalse(orgId, receiptId))
                .thenReturn(List.of(blank, alreadyCaptured));

        int updated = service.backfillPrescriber(receiptId, "Dr. Backfill", "REG-7", "Backfill clinic");

        assertEquals(1, updated, "only the blank row is backfilled");
        assertEquals("Dr. Backfill", blank.getPrescriberName());
        assertEquals("REG-7", blank.getPrescriberRegNumber());
        assertEquals("Backfill clinic", blank.getPrescriberAddress());
        // A fully-captured inline row is never overwritten by backfill.
        assertEquals("Dr. Counter", alreadyCaptured.getPrescriberName());
        assertEquals("COUNTER-1", alreadyCaptured.getPrescriberRegNumber());
        assertEquals("Counter clinic", alreadyCaptured.getPrescriberAddress());
        verify(registerRepository, times(1)).save(blank);
        verify(registerRepository, never()).save(alreadyCaptured);
    }

    @Test
    void backfill_prescriber_noop_for_null_receipt() {
        assertEquals(0, service.backfillPrescriber(null, "Dr. X", "R", "A"));
        verify(registerRepository, never()).findByOrgIdAndSaleReceiptIdAndIsDeletedFalse(any(), any());
    }

    @Test
    void strict_mode_only_blocks_h1_not_schedule_x_or_narcotics() {
        // Spec: strict gate is for H1 only — X and NARCOTICS still record even without Rx.
        Item xItem = pharmaItem("Pentazocine", "SCHEDULE_X");
        SalesReceipt receipt = receiptOf(LocalDate.now(), line(xItem, "1"));

        when(orgSettingsService.get(orgId, "pharma.h1_strict", "false")).thenReturn("true");
        // Returns empty (no rx for receipt) — but X is not gated
        List<StatutoryRegisterEntry> rows = service.recordSaleEntries(receipt, Map.of(xItem.getId(), xItem));
        assertEquals(1, rows.size());
        assertEquals(RegisterType.SCHEDULE_X, rows.get(0).getRegisterType());
    }

    // ── Schedule normalisation ───────────────────────────────────

    @Test
    void schedule_normalisation_maps_common_variants() {
        assertEquals(RegisterType.H1, StatutoryRegisterService.classify("H1"));
        assertEquals(RegisterType.H1, StatutoryRegisterService.classify("H-1"));
        assertEquals(RegisterType.H1, StatutoryRegisterService.classify("H1A"));
        assertEquals(RegisterType.H1, StatutoryRegisterService.classify("Sch H1"));
        assertEquals(RegisterType.H1, StatutoryRegisterService.classify("Schedule H1"));
        assertEquals(RegisterType.SCHEDULE_X, StatutoryRegisterService.classify("X"));
        assertEquals(RegisterType.SCHEDULE_X, StatutoryRegisterService.classify("Sch X"));
        assertEquals(RegisterType.SCHEDULE_X, StatutoryRegisterService.classify("Schedule X"));
        assertEquals(RegisterType.NARCOTICS, StatutoryRegisterService.classify("NARCO"));
        assertEquals(RegisterType.NARCOTICS, StatutoryRegisterService.classify("NARCOTIC"));
        assertEquals(RegisterType.NARCOTICS, StatutoryRegisterService.classify("NDPS"));
        // Non-scheduled
        assertNull(StatutoryRegisterService.classify(null));
        assertNull(StatutoryRegisterService.classify(""));
        assertNull(StatutoryRegisterService.classify("   "));
        assertNull(StatutoryRegisterService.classify("H"));          // general Schedule H — not tracked separately
        assertNull(StatutoryRegisterService.classify("OTC"));
    }

    // ── Batch number resolution ──────────────────────────────────

    @Test
    void batch_number_resolved_from_batch_id() {
        Item h1Item = pharmaItem("Augmentin 625", "H1");
        UUID batchId = UUID.randomUUID();
        SalesReceiptLine ln = line(h1Item, "2");
        ln.setBatchId(batchId);
        SalesReceipt receipt = receiptOf(LocalDate.now(), ln);

        StockBatch batch = new StockBatch();
        batch.setBatchNumber("BAT-2026-Q2-117");

        when(orgSettingsService.get(orgId, "pharma.h1_strict", "false")).thenReturn("false");
        when(stockBatchRepository.findByIdAndOrgIdAndIsDeletedFalse(batchId, orgId))
                .thenReturn(Optional.of(batch));

        List<StatutoryRegisterEntry> rows = service.recordSaleEntries(receipt, Map.of(h1Item.getId(), h1Item));

        assertEquals("BAT-2026-Q2-117", rows.get(0).getBatchNumber());
        assertEquals(batchId, rows.get(0).getBatchId());
    }

    // ── CSV export ───────────────────────────────────────────────

    @Test
    void export_csv_emits_header_and_one_row_per_entry() {
        StatutoryRegisterEntry a = StatutoryRegisterEntry.builder()
                .registerType(RegisterType.H1)
                .saleReceiptId(receiptId)
                .itemId(UUID.randomUUID())
                .drugName("Augmentin 625")
                .batchNumber("BAT-A")
                .quantity(new BigDecimal("3"))
                .saleDate(LocalDate.of(2026, 5, 10))
                .retentionUntil(LocalDate.of(2029, 5, 10))
                .prescriberName("Dr. R. Sharma")
                .prescriberRegNumber("MMC-44219")
                .patientName("Asha, Patel")           // contains comma -> CSV-quoted
                .patientPhone("9876543210")
                .build();
        StatutoryRegisterEntry b = StatutoryRegisterEntry.builder()
                .registerType(RegisterType.H1)
                .saleReceiptId(receiptId)
                .itemId(UUID.randomUUID())
                .drugName("Zithromax 500")
                .quantity(new BigDecimal("1"))
                .saleDate(LocalDate.of(2026, 5, 11))
                .retentionUntil(LocalDate.of(2029, 5, 11))
                .build();
        when(registerRepository
                .findByOrgIdAndRegisterTypeAndSaleDateBetweenAndIsDeletedFalseOrderBySaleDateAscCreatedAtAsc(
                        any(), any(), any(), any()))
                .thenReturn(List.of(a, b));

        byte[] bytes = service.exportCsv(RegisterType.H1, LocalDate.of(2026, 5, 1), LocalDate.of(2026, 5, 31));
        String csv = new String(bytes, java.nio.charset.StandardCharsets.UTF_8);

        String[] lines = csv.split("\\r?\\n");
        assertTrue(lines[0].startsWith("Sl No,Sale Date,Drug Name"));
        assertEquals(3, lines.length, "header + 2 rows");
        assertTrue(lines[1].contains("\"Asha, Patel\""), "comma in patient name must be CSV-quoted");
        assertTrue(lines[1].contains("Augmentin 625"));
        assertTrue(lines[1].contains("3"));
        assertTrue(lines[2].contains("Zithromax 500"));
    }

    // ── Helpers ──────────────────────────────────────────────────

    private Item pharmaItem(String name, String schedule) {
        Item it = Item.builder().name(name).drugSchedule(schedule).build();
        it.setId(UUID.randomUUID());
        it.setOrgId(orgId);
        return it;
    }

    private SalesReceiptLine line(Item item, String qty) {
        return SalesReceiptLine.builder()
                .lineNumber(1)
                .itemId(item.getId())
                .description(item.getName())
                .quantity(new BigDecimal(qty))
                .rate(BigDecimal.ZERO)
                .amount(BigDecimal.ZERO)
                .build();
    }

    private SalesReceipt receiptOf(LocalDate date, SalesReceiptLine... lines) {
        SalesReceipt r = SalesReceipt.builder()
                .receiptNumber("SR-TEST-001")
                .receiptDate(date)
                .build();
        r.setId(receiptId);
        r.setOrgId(orgId);
        for (SalesReceiptLine ln : lines) {
            r.addLine(ln);
        }
        return r;
    }
}
