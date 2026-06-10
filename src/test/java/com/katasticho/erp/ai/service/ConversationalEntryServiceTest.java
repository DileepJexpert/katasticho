package com.katasticho.erp.ai.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ai.dto.AiSuggestionReviewRequest;
import com.katasticho.erp.ai.dto.ConversationalEntryDtos.EntryDraftResult;
import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class ConversationalEntryServiceTest {

    private final JournalService journalService = mock(JournalService.class);
    private final AccountRepository accountRepository = mock(AccountRepository.class);
    private final ContactRepository contactRepository = mock(ContactRepository.class);
    private final DefaultAccountService defaultAccountService = mock(DefaultAccountService.class);
    private final AiSuggestionService aiSuggestionService = mock(AiSuggestionService.class);
    private final AiSuggestionRepository aiSuggestionRepository = mock(AiSuggestionRepository.class);

    private final ConversationalEntryService service = new ConversationalEntryService(
            journalService, accountRepository, contactRepository, defaultAccountService,
            aiSuggestionService, aiSuggestionRepository);

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);

        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.CASH)).thenReturn("1010");
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.BANK)).thenReturn("1020");
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR)).thenReturn("1100");
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.AP)).thenReturn("2010");
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.SALES_REVENUE)).thenReturn("4010");
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.PURCHASE)).thenReturn("5020");

        List<Account> coa = List.of(
                acct("1010", "Cash", "ASSET"),
                acct("1020", "Bank Account", "ASSET"),
                acct("1100", "Accounts Receivable", "ASSET"),
                acct("2010", "Accounts Payable", "LIABILITY"),
                acct("4010", "Sales Revenue", "REVENUE"),
                acct("4020", "Service Revenue", "REVENUE"),
                acct("5200", "Rent Expense", "EXPENSE"),
                acct("5210", "Utilities", "EXPENSE"),
                acct("5300", "Miscellaneous Expense", "EXPENSE"));
        when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId)).thenReturn(coa);
        for (Account a : coa) {
            when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, a.getCode()))
                    .thenReturn(Optional.of(a));
        }

        when(contactRepository.findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(eq(orgId), any()))
                .thenReturn(Optional.empty());

        // postJournal returns a DRAFT entry with an id.
        when(journalService.postJournal(any())).thenAnswer(inv -> JournalEntry.builder()
                .id(UUID.randomUUID()).orgId(orgId).entryNumber("JV-0001")
                .description("draft").status("DRAFT").build());

        // createSuggestion echoes the suggestion with an id.
        when(aiSuggestionService.createSuggestion(any())).thenAnswer(inv -> {
            AiSuggestion s = inv.getArgument(0);
            s.setId(UUID.randomUUID());
            return s;
        });
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void paymentWithExpensePurpose() {
        EntryDraftResult r = service.draftFromText("paid 5000 cash for shop rent");

        assertThat(r.drafted()).isTrue();
        assertThat(r.voucherType()).isEqualTo("PAYMENT");
        assertThat(r.amount()).isEqualByComparingTo("5000");
        assertThat(r.warnings()).isEmpty();
        // Dr Rent Expense, Cr Cash
        assertThat(r.lines()).hasSize(2);
        assertThat(r.lines().get(0).accountCode()).isEqualTo("5200");
        assertThat(r.lines().get(0).debit()).isEqualByComparingTo("5000");
        assertThat(r.lines().get(1).accountCode()).isEqualTo("1010");
        assertThat(r.lines().get(1).credit()).isEqualByComparingTo("5000");

        // Drafted as DRAFT (autoPost = false), suggestion created.
        ArgumentCaptor<JournalPostRequest> jc = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(jc.capture());
        assertThat(jc.getValue().autoPost()).isFalse();
        assertThat(jc.getValue().sourceModule()).isEqualTo("AI_ENTRY");
        verify(aiSuggestionService).createSuggestion(any());
    }

    @Test
    void receiptFromCustomerHitsReceivable() {
        when(contactRepository.findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(orgId, "MediMart"))
                .thenReturn(Optional.of(customer("MediMart")));

        EntryDraftResult r = service.draftFromText("received 12000 from MediMart against invoice");

        assertThat(r.voucherType()).isEqualTo("RECEIPT");
        assertThat(r.amount()).isEqualByComparingTo("12000");
        // Dr Cash, Cr Accounts Receivable
        assertThat(r.lines().get(0).accountCode()).isEqualTo("1010");
        assertThat(r.lines().get(0).debit()).isEqualByComparingTo("12000");
        assertThat(r.lines().get(1).accountCode()).isEqualTo("1100");
        assertThat(r.lines().get(1).credit()).isEqualByComparingTo("12000");
    }

    @Test
    void bankInstrumentRecognised() {
        EntryDraftResult r = service.draftFromText("paid 1500 by bank for rent");

        assertThat(r.lines().get(0).accountCode()).isEqualTo("5200");   // Rent
        assertThat(r.lines().get(1).accountCode()).isEqualTo("1020");   // Bank, not Cash
    }

    @Test
    void paymentToVendorSettlesPayable() {
        when(contactRepository.findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(orgId, "ABC Traders"))
                .thenReturn(Optional.of(vendor("ABC Traders")));

        EntryDraftResult r = service.draftFromText("paid 8000 cash to ABC Traders");

        assertThat(r.voucherType()).isEqualTo("PAYMENT");
        assertThat(r.lines().get(0).accountCode()).isEqualTo("2010");   // AP
        assertThat(r.lines().get(1).accountCode()).isEqualTo("1010");   // Cash
        assertThat(r.warnings()).isNotEmpty();
    }

    @Test
    void unknownExpenseFallsBackToMiscWithWarning() {
        EntryDraftResult r = service.draftFromText("paid 800 cash for zzqq widget");

        assertThat(r.drafted()).isTrue();
        assertThat(r.lines().get(0).accountCode()).isEqualTo("5300");   // Miscellaneous Expense
        assertThat(r.warnings()).isNotEmpty();
        assertThat(r.confidence()).isLessThan(0.5);
    }

    @Test
    void kShorthandAmountExpands() {
        EntryDraftResult r = service.draftFromText("paid 5k cash for rent");
        assertThat(r.amount()).isEqualByComparingTo("5000");
    }

    @Test
    void missingDirectionNotDrafted() {
        EntryDraftResult r = service.draftFromText("5000 rent");
        assertThat(r.drafted()).isFalse();
        assertThat(r.message()).contains("paid").contains("received");
        verify(journalService, never()).postJournal(any());
    }

    @Test
    void missingAmountNotDrafted() {
        EntryDraftResult r = service.draftFromText("paid cash for rent");
        assertThat(r.drafted()).isFalse();
        assertThat(r.message()).contains("amount");
    }

    @Test
    void approvePostsAndMarksAccepted() {
        UUID sid = UUID.randomUUID();
        UUID eid = UUID.randomUUID();
        AiSuggestion s = AiSuggestion.builder().id(sid).orgId(orgId)
                .suggestionType("DRAFT_ENTRY").entityId(eid).status("PENDING")
                .confidence(new BigDecimal("0.800")).build();
        when(aiSuggestionRepository.findByIdAndOrgId(sid, orgId)).thenReturn(Optional.of(s));
        when(journalService.postEntry(eid)).thenReturn(JournalEntry.builder()
                .id(eid).entryNumber("JV-0001").description("Paid 5000 for rent").build());

        service.approve(sid);

        verify(journalService).postEntry(eid);
        ArgumentCaptor<AiSuggestionReviewRequest> rc = ArgumentCaptor.forClass(AiSuggestionReviewRequest.class);
        verify(aiSuggestionService).review(eq(sid), rc.capture());
        assertThat(rc.getValue().action()).isEqualTo("ACCEPT");
    }

    @Test
    void rejectDeletesDraftAndMarksRejected() {
        UUID sid = UUID.randomUUID();
        UUID eid = UUID.randomUUID();
        AiSuggestion s = AiSuggestion.builder().id(sid).orgId(orgId)
                .suggestionType("DRAFT_ENTRY").entityId(eid).status("PENDING").build();
        when(aiSuggestionRepository.findByIdAndOrgId(sid, orgId)).thenReturn(Optional.of(s));

        service.reject(sid, "wrong");

        verify(journalService).deleteEntry(eid);
        ArgumentCaptor<AiSuggestionReviewRequest> rc = ArgumentCaptor.forClass(AiSuggestionReviewRequest.class);
        verify(aiSuggestionService).review(eq(sid), rc.capture());
        assertThat(rc.getValue().action()).isEqualTo("REJECT");
    }

    @Test
    void amountParsingHandlesIndianFormats() {
        assertThat(ConversationalEntryService.extractAmount("paid rs 1,15,000 for stock"))
                .isEqualByComparingTo("115000");
        assertThat(ConversationalEntryService.extractAmount("got ₹2.5 lakh from sale"))
                .isEqualByComparingTo("250000");
        assertThat(ConversationalEntryService.extractAmount("nothing here")).isNull();
    }

    @Test
    void partyAndPurposeExtraction() {
        assertThat(ConversationalEntryService.extractParty(
                "paid 5000 to ABC Traders for office rent",
                "paid 5000 to abc traders for office rent", " to "))
                .isEqualTo("ABC Traders");
        assertThat(ConversationalEntryService.extractPurpose(
                "paid 5000 to ABC Traders for office rent",
                "paid 5000 to abc traders for office rent"))
                .isEqualTo("office rent");
    }

    // ── Fixtures ──────────────────────────────────────────────────────────

    private static Account acct(String code, String name, String type) {
        Account a = new Account();
        a.setCode(code);
        a.setName(name);
        a.setType(type);
        return a;
    }

    private Contact customer(String name) {
        return Contact.builder().contactType(ContactType.CUSTOMER).displayName(name).build();
    }

    private Contact vendor(String name) {
        return Contact.builder().contactType(ContactType.VENDOR).displayName(name).build();
    }
}
