package com.katasticho.erp.pos.service;

import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.posting.AccountingPostingEngine;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.cache.CacheInvalidationService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.snapshot.DocumentSnapshotService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.contact.service.ContactLedgerService;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.BatchService;
import com.katasticho.erp.inventory.service.CostResolverService;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.notification.sms.SmsService;
import com.katasticho.erp.notification.whatsapp.WhatsAppDocumentService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.pharma.register.StatutoryRegisterService;
import com.katasticho.erp.pos.dto.CreateSalesReceiptRequest;
import com.katasticho.erp.pos.entity.PaymentMode;
import com.katasticho.erp.pos.entity.SalesReceipt;
import com.katasticho.erp.pos.repository.SalesReceiptRepository;
import com.katasticho.erp.tax.TaxEngine;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Khata (CREDIT) POS sale: gated by {@code pos.allow_credit_sales}, requires
 * a customer, bumps the contact's denormalized outstanding by the receipt
 * total, and a POS return takes it back off.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PosKhataSaleTest {

    @Mock private SalesReceiptRepository receiptRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private StockBatchRepository stockBatchRepository;
    @Mock private WarehouseRepository warehouseRepository;
    @Mock private InvoiceNumberSequenceRepository sequenceRepository;
    @Mock private TaxLineItemRepository taxLineItemRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private JournalService journalService;
    @Mock private AccountingPostingEngine postingEngine;
    @Mock private InventoryService inventoryService;
    @Mock private BatchService batchService;
    @Mock private CostResolverService costResolverService;
    @Mock private TaxEngine taxEngine;
    @Mock private AuditService auditService;
    @Mock private CacheInvalidationService cacheInvalidationService;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private DocumentSnapshotService documentSnapshotService;
    @Mock private ContactLedgerService contactLedgerService;
    @Mock private SmsService smsService;
    @Mock private OrgSettingsService orgSettingsService;
    @Mock private WhatsAppDocumentService whatsAppDocumentService;
    @Mock private StatutoryRegisterService statutoryRegisterService;

    @InjectMocks private SalesReceiptService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID contactId = UUID.randomUUID();
    private Contact customer;

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);

        customer = Contact.builder()
                .displayName("Khata Kirana Store")
                .contactType(ContactType.CUSTOMER)
                .build();
        customer.setId(contactId);
        customer.setOrgId(orgId);

        when(orgSettingsService.get(orgId, "pos.allow_credit_sales", "false")).thenReturn("true");
        when(orgSettingsService.get(orgId, "pos.allow_negative_stock", "true")).thenReturn("true");
        when(sequenceRepository.findByOrgIdAndPrefixAndYear(any(), any(), org.mockito.ArgumentMatchers.anyInt()))
                .thenReturn(Optional.empty());
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(mock(Organisation.class)));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(customer));
        when(contactRepository.findById(contactId)).thenReturn(Optional.of(customer));
        when(taxEngine.calculate(any(), any(), any(), any()))
                .thenReturn(new TaxEngine.TaxCalculationResult(List.of(), BigDecimal.ZERO));
        when(receiptRepository.save(any(SalesReceipt.class))).thenAnswer(inv -> {
            SalesReceipt r = inv.getArgument(0);
            if (r.getId() == null) r.setId(UUID.randomUUID());
            return r;
        });
        JournalEntry journalEntry = mock(JournalEntry.class);
        when(journalEntry.getId()).thenReturn(UUID.randomUUID());
        when(postingEngine.postPosReceipt(any(), any(), any())).thenReturn(journalEntry);
        when(warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.empty());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private CreateSalesReceiptRequest creditRequest(UUID contact) {
        return new CreateSalesReceiptRequest(
                null, contact, LocalDate.of(2026, 7, 2), PaymentMode.CREDIT,
                null, BigDecimal.ZERO, null, null, null, null,
                List.of(new CreateSalesReceiptRequest.LineRequest(
                        null, "Loose sugar", new BigDecimal("2"), null,
                        new BigDecimal("50.00"), null, null, null, null, null, null)));
    }

    @Test
    void creditSaleBooksReceivableOnTheContact() {
        var response = service.create(creditRequest(contactId));

        assertThat(customer.getOutstandingAr()).isEqualByComparingTo("100.00");
        verify(contactRepository).save(customer);
        verify(postingEngine).postPosReceipt(
                org.mockito.ArgumentMatchers.argThat(r -> r.getPaymentMode() == PaymentMode.CREDIT),
                any(), any());
        assertThat(response.total()).isEqualByComparingTo("100.00");
    }

    @Test
    void creditSaleBlockedWhenSettingIsOff() {
        when(orgSettingsService.get(orgId, "pos.allow_credit_sales", "false")).thenReturn("false");

        assertThatThrownBy(() -> service.create(creditRequest(contactId)))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "POS_CREDIT_DISABLED");
        verify(postingEngine, never()).postPosReceipt(any(), any(), any());
    }

    @Test
    void creditSaleWithoutContactIsRejected() {
        assertThatThrownBy(() -> service.create(creditRequest(null)))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "POS_CREDIT_REQUIRES_CONTACT");
        verify(postingEngine, never()).postPosReceipt(any(), any(), any());
    }

    @Test
    void creditSaleToNonCustomerIsRejected() {
        customer.setContactType(ContactType.VENDOR);

        assertThatThrownBy(() -> service.create(creditRequest(contactId)))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "POS_CREDIT_CONTACT_NOT_CUSTOMER");
    }

    @Test
    void cashSaleNeverTouchesOutstanding() {
        var request = new CreateSalesReceiptRequest(
                null, null, LocalDate.of(2026, 7, 2), PaymentMode.CASH,
                null, new BigDecimal("100.00"), null, null, null, null,
                List.of(new CreateSalesReceiptRequest.LineRequest(
                        null, "Loose sugar", new BigDecimal("2"), null,
                        new BigDecimal("50.00"), null, null, null, null, null, null)));

        service.create(request);

        verify(contactRepository, never()).save(any());
    }

    @Test
    void voidingCreditSaleRestoresTheOutstanding() {
        customer.setOutstandingAr(new BigDecimal("150.00"));
        UUID receiptId = UUID.randomUUID();
        UUID journalId = UUID.randomUUID();
        SalesReceipt receipt = SalesReceipt.builder()
                .receiptNumber("SR-2026-000009")
                .receiptDate(LocalDate.of(2026, 7, 2))
                .paymentMode(PaymentMode.CREDIT)
                .contactId(contactId)
                .status("COMPLETED")
                .total(new BigDecimal("100.00"))
                .journalEntryId(journalId)
                .build();
        receipt.setOrgId(orgId);
        when(receiptRepository.findByIdAndOrgIdAndIsDeletedFalse(receiptId, orgId))
                .thenReturn(Optional.of(receipt));
        JournalEntry reversal = mock(JournalEntry.class);
        when(reversal.getId()).thenReturn(UUID.randomUUID());
        when(journalService.reverseEntry(journalId)).thenReturn(reversal);

        service.voidReceipt(receiptId, "goods returned");

        assertThat(customer.getOutstandingAr()).isEqualByComparingTo("50.00");
        verify(contactRepository).save(customer);
    }
}
