package com.katasticho.erp.ai.service;

import com.katasticho.erp.ai.dto.AiSuggestionReviewRequest;
import com.katasticho.erp.ai.dto.BillDraftFromScanRequest;
import com.katasticho.erp.ai.dto.BillDraftResult;
import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiPatternRepository;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ap.dto.CreatePurchaseBillRequest;
import com.katasticho.erp.ap.dto.PurchaseBillResponse;
import com.katasticho.erp.ap.service.PurchaseBillService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.inventory.entity.HsnGstMaster;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.HsnGstMasterRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class BillDraftingServiceTest {

    private final PurchaseBillService purchaseBillService = mock(PurchaseBillService.class);
    private final com.katasticho.erp.contact.repository.ContactRepository contactRepository =
            mock(com.katasticho.erp.contact.repository.ContactRepository.class);
    private final ItemRepository itemRepository = mock(ItemRepository.class);
    private final HsnGstMasterRepository hsnGstMasterRepository = mock(HsnGstMasterRepository.class);
    private final AiSuggestionService aiSuggestionService = mock(AiSuggestionService.class);
    private final AiSuggestionRepository aiSuggestionRepository = mock(AiSuggestionRepository.class);
    private final AiPatternRepository aiPatternRepository = mock(AiPatternRepository.class);

    private final BillDraftingService service = new BillDraftingService(
            purchaseBillService, contactRepository, itemRepository, hsnGstMasterRepository,
            aiSuggestionService, aiSuggestionRepository, aiPatternRepository);

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID suggestionId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
        // createSuggestion echoes the entity back with an id assigned.
        when(aiSuggestionService.createSuggestion(any(AiSuggestion.class))).thenAnswer(inv -> {
            AiSuggestion s = inv.getArgument(0);
            s.setId(suggestionId);
            return s;
        });
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void draftMatchesVendorByGstinAndItemBecomesGoodsLine() {
        UUID vendorId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        UUID billId = UUID.randomUUID();

        Contact vendor = vendor(vendorId, "ABC Pharma", "27AABCT1234A1Z5");
        when(contactRepository.findFirstByOrgIdAndGstinIgnoreCaseAndIsDeletedFalse(orgId, "27AABCT1234A1Z5"))
                .thenReturn(Optional.of(vendor));

        Item item = new Item();
        item.setId(itemId);
        item.setName("Crocin 500mg");
        when(itemRepository.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, "Crocin 500mg"))
                .thenReturn(Optional.of(item));

        when(purchaseBillService.createBill(any(CreatePurchaseBillRequest.class)))
                .thenReturn(draftBill(billId, vendorId, "BILL-2026-0001"));

        BillDraftFromScanRequest req = new BillDraftFromScanRequest(
                "ABC Pharma", "27AABCT1234A1Z5", "MH", "INV-77",
                LocalDate.of(2026, 6, 1), LocalDate.of(2026, 7, 1), null, 0.92,
                List.of(new BillDraftFromScanRequest.ScanLine(
                        "Crocin 500mg", "3004", new BigDecimal("10"), new BigDecimal("95"),
                        new BigDecimal("12"), null)));

        BillDraftResult result = service.draftFromScan(req);

        assertThat(result.billId()).isEqualTo(billId);
        assertThat(result.suggestionId()).isEqualTo(suggestionId);
        assertThat(result.vendorCreated()).isFalse();
        assertThat(result.unmatchedItemCount()).isZero();
        assertThat(result.status()).isEqualTo("DRAFT");

        ArgumentCaptor<CreatePurchaseBillRequest> captor =
                ArgumentCaptor.forClass(CreatePurchaseBillRequest.class);
        verify(purchaseBillService).createBill(captor.capture());
        CreatePurchaseBillRequest sent = captor.getValue();
        assertThat(sent.contactId()).isEqualTo(vendorId);
        assertThat(sent.lines()).hasSize(1);
        CreatePurchaseBillRequest.BillLineRequest line = sent.lines().get(0);
        assertThat(line.lineType()).isEqualTo("GOODS");
        assertThat(line.itemId()).isEqualTo(itemId);
        assertThat(line.gstRate()).isEqualByComparingTo("12");

        // Vendor matched cleanly — no contact mutation.
        verify(contactRepository, never()).save(any(Contact.class));
    }

    @Test
    void draftCreatesVendorAndUnmatchedItemBecomesServiceWithHsnGst() {
        UUID newVendorId = UUID.randomUUID();
        UUID billId = UUID.randomUUID();

        when(contactRepository.findFirstByOrgIdAndGstinIgnoreCaseAndIsDeletedFalse(any(), any()))
                .thenReturn(Optional.empty());
        when(contactRepository.findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(any(), any()))
                .thenReturn(Optional.empty());
        when(contactRepository.save(any(Contact.class))).thenAnswer(inv -> {
            Contact c = inv.getArgument(0);
            if (c.getId() == null) c.setId(newVendorId);
            return c;
        });
        when(itemRepository.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(any(), any()))
                .thenReturn(Optional.empty());
        // gstRate not on the bill → infer from HSN master.
        HsnGstMaster hsn = new HsnGstMaster();
        hsn.setHsnCode("3004");
        hsn.setGstRate(new BigDecimal("12.00"));
        when(hsnGstMasterRepository.findByHsnCodeAndActiveTrue("3004")).thenReturn(Optional.of(hsn));

        when(purchaseBillService.createBill(any(CreatePurchaseBillRequest.class)))
                .thenReturn(draftBill(billId, newVendorId, "BILL-2026-0002"));

        BillDraftFromScanRequest req = new BillDraftFromScanRequest(
                "New Supplier Co", null, "MH", "INV-9",
                LocalDate.of(2026, 6, 2), null, null, 0.7,
                List.of(new BillDraftFromScanRequest.ScanLine(
                        "Unknown Widget", "3004", new BigDecimal("5"), new BigDecimal("40"),
                        null, null)));

        BillDraftResult result = service.draftFromScan(req);

        assertThat(result.vendorCreated()).isTrue();
        assertThat(result.contactId()).isEqualTo(newVendorId);
        assertThat(result.unmatchedItemCount()).isEqualTo(1);
        assertThat(result.warnings()).anyMatch(w -> w.contains("New vendor created"));

        ArgumentCaptor<CreatePurchaseBillRequest> captor =
                ArgumentCaptor.forClass(CreatePurchaseBillRequest.class);
        verify(purchaseBillService).createBill(captor.capture());
        CreatePurchaseBillRequest.BillLineRequest line = captor.getValue().lines().get(0);
        assertThat(line.lineType()).isEqualTo("SERVICE");
        assertThat(line.itemId()).isNull();
        assertThat(line.gstRate()).isEqualByComparingTo("12.00");
        verify(contactRepository).save(any(Contact.class));
    }

    @Test
    void approvePostsBillLearnsAndMarksAccepted() {
        UUID billId = UUID.randomUUID();
        UUID contactId = UUID.randomUUID();
        UUID accountId = UUID.randomUUID();

        AiSuggestion suggestion = AiSuggestion.builder()
                .id(suggestionId).orgId(orgId)
                .entityType("PURCHASE_BILL").entityId(billId)
                .suggestionType("DRAFT_BILL").status("PENDING")
                .confidence(new BigDecimal("0.900"))
                .build();
        when(aiSuggestionRepository.findByIdAndOrgId(suggestionId, orgId))
                .thenReturn(Optional.of(suggestion));

        PurchaseBillResponse posted = postedBill(billId, contactId, accountId);
        when(purchaseBillService.postBill(billId)).thenReturn(posted);

        BillDraftResult result = service.approve(suggestionId);

        assertThat(result.billId()).isEqualTo(billId);
        assertThat(result.status()).isEqualTo("OPEN");

        verify(purchaseBillService).postBill(billId);
        verify(aiSuggestionService).review(eq(suggestionId),
                argThat((AiSuggestionReviewRequest r) -> "ACCEPT".equals(r.action())));
        // Learned the vendor+HSN → account mapping.
        verify(aiPatternRepository).save(any());
    }

    @Test
    void rejectDeletesDraftAndMarksRejected() {
        UUID billId = UUID.randomUUID();
        AiSuggestion suggestion = AiSuggestion.builder()
                .id(suggestionId).orgId(orgId)
                .entityType("PURCHASE_BILL").entityId(billId)
                .suggestionType("DRAFT_BILL").status("PENDING")
                .build();
        when(aiSuggestionRepository.findByIdAndOrgId(suggestionId, orgId))
                .thenReturn(Optional.of(suggestion));

        service.reject(suggestionId, "Wrong vendor");

        verify(purchaseBillService).deleteBill(billId);
        verify(aiSuggestionService).review(eq(suggestionId),
                argThat((AiSuggestionReviewRequest r) -> "REJECT".equals(r.action())));
    }

    @Test
    void approveRejectsNonDraftBillSuggestion() {
        AiSuggestion suggestion = AiSuggestion.builder()
                .id(suggestionId).orgId(orgId)
                .entityType("INVOICE").entityId(UUID.randomUUID())
                .suggestionType("HIGH_VALUE_INVOICE").status("PENDING")
                .build();
        when(aiSuggestionRepository.findByIdAndOrgId(suggestionId, orgId))
                .thenReturn(Optional.of(suggestion));

        assertThatThrownBy(() -> service.approve(suggestionId))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("not a drafted bill");

        verify(purchaseBillService, never()).postBill(any());
    }

    // ── fixtures ─────────────────────────────────────────────────────────

    private Contact vendor(UUID id, String name, String gstin) {
        Contact c = Contact.builder()
                .contactType(ContactType.VENDOR)
                .displayName(name)
                .gstin(gstin)
                .build();
        c.setId(id);
        c.setOrgId(orgId);
        return c;
    }

    private PurchaseBillResponse draftBill(UUID id, UUID contactId, String number) {
        return new PurchaseBillResponse(
                id, contactId, "ABC Pharma", number, "INV-77",
                LocalDate.of(2026, 6, 1), LocalDate.of(2026, 7, 1), "DRAFT",
                new BigDecimal("950"), new BigDecimal("114"), new BigDecimal("1064"),
                BigDecimal.ZERO, new BigDecimal("1064"), BigDecimal.ZERO,
                "INR", "MH", false, null, null, null, null, null, null, null, List.of(), Instant.now());
    }

    private PurchaseBillResponse postedBill(UUID id, UUID contactId, UUID accountId) {
        PurchaseBillResponse.LineResponse line = new PurchaseBillResponse.LineResponse(
                UUID.randomUUID(), 1, "Crocin 500mg", "3004", UUID.randomUUID(), accountId,
                new BigDecimal("10"), new BigDecimal("95"), BigDecimal.ZERO, BigDecimal.ZERO,
                new BigDecimal("950"), new BigDecimal("12"), new BigDecimal("114"), new BigDecimal("1064"),
                null);
        return new PurchaseBillResponse(
                id, contactId, "ABC Pharma", "BILL-2026-0001", "INV-77",
                LocalDate.of(2026, 6, 1), LocalDate.of(2026, 7, 1), "OPEN",
                new BigDecimal("950"), new BigDecimal("114"), new BigDecimal("1064"),
                BigDecimal.ZERO, new BigDecimal("1064"), BigDecimal.ZERO,
                "INR", "MH", false, UUID.randomUUID(), null, null, null, null, null, null, List.of(line), Instant.now());
    }
}
