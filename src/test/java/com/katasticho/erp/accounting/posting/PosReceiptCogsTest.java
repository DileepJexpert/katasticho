package com.katasticho.erp.accounting.posting;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.service.CostResolverService;
import com.katasticho.erp.pos.entity.PaymentMode;
import com.katasticho.erp.pos.entity.SalesReceipt;
import com.katasticho.erp.pos.entity.SalesReceiptLine;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

/**
 * COGS posting on a POS receipt under the V5 provisional-cost regime.
 *
 *   - Item with a known purchase price: legacy path — DR COGS / CR Inventory.
 *   - Item without (bill-freely): provisional path — DR COGS / CR Stock-Out
 *     Suspense (2042). The Suspense leg is later closed by ProvisionalCostReconciler.
 *   - Item with NO cost basis at all: revenue + cash only, no COGS line.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PosReceiptCogsTest {

    @Mock private JournalService journalService;
    @Mock private com.katasticho.erp.accounting.defaults.service.DefaultAccountService defaultAccountService;
    @Mock private com.katasticho.erp.ar.repository.TaxLineItemRepository taxLineItemRepository;
    @Mock private com.katasticho.erp.accounting.repository.AccountRepository accountRepository;
    @Mock private SalesInvoicePostingRule salesInvoicePostingRule;
    @Mock private CostResolverService costResolverService;

    @InjectMocks private AccountingPostingEngine engine;

    private final UUID orgId = UUID.randomUUID();
    private final UUID itemId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        when(defaultAccountService.getCode(eq(orgId), eq(DefaultAccountPurpose.CASH))).thenReturn("1010");
        when(defaultAccountService.getCode(eq(orgId), eq(DefaultAccountPurpose.SALES_REVENUE))).thenReturn("4010");
        when(defaultAccountService.getCode(eq(orgId), eq(DefaultAccountPurpose.COGS))).thenReturn("5010");
        when(defaultAccountService.getCode(eq(orgId), eq(DefaultAccountPurpose.INVENTORY_ASSET))).thenReturn("1200");
        when(defaultAccountService.getCode(eq(orgId), eq(DefaultAccountPurpose.STOCK_OUT_SUSPENSE))).thenReturn("2042");
        JournalEntry je = new JournalEntry();
        when(journalService.postJournal(any())).thenReturn(je);
    }

    private SalesReceipt buildReceipt(BigDecimal lineRate, BigDecimal qty) {
        SalesReceipt r = SalesReceipt.builder()
                .receiptNumber("SR-2026-000001")
                .receiptDate(LocalDate.of(2026, 6, 22))
                .paymentMode(PaymentMode.CASH)
                .subtotal(lineRate.multiply(qty))
                .taxAmount(BigDecimal.ZERO)
                .total(lineRate.multiply(qty))
                .build();
        r.setOrgId(orgId);

        SalesReceiptLine line = SalesReceiptLine.builder()
                .lineNumber(1)
                .itemId(itemId)
                .quantity(qty)
                .baseQuantity(qty)
                .rate(lineRate)
                .amount(lineRate.multiply(qty))
                .build();
        r.addLine(line);
        return r;
    }

    private Item trackedItem(BigDecimal purchasePrice, BigDecimal mrp) {
        return Item.builder()
                .name("Test")
                .sku("SKU")
                .trackInventory(true)
                .purchasePrice(purchasePrice)
                .mrp(mrp)
                .build();
    }

    private JournalPostRequest capturePost() {
        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        org.mockito.Mockito.verify(journalService).postJournal(captor.capture());
        return captor.getValue();
    }

    @Test
    void knownPurchasePrice_postsRealCogsAgainstInventory() {
        SalesReceipt r = buildReceipt(new BigDecimal("30.00"), new BigDecimal("2"));
        Item item = trackedItem(new BigDecimal("20.00"), new BigDecimal("30.00"));
        when(costResolverService.resolve(any(Item.class), eq(orgId)))
                .thenReturn(new CostResolverService.CostBasis(
                        new BigDecimal("20.00"), false, "PURCHASE_PRICE"));

        engine.postPosReceipt(r, List.of(), Map.of(itemId, item));

        List<JournalLineRequest> lines = capturePost().lines();
        // Should contain DR COGS 40 / CR Inventory 40 — no Suspense leg.
        assertThat(lines)
                .extracting(JournalLineRequest::accountCode,
                            JournalLineRequest::debit,
                            JournalLineRequest::credit)
                .contains(
                        tuple("5010", new BigDecimal("40.00"), BigDecimal.ZERO),
                        tuple("1200", BigDecimal.ZERO, new BigDecimal("40.00"))
                )
                .doesNotContain(
                        tuple("2042", BigDecimal.ZERO, new BigDecimal("40.00"))
                );
    }

    @Test
    void provisionalBasis_postsProvisionalCogsAgainstStockOutSuspense() {
        SalesReceipt r = buildReceipt(new BigDecimal("30.00"), new BigDecimal("2"));
        Item item = trackedItem(BigDecimal.ZERO, new BigDecimal("30.00"));
        // MRP × (1 − 0.25) = 22.50
        when(costResolverService.resolve(any(Item.class), eq(orgId)))
                .thenReturn(new CostResolverService.CostBasis(
                        new BigDecimal("22.50"), true, "MRP_MINUS_MARGIN"));

        engine.postPosReceipt(r, List.of(), Map.of(itemId, item));

        List<JournalLineRequest> lines = capturePost().lines();
        // 22.50 × 2 = 45.00. DR COGS 45 / CR Suspense (2042) 45. No Inventory leg.
        assertThat(lines)
                .extracting(JournalLineRequest::accountCode,
                            JournalLineRequest::debit,
                            JournalLineRequest::credit)
                .contains(
                        tuple("5010", new BigDecimal("45.00"), BigDecimal.ZERO),
                        tuple("2042", BigDecimal.ZERO, new BigDecimal("45.00"))
                )
                .doesNotContain(
                        tuple("1200", BigDecimal.ZERO, new BigDecimal("45.00"))
                );
    }

    @Test
    void noCostBasis_postsRevenueOnly_noCogsLine() {
        SalesReceipt r = buildReceipt(new BigDecimal("30.00"), new BigDecimal("2"));
        Item item = trackedItem(BigDecimal.ZERO, null);
        item.setSalePrice(BigDecimal.ZERO);
        when(costResolverService.resolve(any(Item.class), eq(orgId))).thenReturn(null);

        engine.postPosReceipt(r, List.of(), Map.of(itemId, item));

        List<JournalLineRequest> lines = capturePost().lines();
        // No 5010 / 1200 / 2042 lines at all — just cash + revenue.
        assertThat(lines)
                .extracting(JournalLineRequest::accountCode)
                .doesNotContain("5010", "1200", "2042")
                .contains("1010", "4010");
    }
}
