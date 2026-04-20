package com.katasticho.erp.automation;

import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ap.repository.VendorPaymentRepository;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.PaymentRepository;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.entity.Notification;
import com.katasticho.erp.common.repository.NotificationRepository;
import com.katasticho.erp.common.service.NotificationService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.expense.repository.ExpenseRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.entity.StockBatchBalance;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.StockBatchBalanceRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.pos.repository.SalesReceiptRepository;
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
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class AutomationJobsTest {

    @Mock private OrganisationRepository orgRepository;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private PurchaseBillRepository billRepository;
    @Mock private StockBatchRepository batchRepository;
    @Mock private StockBatchBalanceRepository batchBalanceRepository;
    @Mock private StockBalanceRepository stockBalanceRepository;
    @Mock private StockMovementRepository stockMovementRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private AppUserRepository userRepository;
    @Mock private NotificationService notificationService;
    @Mock private NotificationRepository notificationRepository;
    @Mock private PaymentRepository paymentRepository;
    @Mock private SalesReceiptRepository salesReceiptRepository;
    @Mock private ExpenseRepository expenseRepository;
    @Mock private VendorPaymentRepository vendorPaymentRepository;

    private PaymentReminderJob paymentReminderJob;
    private ExpiryAlertJob expiryAlertJob;
    private LowStockAlertJob lowStockAlertJob;
    private DailySalesSummaryJob dailySummaryJob;
    private OverdueBillJob overdueBillJob;

    private UUID orgId;
    private UUID adminId;
    private Organisation org;

    @BeforeEach
    void setUp() {
        paymentReminderJob = new PaymentReminderJob(
                orgRepository, invoiceRepository, contactRepository, userRepository, notificationService);
        expiryAlertJob = new ExpiryAlertJob(
                orgRepository, batchRepository, batchBalanceRepository, itemRepository, userRepository, notificationService);
        lowStockAlertJob = new LowStockAlertJob(
                orgRepository, stockBalanceRepository, itemRepository, contactRepository, userRepository, notificationService);
        dailySummaryJob = new DailySalesSummaryJob(
                orgRepository, invoiceRepository, paymentRepository, salesReceiptRepository,
                expenseRepository, vendorPaymentRepository, stockMovementRepository,
                itemRepository, userRepository, notificationService);
        overdueBillJob = new OverdueBillJob(
                orgRepository, billRepository, contactRepository, userRepository, notificationService);

        orgId = UUID.randomUUID();
        adminId = UUID.randomUUID();
        org = new Organisation();
        org.setId(orgId);
        org.setName("Test Pharma");
        org.setActive(true);

        AppUser admin = new AppUser();
        admin.setId(adminId);
        admin.setOrgId(orgId);
        admin.setRole("OWNER");

        when(orgRepository.findByIsDeletedFalseAndIsActiveTrue()).thenReturn(List.of(org));
        when(userRepository.findFirstByOrgIdAndRoleAndIsDeletedFalse(orgId, "OWNER"))
                .thenReturn(Optional.of(admin));
    }

    // ── Payment Reminder ──────────────────────────────────────

    @Test
    void paymentReminder_createsNotificationForOverdueInvoice() {
        Invoice inv = buildInvoice("INV-0042", LocalDate.now().minusDays(3), new BigDecimal("12500"));
        when(invoiceRepository.findDueOnDates(eq(orgId), anyList())).thenReturn(List.of(inv));
        when(notificationService.existsTodayForEntity(eq(orgId), eq("PAYMENT_REMINDER"), any()))
                .thenReturn(false);

        Contact customer = buildContact("Ramesh Kumar", "9876543210");
        when(contactRepository.findById(inv.getContactId())).thenReturn(Optional.of(customer));

        paymentReminderJob.run();

        verify(notificationService).send(
                eq(orgId), eq(adminId),
                eq("Payment reminder: INV-0042"),
                contains("12500"),
                eq("WARNING"),
                eq("PAYMENT_REMINDER"),
                eq("INVOICE"),
                eq(inv.getId()),
                argThat(m -> m.containsKey("whatsappLink")));
    }

    @Test
    void paymentReminder_noDuplicateSameDay() {
        Invoice inv = buildInvoice("INV-0043", LocalDate.now().minusDays(7), new BigDecimal("5000"));
        when(invoiceRepository.findDueOnDates(eq(orgId), anyList())).thenReturn(List.of(inv));
        when(notificationService.existsTodayForEntity(eq(orgId), eq("PAYMENT_REMINDER"), eq(inv.getId())))
                .thenReturn(true);

        paymentReminderJob.run();

        verify(notificationService, never()).send(any(), any(), any(), any(), any(), any(), any(), any(), any());
    }

    // ── Expiry Alert ──────────────────────────────────────────

    @Test
    void expiryAlert_createsConsolidatedNotification() {
        UUID itemId = UUID.randomUUID();
        UUID batchId = UUID.randomUUID();
        StockBatch batch = StockBatch.builder()
                .itemId(itemId)
                .batchNumber("BATCH-001")
                .expiryDate(LocalDate.now().plusDays(5))
                .build();
        batch.setId(batchId);
        batch.setOrgId(orgId);

        when(batchRepository.findExpiringWithStock(eq(orgId), any())).thenReturn(List.of(batch));
        when(batchRepository.markExpired(eq(orgId), any())).thenReturn(0);

        StockBatchBalance balance = new StockBatchBalance();
        balance.setQuantityOnHand(new BigDecimal("50"));
        when(batchBalanceRepository.findByOrgIdAndBatchId(orgId, batchId)).thenReturn(List.of(balance));

        Item item = Item.builder().name("Paracetamol 500mg").sku("MED-001").build();
        item.setId(itemId);
        when(itemRepository.findById(itemId)).thenReturn(Optional.of(item));

        expiryAlertJob.run();

        verify(notificationService).send(
                eq(orgId), eq(adminId),
                contains("1 batches expiring"),
                contains("expiring within 7 days"),
                eq("WARNING"),
                eq("EXPIRY_ALERT"),
                isNull(), isNull(),
                argThat(m -> {
                    @SuppressWarnings("unchecked")
                    var items = (List<Map<String, Object>>) m.get("items");
                    return items.size() == 1
                            && "CRITICAL".equals(items.get(0).get("urgency"))
                            && "Paracetamol 500mg".equals(items.get(0).get("itemName"));
                }));
    }

    @Test
    void expiryAlert_marksBatchesExpired() {
        when(batchRepository.findExpiringWithStock(eq(orgId), any())).thenReturn(List.of());

        expiryAlertJob.run();

        verify(batchRepository).markExpired(eq(orgId), eq(LocalDate.now()));
    }

    // ── Low Stock Alert ───────────────────────────────────────

    @Test
    void lowStockAlert_createsNotification() {
        UUID itemId = UUID.randomUUID();
        StockBalance sb = new StockBalance();
        sb.setItemId(itemId);
        sb.setQuantityOnHand(new BigDecimal("30"));
        when(stockBalanceRepository.findLowStock(orgId)).thenReturn(List.of(sb));

        Item item = Item.builder()
                .name("Crocin")
                .sku("MED-002")
                .reorderLevel(new BigDecimal("50"))
                .reorderQuantity(new BigDecimal("100"))
                .build();
        item.setId(itemId);
        when(itemRepository.findById(itemId)).thenReturn(Optional.of(item));

        lowStockAlertJob.run();

        verify(notificationService).send(
                eq(orgId), eq(adminId),
                contains("1 items need reorder"),
                any(), eq("WARNING"),
                eq("LOW_STOCK_ALERT"),
                isNull(), isNull(),
                argThat(m -> {
                    @SuppressWarnings("unchecked")
                    var items = (List<Map<String, Object>>) m.get("items");
                    return items.size() == 1
                            && "Crocin".equals(items.get(0).get("itemName"))
                            && new BigDecimal("30").compareTo((BigDecimal) items.get(0).get("currentQty")) == 0;
                }));
    }

    // ── Daily Sales Summary ───────────────────────────────────

    @Test
    void dailySummary_createsNotificationWithCorrectTotals() {
        LocalDate today = LocalDate.now();
        when(invoiceRepository.sumRevenueByOrgAndDateRange(orgId, today, today))
                .thenReturn(new BigDecimal("10000"));
        when(salesReceiptRepository.sumTotalByOrgAndDate(orgId, today))
                .thenReturn(new BigDecimal("2450"));
        when(paymentRepository.sumCollectedByOrgAndDateRange(orgId, today, today))
                .thenReturn(new BigDecimal("8000"));
        when(expenseRepository.sumTotalByOrgAndDate(orgId, today))
                .thenReturn(new BigDecimal("3000"));
        when(vendorPaymentRepository.sumAmountByOrgAndDate(orgId, today))
                .thenReturn(new BigDecimal("1500"));
        when(invoiceRepository.countByOrgAndDate(orgId, today)).thenReturn(3L);
        when(salesReceiptRepository.countByOrgAndDate(orgId, today)).thenReturn(2L);
        when(stockMovementRepository.findTopSellingByDate(orgId, today)).thenReturn(List.of());

        dailySummaryJob.run();

        verify(notificationService).send(
                eq(orgId), eq(adminId),
                contains("12450"),
                argThat(msg -> msg.contains("3 invoices") && msg.contains("2 counter sales")),
                eq("INFO"),
                eq("DAILY_SUMMARY"),
                isNull(), isNull(),
                argThat(m -> {
                    BigDecimal revenue = (BigDecimal) m.get("revenue");
                    BigDecimal collections = (BigDecimal) m.get("collections");
                    BigDecimal expenses = (BigDecimal) m.get("expenses");
                    return revenue.compareTo(new BigDecimal("12450")) == 0
                            && collections.compareTo(new BigDecimal("10450")) == 0
                            && expenses.compareTo(new BigDecimal("4500")) == 0;
                }));
    }

    @Test
    void dailySummary_skipsOrgWithNoActivity() {
        LocalDate today = LocalDate.now();
        when(invoiceRepository.sumRevenueByOrgAndDateRange(orgId, today, today)).thenReturn(BigDecimal.ZERO);
        when(salesReceiptRepository.sumTotalByOrgAndDate(orgId, today)).thenReturn(BigDecimal.ZERO);
        when(paymentRepository.sumCollectedByOrgAndDateRange(orgId, today, today)).thenReturn(BigDecimal.ZERO);
        when(expenseRepository.sumTotalByOrgAndDate(orgId, today)).thenReturn(BigDecimal.ZERO);
        when(vendorPaymentRepository.sumAmountByOrgAndDate(orgId, today)).thenReturn(BigDecimal.ZERO);
        when(invoiceRepository.countByOrgAndDate(orgId, today)).thenReturn(0L);
        when(salesReceiptRepository.countByOrgAndDate(orgId, today)).thenReturn(0L);

        dailySummaryJob.run();

        verify(notificationService, never()).send(any(), any(), any(), any(), any(), any(), any(), any(), any());
    }

    // ── Overdue Bill ──────────────────────────────────────────

    @Test
    void overdueBill_createsNotification() {
        PurchaseBill bill = buildBill("BILL-001", LocalDate.now().minusDays(1), new BigDecimal("25000"));
        when(billRepository.findOverdueBills(eq(orgId), any())).thenReturn(List.of(bill));
        when(notificationService.existsTodayForEntity(eq(orgId), eq("BILL_OVERDUE"), any()))
                .thenReturn(false);

        Contact vendor = new Contact();
        vendor.setDisplayName("ABC Suppliers");
        when(contactRepository.findById(bill.getContactId())).thenReturn(Optional.of(vendor));

        overdueBillJob.run();

        verify(notificationService).send(
                eq(orgId), eq(adminId),
                eq("Bill overdue: ABC Suppliers"),
                contains("25000"),
                eq("WARNING"),
                eq("BILL_OVERDUE"),
                eq("BILL"),
                eq(bill.getId()),
                argThat(m -> "ABC Suppliers".equals(m.get("vendorName"))));
    }

    @Test
    void overdueBill_skipsIfAlreadyNotifiedToday() {
        PurchaseBill bill = buildBill("BILL-002", LocalDate.now().minusDays(5), new BigDecimal("10000"));
        when(billRepository.findOverdueBills(eq(orgId), any())).thenReturn(List.of(bill));
        when(notificationService.existsTodayForEntity(eq(orgId), eq("BILL_OVERDUE"), eq(bill.getId())))
                .thenReturn(true);

        overdueBillJob.run();

        verify(notificationService, never()).send(any(), any(), any(), any(), any(), any(), any(), any(), any());
    }

    // ── Scheduler only processes active orgs ──────────────────

    @Test
    void schedulers_skipDeletedOrgs() {
        when(orgRepository.findByIsDeletedFalseAndIsActiveTrue()).thenReturn(List.of());

        paymentReminderJob.run();
        expiryAlertJob.run();
        lowStockAlertJob.run();
        dailySummaryJob.run();
        overdueBillJob.run();

        verify(notificationService, never()).send(any(), any(), any(), any(), any(), any(), any(), any(), any());
    }

    // ── Notification API ──────────────────────────────────────

    @Test
    void notificationService_send_createsWithType() {
        NotificationService realService = new NotificationService(notificationRepository);
        ArgumentCaptor<Notification> captor = ArgumentCaptor.forClass(Notification.class);

        realService.send(orgId, adminId, "Test", "Body", "INFO", "LOW_STOCK_ALERT",
                "ITEM", UUID.randomUUID(), Map.of("key", "value"));

        verify(notificationRepository).save(captor.capture());
        Notification saved = captor.getValue();
        assertEquals("LOW_STOCK_ALERT", saved.getType());
        assertEquals("Test", saved.getTitle());
        assertEquals("key", ((Map<?, ?>) saved.getMetadata()).keySet().iterator().next());
        assertFalse(saved.isRead());
    }

    // ── Helpers ───────────────────────────────────────────────

    private Invoice buildInvoice(String number, LocalDate dueDate, BigDecimal balance) {
        Invoice inv = new Invoice();
        inv.setId(UUID.randomUUID());
        inv.setOrgId(orgId);
        inv.setInvoiceNumber(number);
        inv.setDueDate(dueDate);
        inv.setBalanceDue(balance);
        inv.setContactId(UUID.randomUUID());
        inv.setStatus("SENT");
        return inv;
    }

    private Contact buildContact(String name, String phone) {
        Contact c = new Contact();
        c.setDisplayName(name);
        c.setPhone(phone);
        c.setContactType(ContactType.CUSTOMER);
        return c;
    }

    private PurchaseBill buildBill(String number, LocalDate dueDate, BigDecimal balance) {
        PurchaseBill bill = new PurchaseBill();
        bill.setId(UUID.randomUUID());
        bill.setOrgId(orgId);
        bill.setBillNumber(number);
        bill.setDueDate(dueDate);
        bill.setBalanceDue(balance);
        bill.setContactId(UUID.randomUUID());
        bill.setStatus("OPEN");
        return bill;
    }
}
