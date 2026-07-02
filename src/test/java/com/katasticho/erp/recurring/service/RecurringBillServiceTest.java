package com.katasticho.erp.recurring.service;

import com.katasticho.erp.ap.dto.CreatePurchaseBillRequest;
import com.katasticho.erp.ap.dto.PurchaseBillResponse;
import com.katasticho.erp.ap.service.PurchaseBillService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.recurring.dto.RecurringBillDtos.CreateRecurringBillRequest;
import com.katasticho.erp.recurring.entity.RecurringBill;
import com.katasticho.erp.recurring.entity.RecurringBillLineItem;
import com.katasticho.erp.recurring.repository.RecurringBillGenerationRepository;
import com.katasticho.erp.recurring.repository.RecurringBillRepository;
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
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class RecurringBillServiceTest {

    @Mock private RecurringBillRepository billRepository;
    @Mock private RecurringBillGenerationRepository generationRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private PurchaseBillService purchaseBillService;

    private RecurringBillService svc;
    private final UUID orgId = UUID.randomUUID();
    private final UUID contactId = UUID.randomUUID();
    private final UUID templateId = UUID.randomUUID();
    private final UUID billId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        Clock clock = Clock.fixed(LocalDate.of(2026, 7, 2).atStartOfDay(ZoneId.systemDefault()).toInstant(),
                ZoneId.systemDefault());
        svc = new RecurringBillService(billRepository, generationRepository, contactRepository,
                purchaseBillService, clock);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
        when(billRepository.save(any())).thenAnswer(i -> {
            RecurringBill b = i.getArgument(0);
            if (b.getId() == null) b.setId(templateId);
            return b;
        });
        Contact vendor = new Contact();
        vendor.setId(contactId);
        vendor.setOrgId(orgId);
        vendor.setContactType(ContactType.VENDOR);
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId)).thenReturn(Optional.of(vendor));

        PurchaseBillResponse resp = mock(PurchaseBillResponse.class);
        when(resp.id()).thenReturn(billId);
        when(resp.billNumber()).thenReturn("BILL-1");
        when(purchaseBillService.createBill(any())).thenReturn(resp);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private RecurringBillLineItem serviceLine() {
        return RecurringBillLineItem.builder()
                .lineType("SERVICE").description("Monthly rent")
                .quantity(BigDecimal.ONE).unitPrice(new BigDecimal("10000")).build();
    }

    private CreateRecurringBillRequest createReq(String frequency, LocalDate start, LocalDate end, boolean autoPost) {
        return new CreateRecurringBillRequest("Office rent", contactId, frequency, start, end,
                30, false, "27", autoPost, "note", "terms", List.of(serviceLine()));
    }

    @Test
    void createTemplate_starts_active_with_cursor_at_start_date() {
        var resp = svc.createTemplate(createReq("MONTHLY", LocalDate.of(2026, 7, 1), null, false));
        assertThat(resp.status()).isEqualTo("ACTIVE");
        assertThat(resp.nextBillDate()).isEqualTo(LocalDate.of(2026, 7, 1));
        assertThat(resp.frequency()).isEqualTo("MONTHLY");
    }

    @Test
    void createTemplate_rejects_a_non_vendor_contact() {
        Contact customer = new Contact();
        customer.setId(contactId);
        customer.setOrgId(orgId);
        customer.setContactType(ContactType.CUSTOMER);
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId)).thenReturn(Optional.of(customer));

        assertThatThrownBy(() -> svc.createTemplate(createReq("MONTHLY", LocalDate.of(2026, 7, 1), null, false)))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "REC_BILL_CONTACT_NOT_VENDOR");
    }

    @Test
    void createTemplate_rejects_goods_line_without_item() {
        var goods = RecurringBillLineItem.builder().lineType("GOODS").description("widgets")
                .quantity(BigDecimal.ONE).unitPrice(new BigDecimal("5")).build();
        var req = new CreateRecurringBillRequest("stock", contactId, "MONTHLY", LocalDate.of(2026, 7, 1),
                null, 0, false, null, false, null, null, List.of(goods));
        assertThatThrownBy(() -> svc.createTemplate(req))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "REC_BILL_GOODS_ITEM_REQUIRED");
    }

    private RecurringBill activeTemplate(LocalDate nextBillDate, LocalDate endDate, boolean autoPost) {
        RecurringBill t = RecurringBill.builder()
                .profileName("Office rent").contactId(contactId).frequency("MONTHLY")
                .startDate(LocalDate.of(2026, 6, 1)).endDate(endDate).nextBillDate(nextBillDate)
                .lineItems(List.of(serviceLine())).paymentTermsDays(30).autoPost(autoPost)
                .status("ACTIVE").build();
        t.setId(templateId);
        t.setOrgId(orgId);
        return t;
    }

    @Test
    void generate_drafts_a_bill_advances_the_cursor_and_logs_it() {
        RecurringBill t = activeTemplate(LocalDate.of(2026, 7, 1), null, false);
        when(billRepository.findByIdAndOrgIdAndIsDeletedFalse(templateId, orgId)).thenReturn(Optional.of(t));

        UUID out = svc.generateFromTemplate(templateId);

        assertThat(out).isEqualTo(billId);
        ArgumentCaptor<CreatePurchaseBillRequest> req = ArgumentCaptor.forClass(CreatePurchaseBillRequest.class);
        verify(purchaseBillService).createBill(req.capture());
        assertThat(req.getValue().contactId()).isEqualTo(contactId);
        assertThat(req.getValue().billDate()).isEqualTo(LocalDate.of(2026, 7, 2)); // clock today
        assertThat(req.getValue().lines()).hasSize(1);
        verify(purchaseBillService, never()).postBill(any()); // not auto-post
        verify(generationRepository).save(any());
        assertThat(t.getNextBillDate()).isEqualTo(LocalDate.of(2026, 8, 1)); // +1 month
        assertThat(t.getTotalGenerated()).isEqualTo(1);
    }

    @Test
    void generate_auto_posts_when_flag_set() {
        when(billRepository.findByIdAndOrgIdAndIsDeletedFalse(templateId, orgId))
                .thenReturn(Optional.of(activeTemplate(LocalDate.of(2026, 7, 1), null, true)));
        svc.generateFromTemplate(templateId);
        verify(purchaseBillService).postBill(billId);
    }

    @Test
    void generate_skips_a_non_active_template() {
        RecurringBill stopped = activeTemplate(LocalDate.of(2026, 7, 1), null, false);
        stopped.setStatus("STOPPED");
        when(billRepository.findByIdAndOrgIdAndIsDeletedFalse(templateId, orgId)).thenReturn(Optional.of(stopped));

        assertThat(svc.generateFromTemplate(templateId)).isNull();
        verify(purchaseBillService, never()).createBill(any());
    }

    @Test
    void createTemplate_rejects_end_before_start() {
        var req = new CreateRecurringBillRequest("bad", contactId, "MONTHLY",
                LocalDate.of(2026, 7, 1), LocalDate.of(2026, 6, 30), 0, false, null, false, null, null,
                List.of(serviceLine()));
        assertThatThrownBy(() -> svc.createTemplate(req))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "REC_BILL_END_BEFORE_START");
    }

    @Test
    void generate_on_a_foreign_or_missing_template_is_not_found() {
        // org-scoped lookup returns empty for another org's template id
        when(billRepository.findByIdAndOrgIdAndIsDeletedFalse(templateId, orgId)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> svc.generateFromTemplate(templateId))
                .isInstanceOf(BusinessException.class);
        verify(purchaseBillService, never()).createBill(any());
    }

    @Test
    void generate_flips_to_expired_when_cursor_passes_end_date() {
        // next=2026-07-01, end=2026-07-15 -> advance to 2026-08-01 > end -> EXPIRED
        RecurringBill t = activeTemplate(LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 15), false);
        when(billRepository.findByIdAndOrgIdAndIsDeletedFalse(templateId, orgId)).thenReturn(Optional.of(t));

        svc.generateFromTemplate(templateId);
        assertThat(t.getStatus()).isEqualTo("EXPIRED");
    }
}
