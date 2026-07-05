package com.katasticho.erp.recurring.service;

import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.recurring.dto.RecurringJournalDtos.CreateRecurringJournalRequest;
import com.katasticho.erp.recurring.entity.RecurringJournal;
import com.katasticho.erp.recurring.entity.RecurringJournalLine;
import com.katasticho.erp.recurring.repository.RecurringJournalGenerationRepository;
import com.katasticho.erp.recurring.repository.RecurringJournalRepository;
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
class RecurringJournalServiceTest {

    @Mock private RecurringJournalRepository journalRepository;
    @Mock private RecurringJournalGenerationRepository generationRepository;
    @Mock private JournalService journalService;

    private RecurringJournalService svc;
    private final UUID orgId = UUID.randomUUID();
    private final UUID templateId = UUID.randomUUID();
    private final UUID entryId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        Clock clock = Clock.fixed(LocalDate.of(2026, 7, 2).atStartOfDay(ZoneId.systemDefault()).toInstant(),
                ZoneId.systemDefault());
        svc = new RecurringJournalService(journalRepository, generationRepository, journalService, clock);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
        when(journalRepository.save(any())).thenAnswer(i -> {
            RecurringJournal j = i.getArgument(0);
            if (j.getId() == null) j.setId(templateId);
            return j;
        });
        // generateFromTemplate now pessimistic-locks the template row; delegate the
        // locked finder to the plain finder the tests stub.
        when(journalRepository.findByIdAndOrgIdForUpdate(any(), any())).thenAnswer(inv ->
                journalRepository.findByIdAndOrgIdAndIsDeletedFalse(inv.getArgument(0), inv.getArgument(1)));
        JournalEntry entry = mock(JournalEntry.class);
        when(entry.getId()).thenReturn(entryId);
        when(journalService.postJournal(any())).thenReturn(entry);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private List<RecurringJournalLine> balancedLines() {
        return List.of(
                RecurringJournalLine.builder().accountCode("5030").debit(new BigDecimal("1000")).build(),
                RecurringJournalLine.builder().accountCode("1210").credit(new BigDecimal("1000")).build());
    }

    private CreateRecurringJournalRequest createReq(boolean autoPost, List<RecurringJournalLine> lines) {
        return new CreateRecurringJournalRequest("Monthly depreciation", "MONTHLY",
                LocalDate.of(2026, 7, 1), null, "Depreciation for the month", autoPost, "note", lines);
    }

    @Test
    void createTemplate_accepts_a_balanced_journal() {
        var resp = svc.createTemplate(createReq(false, balancedLines()));
        assertThat(resp.status()).isEqualTo("ACTIVE");
        assertThat(resp.nextRunDate()).isEqualTo(LocalDate.of(2026, 7, 1));
    }

