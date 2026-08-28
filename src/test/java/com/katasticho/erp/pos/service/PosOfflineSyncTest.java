package com.katasticho.erp.pos.service;

import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.posting.AccountingPostingEngine;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.entity.InvoiceNumberSequence;
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.cache.CacheInvalidationService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.snapshot.DocumentSnapshotService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.contact.service.ContactLedgerService;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.BatchService;
import com.katasticho.erp.inventory.service.CostResolverService;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.notification.sms.SmsService;
import com.katasticho.erp.notification.whatsapp.WhatsAppDocumentService;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.pharma.register.StatutoryRegisterService;
import com.katasticho.erp.pos.dto.BatchOfflineSyncResponse;
import com.katasticho.erp.pos.dto.CreateSalesReceiptRequest;
import com.katasticho.erp.pos.dto.SalesReceiptResponse;
import com.katasticho.erp.pos.entity.PaymentMode;
import com.katasticho.erp.pos.entity.SalesReceipt;
import com.katasticho.erp.pos.entity.SalesReceiptLine;
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
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PosOfflineSyncTest {

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
    private final UUID itemId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);

        Organisation org = Organisation.builder().name("Test Org").build();
        org.setId(orgId);
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));

        when(orgSettingsService.get(orgId, "pos.allow_negative_stock", "true")).thenReturn("true");
        when(sequenceRepository.findByOrgIdAndPrefixAndYear(any(), any(), anyInt()))
                .thenReturn(Optional.empty());

        Item item = Item.builder()
                .name("Paracetamol 500mg")
                .sku("PCM500")
                .salePrice(new BigDecimal("20.00"))
                .gstRate(new BigDecimal("5.00"))
                .trackInventory(false)
                .build();
        item.setId(itemId);
        item.setOrgId(orgId);
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(item));
        when(itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any()))
                .thenReturn(List.of(item));

        when(taxEngine.calculate(any(), any(), any(), any()))
                .thenReturn(new TaxEngine.TaxCalculationResult(List.of(), BigDecimal.ZERO));

        JournalEntry journalEntry = mock(JournalEntry.class);
        when(journalEntry.getId()).thenReturn(UUID.randomUUID());
        when(postingEngine.postPosReceipt(any(), any(), any())).thenReturn(journalEntry);

        when(receiptRepository.save(any(SalesReceipt.class))).thenAnswer(inv -> {
            SalesReceipt r = inv.getArgument(0);
            if (r.getId() == null) r.setId(UUID.randomUUID());
            return r;
        });
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void create_withOfflineReceiptNumber_storesOfflineNumber() {
        CreateSalesReceiptRequest request = new CreateSalesReceiptRequest(
                null,
                null,
                LocalDate.of(2026, 8, 18),
                PaymentMode.CASH,
                null,
                new BigDecimal("20.00"),
                null,
                "Offline counter sale",
                false,
                "OFF-0001",
                null, null, null, null,
                List.of(new CreateSalesReceiptRequest.LineRequest(
                        itemId, "Paracetamol 500mg", new BigDecimal("1"), "STRIP",
                        new BigDecimal("20.00"), null, null, null, null, null, false
                ))
        );

        SalesReceiptResponse res = service.create(request);

        assertThat(res).isNotNull();
        assertThat(res.offlineReceiptNumber()).isEqualTo("OFF-0001");
        verify(receiptRepository, atLeastOnce()).save(any(SalesReceipt.class));
    }

    @Test
    void create_duplicateOfflineReceiptNumber_returnsExistingWithoutDoublePosting() {
        SalesReceipt existing = SalesReceipt.builder()
                .receiptNumber("REC-2026-0011")
                .offlineReceiptNumber("OFF-0002")
                .receiptDate(LocalDate.of(2026, 8, 18))
                .paymentMode(PaymentMode.CASH)
                .total(new BigDecimal("50.00"))
                .lines(new ArrayList<>())
                .build();
        existing.setId(UUID.randomUUID());
        existing.setOrgId(orgId);

        when(receiptRepository.findByOrgIdAndOfflineReceiptNumberAndIsDeletedFalse(orgId, "OFF-0002"))
                .thenReturn(Optional.of(existing));

        CreateSalesReceiptRequest duplicateRequest = new CreateSalesReceiptRequest(
                null,
                null,
                LocalDate.of(2026, 8, 18),
                PaymentMode.CASH,
                null,
                new BigDecimal("50.00"),
                null,
                "Retry sync",
                false,
                "OFF-0002",
                null, null, null, null,
                List.of(new CreateSalesReceiptRequest.LineRequest(
                        itemId, "Paracetamol 500mg", new BigDecimal("2.5"), "STRIP",
                        new BigDecimal("20.00"), null, null, null, null, null, false
                ))
        );

        SalesReceiptResponse res = service.create(duplicateRequest);

        assertThat(res).isNotNull();
        assertThat(res.receiptNumber()).isEqualTo("REC-2026-0011");
        assertThat(res.offlineReceiptNumber()).isEqualTo("OFF-0002");
        // Verify no new save was triggered
        verify(receiptRepository, never()).save(any(SalesReceipt.class));
    }

    @Test
    void batchOfflineSync_handlesNewAndDuplicateReceipts() {
        SalesReceipt existing = SalesReceipt.builder()
                .receiptNumber("REC-2026-0005")
                .offlineReceiptNumber("OFF-0005")
                .receiptDate(LocalDate.of(2026, 8, 18))
                .paymentMode(PaymentMode.CASH)
                .total(new BigDecimal("20.00"))
                .lines(new ArrayList<>())
                .build();
        existing.setId(UUID.randomUUID());
        existing.setOrgId(orgId);

        when(receiptRepository.findByOrgIdAndOfflineReceiptNumberAndIsDeletedFalse(orgId, "OFF-0005"))
                .thenReturn(Optional.of(existing));
        when(receiptRepository.findByOrgIdAndOfflineReceiptNumberAndIsDeletedFalse(orgId, "OFF-0006"))
                .thenReturn(Optional.empty());

        CreateSalesReceiptRequest req1 = new CreateSalesReceiptRequest(
                null, null, LocalDate.of(2026, 8, 18), PaymentMode.CASH, null,
                new BigDecimal("20.00"), null, null, false, "OFF-0005",
                null, null, null, null,
                List.of(new CreateSalesReceiptRequest.LineRequest(itemId, "Item 1", BigDecimal.ONE, "STRIP", new BigDecimal("20.00"), null, null, null, null, null, false))
        );

        CreateSalesReceiptRequest req2 = new CreateSalesReceiptRequest(
                null, null, LocalDate.of(2026, 8, 18), PaymentMode.CASH, null,
                new BigDecimal("20.00"), null, null, false, "OFF-0006",
                null, null, null, null,
                List.of(new CreateSalesReceiptRequest.LineRequest(itemId, "Item 2", BigDecimal.ONE, "STRIP", new BigDecimal("20.00"), null, null, null, null, null, false))
        );

        BatchOfflineSyncResponse response = service.batchOfflineSync(List.of(req1, req2));

        assertThat(response.totalReceived()).isEqualTo(2);
        assertThat(response.syncedCount()).isEqualTo(1);
        assertThat(response.duplicateCount()).isEqualTo(1);
        assertThat(response.failedCount()).isEqualTo(0);
        assertThat(response.syncedReceipts()).hasSize(2);
    }
}
