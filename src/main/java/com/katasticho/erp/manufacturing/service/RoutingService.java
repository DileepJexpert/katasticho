package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.EntityAttachment;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.AttachmentService;
import com.katasticho.erp.manufacturing.entity.*;
import com.katasticho.erp.manufacturing.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class RoutingService {

    private final WorkstationRepository workstationRepository;
    private final OperationRepository operationRepository;
    private final RoutingRepository routingRepository;
    private final RoutingOperationRepository routingOperationRepository;
    private final JobCardRepository jobCardRepository;
    private final AttachmentService attachmentService;
    private final RoutingOperationDependencyRepository operationDependencyRepository;
    private final WorkstationAlternateRepository workstationAlternateRepository;

    /**
     * AttachmentService entityType key for operation work-instruction
     * uploads (tracker #13). Stable string — used in {@code
     * entity_attachment.entity_type} rows so don't rename without a
     * migration.
     */
    public static final String OPERATION_ATTACHMENT_ENTITY_TYPE = "OPERATION";

    // ── Workstation CRUD ──────────────────────────────────────────

    @Transactional
    public Workstation createWorkstation(String code, String name, String description,
                                         BigDecimal hourlyRate, BigDecimal capacityHours) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Workstation ws = Workstation.builder()
                .code(code)
                .name(name)
                .description(description)
                .hourlyRate(hourlyRate != null ? hourlyRate : BigDecimal.ZERO)
                .capacityHoursPerDay(capacityHours != null ? capacityHours : BigDecimal.valueOf(8))
                .build();
        ws = workstationRepository.save(ws);
        log.info("Created workstation {} ({}) for org {}", code, name, orgId);
        return ws;
    }

    @Transactional(readOnly = true)
    public List<Workstation> listWorkstations() {
        return workstationRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(
                TenantContext.getCurrentOrgId());
    }

    @Transactional(readOnly = true)
    public Workstation getWorkstation(UUID id) {
        return workstationRepository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Workstation", id));
    }

    // ── Operation CRUD ────────────────────────────────────────────

    @Transactional
    public Operation createOperation(String code, String name, String description,
                                      UUID defaultWorkstationId,
                                      int setupTimeMinutes, BigDecimal runTimePerUnit) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Operation op = Operation.builder()
                .code(code)
                .name(name)
                .description(description)
                .defaultWorkstationId(defaultWorkstationId)
                .setupTimeMinutes(setupTimeMinutes)
                .runTimeMinutesPerUnit(runTimePerUnit != null ? runTimePerUnit : BigDecimal.ZERO)
                .build();
        op = operationRepository.save(op);
        log.info("Created operation {} ({}) for org {}", code, name, orgId);
        return op;
    }

    @Transactional(readOnly = true)
    public List<Operation> listOperations() {
        return operationRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(
                TenantContext.getCurrentOrgId());
    }

    @Transactional(readOnly = true)
    public Operation getOperation(UUID id) {
        return operationRepository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Operation", id));
    }

    // ── Operation work instructions / attachments (tracker #13) ──────

    /**
     * Attach a work-instruction file (SOP PDF, drawing, video, etc.) to
     * an operation so floor staff can pull it up from the job card.
     * Uses the shared {@link AttachmentService} so storage / per-org
     * isolation / backup tooling matches every other attachment in the
     * system. {@code getOperation} runs first to enforce org ownership
     * before the file ever hits storage.
     */
    @Transactional
    public EntityAttachment attachOperationFile(UUID operationId, MultipartFile file) {
        Operation op = getOperation(operationId);
        return attachmentService.upload(OPERATION_ATTACHMENT_ENTITY_TYPE, op.getId(), file);
    }

    @Transactional(readOnly = true)
    public List<EntityAttachment> listOperationAttachments(UUID operationId) {
        Operation op = getOperation(operationId);
        return attachmentService.list(OPERATION_ATTACHMENT_ENTITY_TYPE, op.getId());
    }

    @Transactional
    public void deleteOperationAttachment(UUID attachmentId) {
        // AttachmentService.delete already does the org-scope check via
        // its own tenant-aware lookup. Nothing extra to enforce here.
        attachmentService.delete(attachmentId);
    }

    // ── Routing CRUD ──────────────────────────────────────────────

    @Transactional
    public Routing createRouting(String name, UUID itemId, boolean isDefault,
                                  List<RoutingOperationInput> operations) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Routing routing = Routing.builder()
                .name(name)
                .itemId(itemId)
                .isDefault(isDefault)
                .operations(new ArrayList<>())
                .build();
        routing = routingRepository.save(routing);

        if (operations != null) {
            for (int i = 0; i < operations.size(); i++) {
                RoutingOperationInput input = operations.get(i);
                RoutingOperation ro = RoutingOperation.builder()
                        .routing(routing)
                        .operationId(input.operationId())
                        .workstationId(input.workstationId())
                        .sequenceNumber(input.sequenceNumber() > 0 ? input.sequenceNumber() : i + 1)
                        .setupTimeOverride(input.setupTimeOverride())
                        .runTimeOverride(input.runTimeOverride())
                        .build();
                routing.getOperations().add(ro);
            }
            routing = routingRepository.save(routing);
        }

        log.info("Created routing {} with {} operations for item {} org {}",
                name, routing.getOperations().size(), itemId, orgId);
        return routing;
    }

    @Transactional(readOnly = true)
    public List<Routing> listRoutings() {
        return routingRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(
                TenantContext.getCurrentOrgId());
    }

    @Transactional(readOnly = true)
    public Routing getRouting(UUID id) {
        return routingRepository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Routing", id));
    }

    // ── Operation dependencies (tracker #16) ─────────────────────────

    /**
     * Adds a "{@code successor} cannot start until {@code predecessor}
     * is complete" edge to the routing-op DAG. Both ids refer to rows
     * in {@code routing_operation} (not the master {@code operation}
     * table — each routing has its own op instances).
     *
     * <p>Cycle detection: walks the predecessor's existing ancestor
     * chain breadth-first; if the proposed successor already appears
     * anywhere in that chain, adding this edge would close a loop.
     * Refuses with {@code ROUTING_DEP_CYCLE}.
     *
     * <p>Idempotent — re-adding an existing edge is a silent no-op
     * (returns the existing row).
     */
    @Transactional
    public RoutingOperationDependency addOperationDependency(UUID successorRoutingOpId,
                                                             UUID predecessorRoutingOpId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (successorRoutingOpId.equals(predecessorRoutingOpId)) {
            throw new BusinessException("An operation cannot depend on itself",
                    "ROUTING_DEP_SELF_LOOP", HttpStatus.BAD_REQUEST);
        }

        RoutingOperation succ = routingOperationRepository.findById(successorRoutingOpId)
                .orElseThrow(() -> BusinessException.notFound("RoutingOperation", successorRoutingOpId));
        RoutingOperation pred = routingOperationRepository.findById(predecessorRoutingOpId)
                .orElseThrow(() -> BusinessException.notFound("RoutingOperation", predecessorRoutingOpId));
        if (succ.isDeleted() || pred.isDeleted()) {
            throw BusinessException.notFound("RoutingOperation", predecessorRoutingOpId);
        }
        // Both ops must belong to the same routing — cross-routing
        // dependencies aren't meaningful (each routing is independent).
        if (!succ.getRoutingId().equals(pred.getRoutingId())) {
            throw new BusinessException(
                    "Predecessor and successor must belong to the same routing",
                    "ROUTING_DEP_CROSS_ROUTING", HttpStatus.BAD_REQUEST);
        }

        if (operationDependencyRepository
                .existsByOrgIdAndRoutingOperationIdAndPredecessorRoutingOperationIdAndIsDeletedFalse(
                        orgId, successorRoutingOpId, predecessorRoutingOpId)) {
            // Idempotent: return the existing row.
            return operationDependencyRepository
                    .findByOrgIdAndRoutingOperationIdAndIsDeletedFalse(orgId, successorRoutingOpId)
                    .stream()
                    .filter(d -> d.getPredecessorRoutingOperationId().equals(predecessorRoutingOpId))
                    .findFirst()
                    .orElseThrow();
        }

        // Cycle check: BFS from the proposed predecessor walking BACK up
        // its existing predecessor chain. If the proposed successor
        // appears, the new edge would close a loop.
        if (wouldFormCycle(orgId, successorRoutingOpId, predecessorRoutingOpId)) {
            throw new BusinessException(
                    "Adding this dependency would form a cycle in the operation graph",
                    "ROUTING_DEP_CYCLE", HttpStatus.BAD_REQUEST);
        }

        RoutingOperationDependency dep = RoutingOperationDependency.builder()
                .routingOperationId(successorRoutingOpId)
                .predecessorRoutingOperationId(predecessorRoutingOpId)
                .build();
        dep.setOrgId(orgId);
        return operationDependencyRepository.save(dep);
    }

    private boolean wouldFormCycle(UUID orgId, UUID proposedSuccessor, UUID proposedPredecessor) {
        // BFS up from the predecessor through its own predecessors. If we
        // ever hit the proposed successor, the new edge would close a loop.
        java.util.Deque<UUID> stack = new java.util.ArrayDeque<>();
        java.util.Set<UUID> seen = new java.util.HashSet<>();
        stack.push(proposedPredecessor);
        while (!stack.isEmpty()) {
            UUID cur = stack.pop();
            if (!seen.add(cur)) continue;
            if (cur.equals(proposedSuccessor)) return true;
            for (RoutingOperationDependency d : operationDependencyRepository
                    .findByOrgIdAndRoutingOperationIdAndIsDeletedFalse(orgId, cur)) {
                stack.push(d.getPredecessorRoutingOperationId());
            }
        }
        return false;
    }

    @Transactional
    public void removeOperationDependency(UUID dependencyId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        RoutingOperationDependency dep = operationDependencyRepository
                .findByIdAndOrgIdAndIsDeletedFalse(dependencyId, orgId)
                .orElseThrow(() -> BusinessException.notFound(
                        "RoutingOperationDependency", dependencyId));
        dep.setDeleted(true);
        operationDependencyRepository.save(dep);
    }

    @Transactional(readOnly = true)
    public List<RoutingOperationDependency> listPredecessors(UUID routingOperationId) {
        return operationDependencyRepository
                .findByOrgIdAndRoutingOperationIdAndIsDeletedFalse(
                        TenantContext.getCurrentOrgId(), routingOperationId);
    }

    @Transactional(readOnly = true)
    public List<RoutingOperationDependency> listSuccessors(UUID routingOperationId) {
        return operationDependencyRepository
                .findByOrgIdAndPredecessorRoutingOperationIdAndIsDeletedFalse(
                        TenantContext.getCurrentOrgId(), routingOperationId);
    }

    // ── Alternative work centers (tracker #15) ───────────────────────

    /**
     * Registers a fallback workstation for a routing operation. The
     * operation's primary stays {@code routing_operation.workstation_id};
     * this adds a priority-ordered alternate to fall back to when the
     * primary is at capacity or down.
     *
     * <p>Rejects registering the primary itself as its own alternate
     * ({@code MFG_WS_ALT_SAME_AS_PRIMARY}) and duplicate registrations
     * ({@code MFG_WS_ALT_DUPLICATE}). Both the routing op and the
     * workstation are org-validated before insert.
     */
    @Transactional
    public WorkstationAlternate addWorkstationAlternate(UUID routingOperationId,
                                                        UUID workstationId,
                                                        Integer priority, String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();

        RoutingOperation op = routingOperationRepository.findById(routingOperationId)
                .filter(ro -> !ro.isDeleted() && orgId.equals(ro.getOrgId()))
                .orElseThrow(() -> BusinessException.notFound("RoutingOperation", routingOperationId));
        Workstation ws = workstationRepository.findByIdAndOrgIdAndIsDeletedFalse(workstationId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Workstation", workstationId));

        if (workstationId.equals(op.getWorkstationId())) {
            throw new BusinessException(
                    "Workstation " + ws.getCode() + " is already this operation's primary work center",
                    "MFG_WS_ALT_SAME_AS_PRIMARY", HttpStatus.BAD_REQUEST);
        }
        if (workstationAlternateRepository
                .existsByOrgIdAndRoutingOperationIdAndWorkstationIdAndIsDeletedFalse(
                        orgId, routingOperationId, workstationId)) {
            throw new BusinessException(
                    "Workstation " + ws.getCode() + " is already an alternate for this operation",
                    "MFG_WS_ALT_DUPLICATE", HttpStatus.CONFLICT);
        }

        WorkstationAlternate row = WorkstationAlternate.builder()
                .routingOperationId(routingOperationId)
                .workstationId(workstationId)
                .priority(priority != null ? priority : 1)
                .notes(notes)
                .build();
        row.setOrgId(orgId);
        return workstationAlternateRepository.save(row);
    }

    @Transactional(readOnly = true)
    public List<WorkstationAlternate> listWorkstationAlternates(UUID routingOperationId) {
        return workstationAlternateRepository
                .findByOrgIdAndRoutingOperationIdAndIsDeletedFalseOrderByPriorityAsc(
                        TenantContext.getCurrentOrgId(), routingOperationId);
    }

    @Transactional
    public void deleteWorkstationAlternate(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        WorkstationAlternate row = workstationAlternateRepository
                .findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkstationAlternate", id));
        row.setDeleted(true);
        workstationAlternateRepository.save(row);
    }

    /**
     * Picks the first work center able to absorb {@code requiredHours}
     * of load in a day, trying the operation's primary first and then
     * its alternates in priority order. A candidate qualifies when it is
     * active and its {@code capacityHoursPerDay} is at least
     * {@code requiredHours}.
     *
     * <p>This is a deliberately simple day-capacity gate — it doesn't
     * consult a scheduling calendar (that's the separate capacity-
     * planning track). It answers "which sanctioned machine can take
     * this op's daily load right now?", which is the 80% case for a
     * planner reassigning work off a downed primary.
     *
     * @throws BusinessException {@code MFG_NO_AVAILABLE_WORKSTATION} when
     *         neither the primary nor any alternate qualifies.
     */
    @Transactional(readOnly = true)
    public Workstation pickAvailableWorkstation(UUID routingOperationId, BigDecimal requiredHours) {
        UUID orgId = TenantContext.getCurrentOrgId();
        RoutingOperation op = routingOperationRepository.findById(routingOperationId)
                .filter(ro -> !ro.isDeleted() && orgId.equals(ro.getOrgId()))
                .orElseThrow(() -> BusinessException.notFound("RoutingOperation", routingOperationId));

        BigDecimal load = requiredHours != null ? requiredHours : BigDecimal.ZERO;

        // Ordered candidate ids: primary first, then alternates by priority.
        List<UUID> candidateIds = new ArrayList<>();
        if (op.getWorkstationId() != null) candidateIds.add(op.getWorkstationId());
        for (WorkstationAlternate alt : workstationAlternateRepository
                .findByOrgIdAndRoutingOperationIdAndIsDeletedFalseOrderByPriorityAsc(
                        orgId, routingOperationId)) {
            if (!candidateIds.contains(alt.getWorkstationId())) {
                candidateIds.add(alt.getWorkstationId());
            }
        }

        for (UUID wsId : candidateIds) {
            Workstation ws = workstationRepository.findByIdAndOrgIdAndIsDeletedFalse(wsId, orgId)
                    .orElse(null);
            if (ws == null || !ws.isActive()) continue;
            BigDecimal cap = ws.getCapacityHoursPerDay() != null
                    ? ws.getCapacityHoursPerDay() : BigDecimal.ZERO;
            if (cap.compareTo(load) >= 0) {
                return ws;
            }
        }
        throw new BusinessException(
                "No primary or alternate work center can absorb " + load
                        + "h of load for this operation",
                "MFG_NO_AVAILABLE_WORKSTATION", HttpStatus.CONFLICT);
    }

    // ── Job Cards ─────────────────────────────────────────────────

    @Transactional
    public List<JobCard> createJobCardsForWorkOrder(UUID workOrderId, UUID routingId, BigDecimal qty) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Routing routing = routingRepository.findByIdAndOrgIdAndIsDeletedFalse(routingId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Routing", routingId));

        List<RoutingOperation> ops = routing.getOperations().stream()
                .filter(o -> !o.isDeleted())
                .sorted((a, b) -> Integer.compare(a.getSequenceNumber(), b.getSequenceNumber()))
                .toList();

        if (ops.isEmpty()) {
            throw new BusinessException("Routing has no operations",
                    "MFG_ROUTING_EMPTY", HttpStatus.BAD_REQUEST);
        }

        List<JobCard> cards = new ArrayList<>();
        for (RoutingOperation ro : ops) {
            JobCard card = JobCard.builder()
                    .workOrderId(workOrderId)
                    .operationId(ro.getOperationId())
                    .workstationId(ro.getWorkstationId())
                    .sequenceNumber(ro.getSequenceNumber())
                    .plannedQty(qty)
                    .build();
            cards.add(card);
        }
        cards = jobCardRepository.saveAll(cards);
        log.info("Created {} job cards for work order {} from routing {} org {}",
                cards.size(), workOrderId, routing.getName(), orgId);
        return cards;
    }

    @Transactional(readOnly = true)
    public List<JobCard> getJobCardsForWorkOrder(UUID workOrderId) {
        return jobCardRepository.findByWorkOrderIdAndOrgIdAndIsDeletedFalseOrderBySequenceNumberAsc(
                workOrderId, TenantContext.getCurrentOrgId());
    }

    @Transactional
    public JobCard startJobCard(UUID jobCardId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        JobCard card = jobCardRepository.findByIdAndOrgIdAndIsDeletedFalse(jobCardId, orgId)
                .orElseThrow(() -> BusinessException.notFound("JobCard", jobCardId));

        if (!"PENDING".equals(card.getStatus())) {
            throw new BusinessException("Job card is not PENDING, current: " + card.getStatus(),
                    "MFG_JOB_CARD_NOT_PENDING", HttpStatus.BAD_REQUEST);
        }

        card.setStatus("IN_PROGRESS");
        card.setActualStart(Instant.now());
        return jobCardRepository.save(card);
    }

    @Transactional
    public JobCard completeJobCard(UUID jobCardId, BigDecimal completedQty, BigDecimal scrapQty,
                                    int timeLoggedMinutes, String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();
        JobCard card = jobCardRepository.findByIdAndOrgIdAndIsDeletedFalse(jobCardId, orgId)
                .orElseThrow(() -> BusinessException.notFound("JobCard", jobCardId));

        if (!"IN_PROGRESS".equals(card.getStatus())) {
            throw new BusinessException("Job card is not IN_PROGRESS, current: " + card.getStatus(),
                    "MFG_JOB_CARD_NOT_IN_PROGRESS", HttpStatus.BAD_REQUEST);
        }

        card.setCompletedQty(completedQty != null ? completedQty : card.getPlannedQty());
        card.setScrapQty(scrapQty != null ? scrapQty : BigDecimal.ZERO);
        card.setTimeLoggedMinutes(timeLoggedMinutes);
        card.setActualEnd(Instant.now());
        card.setStatus("COMPLETED");
        if (notes != null) card.setNotes(notes);

        return jobCardRepository.save(card);
    }

    public record RoutingOperationInput(
            UUID operationId,
            UUID workstationId,
            int sequenceNumber,
            Integer setupTimeOverride,
            BigDecimal runTimeOverride
    ) {}
}