    @Test
    void createTemplate_rejects_an_imbalanced_journal() {
        var lines = List.of(
                RecurringJournalLine.builder().accountCode("5030").debit(new BigDecimal("1000")).build(),
                RecurringJournalLine.builder().accountCode("1210").credit(new BigDecimal("900")).build());
        assertThatThrownBy(() -> svc.createTemplate(createReq(false, lines)))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "REC_JRNL_IMBALANCED");
    }

    @Test
    void createTemplate_rejects_a_zero_journal() {
        var lines = List.of(
                RecurringJournalLine.builder().accountCode("5030").debit(BigDecimal.ZERO).build(),
                RecurringJournalLine.builder().accountCode("1210").credit(BigDecimal.ZERO).build());
        assertThatThrownBy(() -> svc.createTemplate(createReq(false, lines)))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "REC_JRNL_ZERO");
    }

    private RecurringJournal activeTemplate(boolean autoPost, LocalDate nextRun, LocalDate end) {
        RecurringJournal t = RecurringJournal.builder()
                .profileName("Depreciation").frequency("MONTHLY")
                .startDate(LocalDate.of(2026, 6, 1)).endDate(end).nextRunDate(nextRun)
                .narration("Monthly depreciation").lines(balancedLines()).autoPost(autoPost)
                .status("ACTIVE").build();
        t.setId(templateId);
        t.setOrgId(orgId);
        return t;
    }

    @Test
    void generate_posts_a_draft_journal_and_advances_cursor() {
        RecurringJournal t = activeTemplate(false, LocalDate.of(2026, 7, 1), null);
        when(journalRepository.findByIdAndOrgIdAndIsDeletedFalse(templateId, orgId)).thenReturn(Optional.of(t));

        UUID out = svc.generateFromTemplate(templateId);

        assertThat(out).isEqualTo(entryId);
        ArgumentCaptor<JournalPostRequest> req = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(req.capture());
        assertThat(req.getValue().autoPost()).isFalse();          // DRAFT by default
        assertThat(req.getValue().sourceModule()).isEqualTo("RECURRING_JOURNAL");
        assertThat(req.getValue().lines()).hasSize(2);
        verify(generationRepository).save(any());
        assertThat(t.getNextRunDate()).isEqualTo(LocalDate.of(2026, 8, 1));
        assertThat(t.getTotalGenerated()).isEqualTo(1);
    }

    @Test
    void generate_auto_posts_via_a_draft_then_post_entry() {
        when(journalRepository.findByIdAndOrgIdAndIsDeletedFalse(templateId, orgId))
                .thenReturn(Optional.of(activeTemplate(true, LocalDate.of(2026, 7, 1), null)));
        svc.generateFromTemplate(templateId);
        // creates a DRAFT (autoPost=false), then posts it best-effort
        ArgumentCaptor<JournalPostRequest> req = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(req.capture());
        assertThat(req.getValue().autoPost()).isFalse();
        verify(journalService).postEntry(entryId);
    }

    @Test
    void generate_auto_post_failure_leaves_a_draft_and_still_advances() {
        RecurringJournal t = activeTemplate(true, LocalDate.of(2026, 7, 1), null);
        when(journalRepository.findByIdAndOrgIdAndIsDeletedFalse(templateId, orgId)).thenReturn(Optional.of(t));
        // posting the draft fails (e.g. an approval workflow) — must not stall
        when(journalService.postEntry(entryId)).thenThrow(new RuntimeException("needs approval"));

        UUID out = svc.generateFromTemplate(templateId);

        assertThat(out).isEqualTo(entryId);          // draft was created
        verify(generationRepository).save(any());    // logged
        assertThat(t.getNextRunDate()).isEqualTo(LocalDate.of(2026, 8, 1)); // cursor advanced
    }

    @Test
    void createTemplate_rejects_end_before_start() {
        assertThatThrownBy(() -> svc.createTemplate(new CreateRecurringJournalRequest(
                "bad", "MONTHLY", LocalDate.of(2026, 7, 1), LocalDate.of(2026, 6, 30),
                "n", false, null, balancedLines())))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "REC_JRNL_END_BEFORE_START");
    }

    @Test
    void generate_skips_a_non_active_template() {
        RecurringJournal stopped = activeTemplate(false, LocalDate.of(2026, 7, 1), null);
        stopped.setStatus("PAUSED");
        when(journalRepository.findByIdAndOrgIdAndIsDeletedFalse(templateId, orgId)).thenReturn(Optional.of(stopped));

        assertThat(svc.generateFromTemplate(templateId)).isNull();
        verify(journalService, never()).postJournal(any());
    }

    @Test
    void generate_flips_to_expired_when_cursor_passes_end_date() {
        RecurringJournal t = activeTemplate(false, LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 10));
        when(journalRepository.findByIdAndOrgIdAndIsDeletedFalse(templateId, orgId)).thenReturn(Optional.of(t));
        svc.generateFromTemplate(templateId);
        assertThat(t.getStatus()).isEqualTo("EXPIRED");
    }
}
