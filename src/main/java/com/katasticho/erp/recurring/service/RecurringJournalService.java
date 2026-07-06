package com.katasticho.erp.recurring.service;

import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.recurring.dto.RecurringJournalDtos.*;
import com.katasticho.erp.recurring.entity.*;
import com.katasticho.erp.recurring.repository.RecurringJournalGenerationRepository;
import com.katasticho.erp.recurring.repository.RecurringJournalRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Recurring journals — depreciation, prepaid amortisation, standing accruals.
 * Mirror of {@code RecurringInvoiceService}; {@link #generateFromTemplate} posts
 * a JournalEntry each period (DRAFT by default, auto_post opt-in). The template
 * lines are validated to balance at create/update so a generation run can never
 * mint an imbalanced journal.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class RecurringJournalService {

    private final RecurringJournalRepository journalRepository;
    private final RecurringJournalGenerationRepository generationRepository;
    private final JournalService journalService;
    private final Clock clock;

    // ── CRUD ────────────────────────────────────────────────────────────────

    @Transactional
    public RecurringJournalResponse createTemplate(CreateRecurringJournalRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (req.profileName() == null || req.profileName().isBlank()) {
            throw new BusinessException("Profile name is required", "REC_JRNL_NAME_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        validateFrequency(req.frequency());
        if (req.startDate() == null) {
            throw new BusinessException("Start date is required", "REC_JRNL_START_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        requireEndAfterStart(req.startDate(), req.endDate());
        if (req.narration() == null || req.narration().isBlank()) {
            throw new BusinessException("Narration is required", "REC_JRNL_NARRATION_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        validateLines(req.lines());

        RecurringJournal t = RecurringJournal.builder()
                .profileName(req.profileName().trim())
                .frequency(req.frequency())
                .startDate(req.startDate())
                .endDate(req.endDate())
                .nextRunDate(req.startDate())
                .narration(req.narration())
                .lines(req.lines())
                .autoPost(req.autoPost())
                .status("ACTIVE")
                .notes(req.notes())
                .build();
        t.setOrgId(orgId);
        t.setCreatedBy(TenantContext.getCurrentUserId());
        return RecurringJournalResponse.of(journalRepository.save(t));
    }

    @Transactional
    public RecurringJournalResponse updateTemplate(UUID id, UpdateRecurringJournalRequest req) {
        RecurringJournal t = load(id);
        if ("STOPPED".equals(t.getStatus()) || "EXPIRED".equals(t.getStatus())) {
            throw new BusinessException("A stopped/expired template can't be edited",
                    "REC_JRNL_NOT_EDITABLE", HttpStatus.BAD_REQUEST);
        }
        if (req.profileName() != null && !req.profileName().isBlank()) t.setProfileName(req.profileName().trim());
        if (req.frequency() != null) { validateFrequency(req.frequency()); t.setFrequency(req.frequency()); }
        if (req.endDate() != null) { requireEndAfterStart(t.getStartDate(), req.endDate()); t.setEndDate(req.endDate()); }
        if (req.narration() != null && !req.narration().isBlank()) t.setNarration(req.narration());
        if (req.autoPost() != null) t.setAutoPost(req.autoPost());
        if (req.notes() != null) t.setNotes(req.notes());
        if (req.lines() != null) { validateLines(req.lines()); t.setLines(req.lines()); }
        return RecurringJournalResponse.of(journalRepository.save(t));
    }

    @Transactional
    public RecurringJournalResponse stopTemplate(UUID id) {
        RecurringJournal t = load(id);
        t.setStatus("STOPPED");
        return RecurringJournalResponse.of(journalRepository.save(t));
    }

    @Transactional
    public RecurringJournalResponse resumeTemplate(UUID id) {
        RecurringJournal t = load(id);
        if ("EXPIRED".equals(t.getStatus())) {
            throw new BusinessException("An expired template can't be resumed",
                    "REC_JRNL_EXPIRED", HttpStatus.BAD_REQUEST);
        }
        LocalDate today = LocalDate.now(clock);
        if (t.getNextRunDate().isBefore(today)) t.setNextRunDate(today);
        t.setStatus("ACTIVE");
        return RecurringJournalResponse.of(journalRepository.save(t));
    }

    @Transactional(readOnly = true)
    public RecurringJournalResponse getTemplate(UUID id) {
        return RecurringJournalResponse.of(load(id));
    }

    @Transactional(readOnly = true)
    public Page<RecurringJournalResponse> listTemplates(String status, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Page<RecurringJournal> page = (status == null || status.isBlank())
                ? journalRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pageable)
                : journalRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(orgId, status, pageable);
        return page.map(RecurringJournalResponse::of);
    }

    @Transactional(readOnly = true)
    public List<GeneratedJournalResponse> listGenerated(UUID id) {
        load(id);
        return generationRepository.findByRecurringJournalIdOrderByGeneratedAtDesc(id).stream()
                .map(GeneratedJournalResponse::of).toList();
    }

    // ── Generation ──────────────────────────────────────────────────────────

    @Transactional
    public UUID generateFromTemplate(UUID templateId) {
        // Org-scoped: the daily job sets TenantContext to each template's own
        // org before calling, and the generate-now endpoint must not reach a
        // foreign org's template (it passes the raw path id straight in, and
        // postJournal resolves accounts against the CALLER's org — a foreign
        // template would otherwise post into the wrong books AND advance the
        // victim org's cursor).
        // Pessimistic lock so two concurrent generate-now clicks (or a click racing
        // the daily sweep) serialise on the template row — otherwise both read the
        // same ACTIVE cursor and both post, double-booking an auto_post journal.
        RecurringJournal t = journalRepository.findByIdAndOrgIdForUpdate(
                        templateId, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Recurring journal", templateId));
        if (!"ACTIVE".equals(t.getStatus())) {
            log.warn("Skipping non-ACTIVE recurring journal {} (status={})", templateId, t.getStatus());
            return null;
        }
        if (t.getLines() == null || t.getLines().isEmpty()) {
            log.warn("Skipping recurring journal {} with no lines", templateId);
            return null;
        }

        List<JournalLineRequest> lines = t.getLines().stream()
                .map(l -> new JournalLineRequest(
                        l.getAccountCode(),
                        l.getDebit() != null ? l.getDebit() : BigDecimal.ZERO,
                        l.getCredit() != null ? l.getCredit() : BigDecimal.ZERO,
                        l.getDescription(), l.getTaxComponentCode(), l.getCostCentre()))
                .toList();

        // Always create the entry as a DRAFT first (validates accounts +
        // period), THEN best-effort post it — mirroring the bill path's
        // create-DRAFT / best-effort-postBill split. An auto-post that fails
        // for a post-specific reason (e.g. an approval workflow) leaves a valid
        // DRAFT + still advances the cursor, instead of stalling the template
        // with nothing generated.
        JournalEntry entry = journalService.postJournal(new JournalPostRequest(
                LocalDate.now(clock),
                "Auto-generated from recurring journal: " + t.getProfileName() + " — " + t.getNarration(),
                "RECURRING_JOURNAL", null, lines, false));
        boolean posted = false;
        if (t.isAutoPost()) {
            try {
                journalService.postEntry(entry.getId());
                posted = true;
            } catch (Exception e) {
                log.warn("Auto-post failed for recurring journal {} -> entry {}: {}",
                        templateId, entry.getId(), e.getMessage());
            }
        }

        generationRepository.save(RecurringJournalGeneration.builder()
                .recurringJournalId(t.getId()).journalEntryId(entry.getId())
                .autoPosted(posted).build());

        RecurringFrequency freq = RecurringFrequency.valueOf(t.getFrequency());
        LocalDate next = freq.advance(t.getNextRunDate());
        t.setNextRunDate(next);
        t.setTotalGenerated(t.getTotalGenerated() + 1);
        t.setLastGeneratedAt(Instant.now(clock));
        if (t.getEndDate() != null && next.isAfter(t.getEndDate())) {
            t.setStatus("EXPIRED");
        }
        journalRepository.save(t);
        return entry.getId();
    }

    @Transactional(readOnly = true)
    public List<DueTemplate> findDueTemplates() {
        return journalRepository.findDueTemplates(LocalDate.now(clock)).stream()
                .map(t -> new DueTemplate(t.getId(), t.getOrgId(), t.getCreatedBy()))
                .toList();
    }

    public record DueTemplate(UUID id, UUID orgId, UUID createdBy) {}

    // ── helpers ───────────────────────────────────────────────────────────

    private RecurringJournal load(UUID id) {
        return journalRepository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Recurring journal", id));
    }

    private void validateFrequency(String frequency) {
        try {
            RecurringFrequency.valueOf(frequency);
        } catch (Exception e) {
            throw new BusinessException("Invalid frequency: " + frequency,
                    "REC_JRNL_BAD_FREQUENCY", HttpStatus.BAD_REQUEST);
        }
    }

    private void requireEndAfterStart(LocalDate start, LocalDate end) {
        if (start != null && end != null && end.isBefore(start)) {
            throw new BusinessException("End date can't be before start date",
                    "REC_JRNL_END_BEFORE_START", HttpStatus.BAD_REQUEST);
        }
    }

    /** A recurring journal template must be balanced + non-zero — pre-empt the postJournal reject. */
    private void validateLines(List<RecurringJournalLine> lines) {
        if (lines == null || lines.size() < 2) {
            throw new BusinessException("A journal needs at least two lines",
                    "REC_JRNL_LINES_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        BigDecimal debit = BigDecimal.ZERO, credit = BigDecimal.ZERO;
        for (RecurringJournalLine l : lines) {
            if (l.getAccountCode() == null || l.getAccountCode().isBlank()) {
                throw new BusinessException("Every line needs an account code",
                        "REC_JRNL_ACCOUNT_REQUIRED", HttpStatus.BAD_REQUEST);
            }
            debit = debit.add(l.getDebit() != null ? l.getDebit() : BigDecimal.ZERO);
            credit = credit.add(l.getCredit() != null ? l.getCredit() : BigDecimal.ZERO);
        }
        if (debit.compareTo(credit) != 0) {
            throw new BusinessException("Debits (" + debit + ") must equal credits (" + credit + ")",
                    "REC_JRNL_IMBALANCED", HttpStatus.BAD_REQUEST);
        }
        if (debit.signum() == 0) {
            throw new BusinessException("Journal total can't be zero", "REC_JRNL_ZERO", HttpStatus.BAD_REQUEST);
        }
    }
}
