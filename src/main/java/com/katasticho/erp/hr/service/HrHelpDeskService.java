package com.katasticho.erp.hr.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.hr.entity.HrTicket;
import com.katasticho.erp.hr.entity.HrTicketComment;
import com.katasticho.erp.hr.repository.HrTicketCommentRepository;
import com.katasticho.erp.hr.repository.HrTicketRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

/**
 * HR Help Desk — Core HR module 6. Employees raise tickets; HR assigns and
 * resolves them through OPEN -> IN_PROGRESS -> RESOLVED -> CLOSED, with a
 * per-ticket comment thread.
 */
@Service
@RequiredArgsConstructor
public class HrHelpDeskService {

    private static final Set<String> STATUSES = Set.of("OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED");
    private static final Set<String> PRIORITIES = Set.of("LOW", "NORMAL", "HIGH");

    private final HrTicketRepository ticketRepository;
    private final HrTicketCommentRepository commentRepository;

    @Transactional
    public HrTicket raise(String category, String subject, String description, String priority) {
        if (subject == null || subject.isBlank()) {
            throw new BusinessException("Subject is required", "HR_TICKET_NO_SUBJECT", HttpStatus.BAD_REQUEST);
        }
        return ticketRepository.save(HrTicket.builder()
                .orgId(TenantContext.getCurrentOrgId())
                .raisedByUserId(TenantContext.getCurrentUserId())
                .category(category != null && !category.isBlank() ? category.trim() : "GENERAL")
                .subject(subject.trim())
                .description(description)
                .priority(PRIORITIES.contains(up(priority)) ? up(priority) : "NORMAL")
                .status("OPEN")
                .build());
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getTicket(UUID id) {
        HrTicket t = load(id);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("ticket", t);
        out.put("comments", commentRepository
                .findByOrgIdAndTicketIdAndIsDeletedFalseOrderByCreatedAtAsc(t.getOrgId(), t.getId()));
        return out;
    }

    @Transactional
    public HrTicketComment addComment(UUID ticketId, String body) {
        if (body == null || body.isBlank()) {
            throw new BusinessException("Comment body is required", "HR_TICKET_NO_BODY", HttpStatus.BAD_REQUEST);
        }
        HrTicket t = load(ticketId);   // validates org ownership
        return commentRepository.save(HrTicketComment.builder()
                .orgId(t.getOrgId()).ticketId(t.getId())
                .authorUserId(TenantContext.getCurrentUserId())
                .body(body.trim())
                .build());
    }

    /** HR assigns a ticket; an OPEN ticket moves to IN_PROGRESS. */
    @Transactional
    public HrTicket assign(UUID ticketId, UUID assigneeId) {
        HrTicket t = load(ticketId);
        t.setAssignedToUserId(assigneeId);
        if ("OPEN".equals(t.getStatus())) t.setStatus("IN_PROGRESS");
        return ticketRepository.save(t);
    }

    /** HR moves a ticket through its lifecycle; resolution stored for RESOLVED/CLOSED. */
    @Transactional
    public HrTicket setStatus(UUID ticketId, String status, String resolution) {
        String s = up(status);
        if (!STATUSES.contains(s)) {
            throw new BusinessException("Unknown status: " + status, "HR_TICKET_BAD_STATUS", HttpStatus.BAD_REQUEST);
        }
        HrTicket t = load(ticketId);
        t.setStatus(s);
        if (("RESOLVED".equals(s) || "CLOSED".equals(s)) && resolution != null && !resolution.isBlank()) {
            t.setResolution(resolution.trim());
        }
        return ticketRepository.save(t);
    }

    @Transactional(readOnly = true)
    public List<HrTicket> myTickets() {
        return ticketRepository.findByOrgIdAndRaisedByUserIdAndIsDeletedFalseOrderByCreatedAtDesc(
                TenantContext.getCurrentOrgId(), TenantContext.getCurrentUserId());
    }

    @Transactional(readOnly = true)
    public List<HrTicket> assignedToMe() {
        return ticketRepository.findByOrgIdAndAssignedToUserIdAndIsDeletedFalseOrderByCreatedAtDesc(
                TenantContext.getCurrentOrgId(), TenantContext.getCurrentUserId());
    }

    /** HR inbox: all not-yet-closed tickets. */
    @Transactional(readOnly = true)
    public List<HrTicket> openTickets() {
        return ticketRepository.findByOrgIdAndStatusInAndIsDeletedFalseOrderByCreatedAtDesc(
                TenantContext.getCurrentOrgId(), List.of("OPEN", "IN_PROGRESS", "RESOLVED"));
    }

    private HrTicket load(UUID id) {
        return ticketRepository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("HrTicket", id));
    }

    private static String up(String s) {
        return s != null ? s.trim().toUpperCase(Locale.ROOT) : "";
    }
}
