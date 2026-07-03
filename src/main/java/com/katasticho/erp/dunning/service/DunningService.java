package com.katasticho.erp.dunning.service;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.dunning.dto.DunningDtos.*;
import com.katasticho.erp.dunning.entity.DunningLevel;
import com.katasticho.erp.dunning.entity.DunningLog;
import com.katasticho.erp.dunning.repository.DunningLevelRepository;
import com.katasticho.erp.dunning.repository.DunningLogRepository;
import com.katasticho.erp.paymentterm.entity.InvoiceInstalment;
import com.katasticho.erp.paymentterm.repository.InvoiceInstalmentRepository;
import com.katasticho.erp.paymentterm.service.PaymentTermService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.*;

/**
 * Configurable escalating overdue reminders (Odoo "follow-up levels"). A sweep
 * walks each overdue invoice (instalment-aware effective due date), finds the
 * highest configured level whose threshold it has crossed and that has not yet
 * been sent, and delegates the actual claim-and-send to {@link DunningDispatcher}
 * (one REQUIRES_NEW transaction per invoice). The sweep itself holds NO
 * transaction, so a per-invoice claim collision or delivery failure can never
 * poison the batch.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class DunningService {

    private static final Set<String> CHANNELS = Set.of("EMAIL", "WHATSAPP", "AI_INBOX", "NONE");
    private static final Set<String> OPEN_STATUSES = Set.of("SENT", "PARTIALLY_PAID", "OVERDUE");

    private final DunningLevelRepository levelRepository;
    private final DunningLogRepository logRepository;
    private final InvoiceRepository invoiceRepository;
    private final InvoiceInstalmentRepository instalmentRepository;
    private final PaymentTermService paymentTermService;
    private final ContactRepository contactRepository;
    private final DunningDispatcher dispatcher;
    private final com.katasticho.erp.organisation.OrganisationRepository organisationRepository;
    private final Clock clock;

    // ── Level CRUD ───────────────────────────────────────────────────────────

    @Transactional
    public LevelResponse createLevel(LevelRequest req) {
        validate(req);
        DunningLevel level = DunningLevel.builder()
                .seq(req.seq() == null ? 0 : req.seq())
                .name(req.name().trim())
                .daysOverdue(req.daysOverdue() == null ? 0 : req.daysOverdue())
                .channel(normaliseChannel(req.channel()))
                .subject(req.subject())
                .messageTemplate(req.messageTemplate())
                .active(req.active() == null || req.active())
                .build();
        return toResponse(levelRepository.save(level));
    }

    @Transactional
    public LevelResponse updateLevel(UUID id, LevelRequest req) {
        validate(req);
        DunningLevel level = loadLevel(id);
        level.setSeq(req.seq() == null ? 0 : req.seq());
        level.setName(req.name().trim());
        level.setDaysOverdue(req.daysOverdue() == null ? 0 : req.daysOverdue());
        level.setChannel(normaliseChannel(req.channel()));
        level.setSubject(req.subject());
        level.setMessageTemplate(req.messageTemplate());
        level.setActive(req.active() == null || req.active());
        return toResponse(levelRepository.save(level));
    }

    @Transactional
    public void deleteLevel(UUID id) {
        DunningLevel level = loadLevel(id);
        level.setDeleted(true);
        levelRepository.save(level);
    }

    @Transactional(readOnly = true)
    public List<LevelResponse> listLevels() {
        return levelRepository.findByOrgIdAndIsDeletedFalseOrderBySeqAsc(TenantContext.getCurrentOrgId())
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public Page<DunningLogResponse> log(UUID invoiceId, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (invoiceId != null) {
            List<DunningLogResponse> rows = logRepository
                    .findByOrgIdAndInvoiceIdAndIsDeletedFalseOrderBySentAtDesc(orgId, invoiceId)
                    .stream().map(this::toLogResponse).toList();
            return new org.springframework.data.domain.PageImpl<>(rows, pageable, rows.size());
        }
        return logRepository.findByOrgIdAndIsDeletedFalseOrderBySentAtDesc(orgId, pageable)
                .map(this::toLogResponse);
    }

    // ── The sweep (NON-transactional — each invoice commits in its own dispatch tx) ──

    public DunningRunResult run() {
        return runForOrg(TenantContext.getCurrentOrgId());
    }

    public DunningRunResult runForOrg(UUID orgId) {
        LocalDate today = LocalDate.now(clock);
        List<DunningLevel> levels = levelRepository
                .findByOrgIdAndActiveTrueAndIsDeletedFalseOrderBySeqAsc(orgId);
        if (levels.isEmpty()) {
            return new DunningRunResult(0, 0, 0, 0);
        }
        // The dispatcher's createSuggestion (requireOrgId) + BaseEntity.onCreate read
        // TenantContext; the scheduled sweep runs on a worker thread. Pin it to the
        // swept org for the duration (restore-after) so writes are never stamped with
        // a caller's stale org.
        UUID priorOrg = TenantContext.getCurrentOrgId();
        try {
            TenantContext.setCurrentOrgId(orgId);
            return sweep(orgId, today, levels);
        } finally {
            TenantContext.setCurrentOrgId(priorOrg);
        }
    }

    private DunningRunResult sweep(UUID orgId, LocalDate today, List<DunningLevel> levels) {
        String orgName = organisationRepository.findById(orgId)
                .map(com.katasticho.erp.organisation.Organisation::getName).orElse("");
        List<Invoice> candidates = collectCandidates(orgId, today);
        int sent = 0, skipped = 0, failed = 0;
        for (Invoice invoice : candidates) {
            long days = daysOverdueFor(invoice, today);
            if (days <= 0) {
                continue;
            }
            DunningLevel level = highestApplicable(levels, days);
            if (level == null) {
                continue;
            }
            // Cheap pre-filter so an already-sent level doesn't open a dispatch tx.
            if (logRepository.existsByOrgIdAndInvoiceIdAndDunningLevelIdAndOutcomeAndIsDeletedFalse(
                    orgId, invoice.getId(), level.getId(), "SENT")) {
                skipped++;
                continue;
            }
            Contact contact = invoice.getContactId() == null ? null
                    : contactRepository.findByIdAndOrgIdAndIsDeletedFalse(invoice.getContactId(), orgId).orElse(null);
            try {
                DunningDispatcher.Outcome outcome = dispatcher.dispatch(orgId, invoice, contact, level, days, orgName);
                if (outcome == DunningDispatcher.Outcome.SENT) {
                    sent++;
                } else {
                    skipped++; // viability skip (no channel target) — retries when fixed
                }
            } catch (Exception e) {
                // Concurrent claim (unique-index) or a not-delivered rollback: the
                // dispatch tx rolled back in isolation, so just move on — retried next sweep.
                skipped++;
                log.debug("Dunning dispatch skipped for invoice {} level {}: {}",
                        invoice.getId(), level.getId(), e.getMessage());
            }
        }
        return new DunningRunResult(candidates.size(), sent, skipped, failed);
    }

    public List<DunningPreviewRow> preview() {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now(clock);
        List<DunningLevel> levels = levelRepository
                .findByOrgIdAndActiveTrueAndIsDeletedFalseOrderBySeqAsc(orgId);
        List<DunningPreviewRow> rows = new ArrayList<>();
        if (levels.isEmpty()) {
            return rows;
        }
        for (Invoice invoice : collectCandidates(orgId, today)) {
            long days = daysOverdueFor(invoice, today);
            if (days <= 0) {
                continue;
            }
            DunningLevel level = highestApplicable(levels, days);
            if (level == null) {
                continue;
            }
            boolean already = logRepository.existsByOrgIdAndInvoiceIdAndDunningLevelIdAndOutcomeAndIsDeletedFalse(
                    orgId, invoice.getId(), level.getId(), "SENT");
            rows.add(new DunningPreviewRow(invoice.getId(), invoice.getInvoiceNumber(), invoice.getContactId(),
                    (int) days, invoice.getBalanceDue(), level.getId(), level.getName(), level.getChannel(), already));
        }
        return rows;
    }

    // ── candidate + overdue computation ──────────────────────────────────────

    private List<Invoice> collectCandidates(UUID orgId, LocalDate today) {
        Map<UUID, Invoice> byId = new LinkedHashMap<>();
        for (Invoice inv : invoiceRepository.findOverdueInvoices(orgId, today)) {
            byId.put(inv.getId(), inv);
        }
        // Instalment invoices carry the FINAL instalment as their invoice-level due
        // date (future until the end), so findOverdueInvoices misses an early missed
        // instalment — pull those in explicitly.
        for (UUID invId : instalmentRepository.findInvoiceIdsWithInstalmentDueBefore(orgId, today)) {
            if (!byId.containsKey(invId)) {
                invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invId, orgId)
                        .ifPresent(inv -> byId.put(inv.getId(), inv));
            }
        }
        return new ArrayList<>(byId.values());
    }

    /** Days past the effective (instalment-aware) due date, or 0 if not overdue / not open. */
    private long daysOverdueFor(Invoice invoice, LocalDate today) {
        if (!OPEN_STATUSES.contains(invoice.getStatus())) {
            return 0;
        }
        if (invoice.getBalanceDue() == null || invoice.getBalanceDue().signum() <= 0) {
            return 0;
        }
        LocalDate effective;
        List<InvoiceInstalment> instalments = instalmentRepository
                .findByInvoiceIdAndIsDeletedFalseOrderBySeqAsc(invoice.getId());
        if (!instalments.isEmpty()) {
            effective = paymentTermService.effectiveDueDate(invoice.getAmountPaid(), instalments, today);
        } else {
            effective = invoice.getDueDate();
        }
        if (effective == null || !effective.isBefore(today)) {
            return 0;
        }
        return ChronoUnit.DAYS.between(effective, today);
    }

    private DunningLevel highestApplicable(List<DunningLevel> levels, long daysOverdue) {
        DunningLevel best = null;
        for (DunningLevel l : levels) {
            if (l.getDaysOverdue() <= daysOverdue) {
                if (best == null || l.getDaysOverdue() > best.getDaysOverdue()
                        || (l.getDaysOverdue() == best.getDaysOverdue() && l.getSeq() > best.getSeq())) {
                    best = l;
                }
            }
        }
        return best;
    }

    // ── validation + helpers ─────────────────────────────────────────────────

    private void validate(LevelRequest req) {
        if (req.name() == null || req.name().isBlank()) {
            throw new BusinessException("Name is required", "DUNNING_NAME_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        if (req.daysOverdue() != null && req.daysOverdue() < 0) {
            throw new BusinessException("days overdue cannot be negative", "DUNNING_BAD_DAYS", HttpStatus.BAD_REQUEST);
        }
        normaliseChannel(req.channel());
    }

    private static String normaliseChannel(String c) {
        String up = c == null ? "AI_INBOX" : c.trim().toUpperCase();
        if (!CHANNELS.contains(up)) {
            throw new BusinessException("Unknown channel: " + c, "DUNNING_BAD_CHANNEL", HttpStatus.BAD_REQUEST);
        }
        return up;
    }

    private DunningLevel loadLevel(UUID id) {
        return levelRepository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Dunning level", id));
    }

    private LevelResponse toResponse(DunningLevel l) {
        return new LevelResponse(l.getId(), l.getSeq(), l.getName(), l.getDaysOverdue(),
                l.getChannel(), l.getSubject(), l.getMessageTemplate(), l.isActive());
    }

    private DunningLogResponse toLogResponse(DunningLog l) {
        return new DunningLogResponse(l.getId(), l.getInvoiceId(), l.getContactId(), l.getDunningLevelId(),
                l.getDaysOverdue(), l.getAmount(), l.getChannel(), l.getOutcome(), l.getDetail(), l.getSentAt());
    }
}
