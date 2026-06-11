package com.katasticho.erp.accounting.posting;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.InvoiceLine;
import com.katasticho.erp.ar.entity.TaxLineItem;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.any;

@ExtendWith(MockitoExtension.class)
class SalesInvoicePostingRuleTest {

    @Mock
    private DefaultAccountService defaultAccountService;
    @Mock
    private TaxLineItemRepository taxLineItemRepository;
    @Mock
    private ItemRepository itemRepository;
    @Mock
    private com.katasticho.erp.inventory.service.FifoCostingService fifoCostingService;
    @Mock
    private com.katasticho.erp.sales.repository.DeliveryChallanRepository deliveryChallanRepository;
    @Mock
    private com.katasticho.erp.inventory.repository.StockMovementRepository stockMovementRepository;

    @InjectMocks
    private SalesInvoicePostingRule rule;

    @Test
    void generatesBalancedSalesInvoiceJournalLines() {
        UUID orgId = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        Invoice invoice = invoice(orgId, invoiceId, itemId);

        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR)).thenReturn("1100");
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.COGS)).thenReturn("5010");
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.INVENTORY_ASSET)).thenReturn("1200");
        when(taxLineItemRepository.findBySourceTypeAndSourceId("INVOICE", invoiceId))
                .thenReturn(List.of(tax("2020", "CGST", "500.00"), tax("2021", "SGST", "500.00")));

        Item item = Item.builder()
                .name("Rice")
                .sku("RICE")
                .purchasePrice(new BigDecimal("100.00"))
                .trackInventory(true)
                .build();
        item.setId(itemId);
        when(itemRepository.findAllById(any())).thenReturn(List.of(item));

        JournalPostRequest request = rule.generate(PostingContext.salesInvoice(invoice));

        assertThat(request.effectiveDate()).isEqualTo(LocalDate.of(2026, 5, 12));
        assertThat(request.description()).isEqualTo("Invoice INV-1");
        assertThat(request.sourceModule()).isEqualTo("SALES");
        assertThat(request.sourceId()).isEqualTo(invoiceId);
        assertThat(request.autoPost()).isTrue();

        assertLine(request.lines().get(0), "1100", "21000.00", "0");
        assertLine(request.lines().get(1), "4010", "0", "20000.00");
        assertLine(request.lines().get(2), "2020", "0", "500.00");
        assertLine(request.lines().get(3), "2021", "0", "500.00");
        assertLine(request.lines().get(4), "5010", "10000.00", "0");
        assertLine(request.lines().get(5), "1200", "0", "10000.00");

        BigDecimal debit = request.lines().stream().map(JournalLineRequest::debit).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal credit = request.lines().stream().map(JournalLineRequest::credit).reduce(BigDecimal.ZERO, BigDecimal::add);
        assertThat(debit).isEqualByComparingTo(credit);
    }

    @Test
    void salesOrderInvoicePostsReceivableRevenueTaxAndCogsLedgersOnce() {
        UUID orgId = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();
        UUID salesOrderId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        Invoice invoice = invoice(orgId, invoiceId, itemId);
        invoice.setSalesOrderId(salesOrderId);

        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR)).thenReturn("1100");
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.COGS)).thenReturn("5010");
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.INVENTORY_ASSET)).thenReturn("1200");
        when(taxLineItemRepository.findBySourceTypeAndSourceId("INVOICE", invoiceId))
                .thenReturn(List.of(tax("2020", "CGST", "500.00"), tax("2021", "SGST", "500.00")));

        Item item = Item.builder()
                .name("Rice")
                .sku("RICE")
                .purchasePrice(new BigDecimal("100.00"))
                .trackInventory(true)
                .build();
        item.setId(itemId);
        when(itemRepository.findAllById(any())).thenReturn(List.of(item));

        JournalPostRequest request = rule.generate(PostingContext.salesInvoice(invoice));

        assertThat(request.sourceModule()).isEqualTo("SALES");
        assertThat(request.sourceId()).isEqualTo(invoiceId);
        assertLine(request.lines().get(0), "1100", "21000.00", "0");
        assertLine(request.lines().get(1), "4010", "0", "20000.00");
        assertLine(request.lines().get(2), "2020", "0", "500.00");
        assertLine(request.lines().get(3), "2021", "0", "500.00");
        assertLine(request.lines().get(4), "5010", "10000.00", "0");
        assertLine(request.lines().get(5), "1200", "0", "10000.00");

        BigDecimal debit = request.lines().stream()
                .map(JournalLineRequest::debit)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal credit = request.lines().stream()
                .map(JournalLineRequest::credit)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        assertThat(debit).isEqualByComparingTo("31000.00");
        assertThat(credit).isEqualByComparingTo("31000.00");
    }

    @Test
    void schemeFreeLineSkipsZeroRevenueButIncludesFreeItemCostInCogs() {
        UUID orgId = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();
        UUID paidItemId = UUID.randomUUID();
        UUID freeItemId = UUID.randomUUID();

        Invoice invoice = Invoice.builder()
                .id(invoiceId)
                .orgId(orgId)
                .invoiceNumber("INV-FREE")
                .invoiceDate(LocalDate.of(2026, 5, 13))
                .totalAmount(new BigDecimal("1000.00"))
                .build();
        invoice.setLines(List.of(
                InvoiceLine.builder()
                        .description("Paid strip")
                        .quantity(new BigDecimal("10.00"))
                        .taxableAmount(new BigDecimal("1000.00"))
                        .lineTotal(new BigDecimal("1000.00"))
                        .accountCode("4010")
                        .itemId(paidItemId)
                        .build(),
                InvoiceLine.builder()
                        .description("Scheme free strip")
                        .quantity(BigDecimal.ONE)
                        .taxableAmount(BigDecimal.ZERO)
                        .lineTotal(BigDecimal.ZERO)
                        .accountCode("4010")
                        .itemId(freeItemId)
                        .build()));

        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR)).thenReturn("1100");
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.COGS)).thenReturn("5010");
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.INVENTORY_ASSET)).thenReturn("1200");
        when(taxLineItemRepository.findBySourceTypeAndSourceId("INVOICE", invoiceId))
                .thenReturn(List.of());

        Item paidItem = Item.builder()
                .name("Paid strip")
                .sku("PAID")
                .purchasePrice(new BigDecimal("60.00"))
                .trackInventory(true)
                .build();
        paidItem.setId(paidItemId);
        Item freeItem = Item.builder()
                .name("Free strip")
                .sku("FREE")
                .purchasePrice(new BigDecimal("60.00"))
                .trackInventory(true)
                .build();
        freeItem.setId(freeItemId);
        when(itemRepository.findAllById(any())).thenReturn(List.of(paidItem, freeItem));

        JournalPostRequest request = rule.generate(PostingContext.salesInvoice(invoice));

        assertThat(request.lines()).hasSize(4);
        assertLine(request.lines().get(0), "1100", "1000.00", "0");
        assertLine(request.lines().get(1), "4010", "0", "1000.00");
        assertLine(request.lines().get(2), "5010", "660.00", "0");
        assertLine(request.lines().get(3), "1200", "0", "660.00");

        assertThat(request.lines())
                .noneMatch(line -> line.debit().compareTo(BigDecimal.ZERO) == 0
                        && line.credit().compareTo(BigDecimal.ZERO) == 0);

        BigDecimal debit = request.lines().stream()
                .map(JournalLineRequest::debit)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal credit = request.lines().stream()
                .map(JournalLineRequest::credit)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        assertThat(debit).isEqualByComparingTo("1660.00");
        assertThat(credit).isEqualByComparingTo("1660.00");
    }

    @Test
    void nonInventoryInvoiceLineDoesNotPostCogsOrInventoryLedger() {
        UUID orgId = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        Invoice invoice = invoice(orgId, invoiceId, itemId);

        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR)).thenReturn("1100");
        when(taxLineItemRepository.findBySourceTypeAndSourceId("INVOICE", invoiceId))
                .thenReturn(List.of(tax("2020", "CGST", "500.00"), tax("2021", "SGST", "500.00")));

        Item item = Item.builder()
                .name("Service")
                .sku("SVC")
                .purchasePrice(new BigDecimal("100.00"))
                .trackInventory(false)
                .build();
        item.setId(itemId);
        when(itemRepository.findAllById(any())).thenReturn(List.of(item));

        JournalPostRequest request = rule.generate(PostingContext.salesInvoice(invoice));

        assertThat(request.lines()).hasSize(4);
        assertLine(request.lines().get(0), "1100", "21000.00", "0");
        assertLine(request.lines().get(1), "4010", "0", "20000.00");
        assertLine(request.lines().get(2), "2020", "0", "500.00");
        assertLine(request.lines().get(3), "2021", "0", "500.00");

        BigDecimal debit = request.lines().stream()
                .map(JournalLineRequest::debit)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal credit = request.lines().stream()
                .map(JournalLineRequest::credit)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        assertThat(debit).isEqualByComparingTo(credit);
    }

    @Test
    void tcsInvoicePostsBalancedTcsPayableCredit() {
        UUID orgId = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();
        Invoice invoice = invoice(orgId, invoiceId, null);
        // TCS 206C(1H): ₹21 on top → AR debits 21021, TCS Payable credits 21.
        invoice.setTcsAmount(new BigDecimal("21.00"));
        invoice.setTotalAmount(new BigDecimal("21021.00"));

        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR)).thenReturn("1100");
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.TCS_PAYABLE)).thenReturn("2031");
        when(taxLineItemRepository.findBySourceTypeAndSourceId("INVOICE", invoiceId))
                .thenReturn(List.of(tax("2020", "CGST", "500.00"), tax("2021", "SGST", "500.00")));

        JournalPostRequest request = rule.generate(PostingContext.salesInvoice(invoice));

        assertLine(request.lines().get(0), "1100", "21021.00", "0");
        assertThat(request.lines())
                .anyMatch(l -> l.accountCode().equals("2031")
                        && l.credit().compareTo(new BigDecimal("21.00")) == 0);

        BigDecimal debit = request.lines().stream()
                .map(JournalLineRequest::debit).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal credit = request.lines().stream()
                .map(JournalLineRequest::credit).reduce(BigDecimal.ZERO, BigDecimal::add);
        assertThat(debit).isEqualByComparingTo(credit);
    }

    @Test
    void failsWhenTaxAccountMappingIsMissing() {
        UUID orgId = UUID.randomUUID();
        UUID invoiceId = UUID.randomUUID();
        Invoice invoice = invoice(orgId, invoiceId, null);

        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR)).thenReturn("1100");
        when(taxLineItemRepository.findBySourceTypeAndSourceId("INVOICE", invoiceId))
                .thenReturn(List.of(tax("", "CGST", "500.00")));

        assertThatThrownBy(() -> rule.generate(PostingContext.salesInvoice(invoice)))
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("TAX_ACCOUNT_MAPPING_MISSING");
                    assertThat(ex.getStatus()).isEqualTo(HttpStatus.CONFLICT);
                });
    }

    private Invoice invoice(UUID orgId, UUID invoiceId, UUID itemId) {
        Invoice invoice = Invoice.builder()
                .id(invoiceId)
                .orgId(orgId)
                .invoiceNumber("INV-1")
                .invoiceDate(LocalDate.of(2026, 5, 12))
                .totalAmount(new BigDecimal("21000.00"))
                .build();
        invoice.setLines(List.of(InvoiceLine.builder()
                .description("Rice 100kg")
                .quantity(new BigDecimal("100.00"))
                .taxableAmount(new BigDecimal("20000.00"))
                .lineTotal(new BigDecimal("21000.00"))
                .accountCode("4010")
                .itemId(itemId)
                .build()));
        return invoice;
    }

    private TaxLineItem tax(String accountCode, String componentCode, String amount) {
        return TaxLineItem.builder()
                .accountCode(accountCode)
                .componentCode(componentCode)
                .taxAmount(new BigDecimal(amount))
                .build();
    }

    private void assertLine(JournalLineRequest line, String accountCode, String debit, String credit) {
        assertThat(line.accountCode()).isEqualTo(accountCode);
        assertThat(line.debit()).isEqualByComparingTo(debit);
        assertThat(line.credit()).isEqualByComparingTo(credit);
    }
}
