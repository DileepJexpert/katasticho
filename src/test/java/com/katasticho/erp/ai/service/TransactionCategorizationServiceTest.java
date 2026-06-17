package com.katasticho.erp.ai.service;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.ai.dto.CategorySuggestion;
import com.katasticho.erp.ai.entity.AiPattern;
import com.katasticho.erp.ai.repository.AiPatternRepository;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.entity.PurchaseBillLine;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.common.context.TenantContext;
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
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class TransactionCategorizationServiceTest {

    @Mock private AiPatternRepository aiPatternRepository;
    @Mock private AccountRepository accountRepository;
    @Mock private PurchaseBillRepository purchaseBillRepository;
    private TransactionCategorizationService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID vendor = UUID.randomUUID();
    private final UUID travelAcct = UUID.randomUUID();
    private final UUID stationeryAcct = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new TransactionCategorizationService(
                aiPatternRepository, accountRepository, purchaseBillRepository);
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private AiPattern pattern(UUID contactId, String hsn, UUID accountId, String confidence, int matchCount) {
        Map<String, Object> key = new HashMap<>();
        key.put("key", contactId + "|" + (hsn == null ? "" : hsn));
        key.put("contactId", contactId.toString());
        key.put("hsn", hsn == null ? "" : hsn);
        Map<String, Object> result = new HashMap<>();
        result.put("accountId", accountId.toString());
        return AiPattern.builder()
                .id(UUID.randomUUID()).orgId(orgId).patternType("PURCHASE_LINE_ACCOUNT")
                .patternKey(key).predictedResult(result)
                .confidence(new BigDecimal(confidence)).matchCount(matchCount)
                .status("ACTIVE").build();
    }

    private void account(UUID id, String code, String name) {
        Account a = new Account();
        a.setId(id);
        a.setCode(code);
        a.setName(name);
        when(accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, id)).thenReturn(Optional.of(a));
    }

    @Test
    void suggest_exactHsnMatch_preferredOverVendorOnly() {
        account(travelAcct, "5240", "Travel & Conveyance");
        account(stationeryAcct, "5260", "Printing & Stationery");
        // vendor-only pattern has higher confidence, but the exact HSN match must win.
        when(aiPatternRepository.findByOrgIdAndPatternTypeAndStatusOrderByConfidenceDesc(
                orgId, "PURCHASE_LINE_ACCOUNT", "ACTIVE"))
                .thenReturn(List.of(
                        pattern(vendor, "", stationeryAcct, "0.900", 9),
                        pattern(vendor, "4820", travelAcct, "0.700", 4)));

        CategorySuggestion s = service.suggest(vendor, "4820").orElseThrow();

        assertEquals(travelAcct, s.accountId());
        assertEquals("5240", s.accountCode());
        assertEquals("EXACT", s.source());
        assertEquals(0.7, s.confidence(), 0.0001);
        assertEquals(4, s.observations());
    }

    @Test
    void suggest_noHsnMatch_fallsBackToVendorPattern() {
        account(stationeryAcct, "5260", "Printing & Stationery");
        when(aiPatternRepository.findByOrgIdAndPatternTypeAndStatusOrderByConfidenceDesc(
                orgId, "PURCHASE_LINE_ACCOUNT", "ACTIVE"))
                .thenReturn(List.of(pattern(vendor, "4820", stationeryAcct, "0.800", 5)));

        // Asking for a different HSN → no exact match, but vendor-only fallback applies.
        CategorySuggestion s = service.suggest(vendor, "9999").orElseThrow();

        assertEquals(stationeryAcct, s.accountId());
        assertEquals("VENDOR", s.source());
    }

    @Test
    void suggest_unknownVendor_isEmpty() {
        when(aiPatternRepository.findByOrgIdAndPatternTypeAndStatusOrderByConfidenceDesc(
                orgId, "PURCHASE_LINE_ACCOUNT", "ACTIVE"))
                .thenReturn(List.of(pattern(UUID.randomUUID(), "4820", travelAcct, "0.800", 5)));

        assertTrue(service.suggest(vendor, "4820").isEmpty());
    }

    @Test
    void suggest_accountDeletedSinceLearned_isEmpty() {
        when(aiPatternRepository.findByOrgIdAndPatternTypeAndStatusOrderByConfidenceDesc(
                orgId, "PURCHASE_LINE_ACCOUNT", "ACTIVE"))
                .thenReturn(List.of(pattern(vendor, "4820", travelAcct, "0.800", 5)));
        when(accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, travelAcct))
                .thenReturn(Optional.empty());

        assertTrue(service.suggest(vendor, "4820").isEmpty());
    }

    @Test
    void backfill_picksMajorityAccountAndWritesConfidence() {
        // Three bills for the same vendor+HSN: travel twice, stationery once → travel wins (2/3).
        PurchaseBill b1 = bill(vendor, line("4820", travelAcct));
        PurchaseBill b2 = bill(vendor, line("4820", travelAcct));
        PurchaseBill b3 = bill(vendor, line("4820", stationeryAcct));
        when(purchaseBillRepository.findPostedByOrgAndDateRange(eq(orgId), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of(b1, b2, b3));
        when(aiPatternRepository.findByOrgIdAndPatternTypeAndStatusOrderByConfidenceDesc(
                orgId, "PURCHASE_LINE_ACCOUNT", "ACTIVE"))
                .thenReturn(List.of());

        int learned = service.backfillFromHistory(365);

        assertEquals(1, learned);
        ArgumentCaptor<AiPattern> captor = ArgumentCaptor.forClass(AiPattern.class);
        verify(aiPatternRepository).save(captor.capture());
        AiPattern saved = captor.getValue();
        assertEquals(travelAcct.toString(), saved.getPredictedResult().get("accountId"));
        assertEquals(vendor + "|4820", saved.getPatternKey().get("key"));
        // 2 of 3 observations → 0.667 confidence.
        assertEquals(0.667, saved.getConfidence().doubleValue(), 0.0005);
        assertEquals(3, saved.getMatchCount());
    }

    private PurchaseBill bill(UUID contactId, PurchaseBillLine... lines) {
        return PurchaseBill.builder().id(UUID.randomUUID()).orgId(orgId)
                .contactId(contactId).lines(List.of(lines)).build();
    }

    private PurchaseBillLine line(String hsn, UUID accountId) {
        return PurchaseBillLine.builder().id(UUID.randomUUID())
                .hsnCode(hsn).accountId(accountId).build();
    }
}
