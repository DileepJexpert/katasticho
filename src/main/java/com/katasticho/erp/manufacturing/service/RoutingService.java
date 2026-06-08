package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.manufacturing.entity.*;
import com.katasticho.erp.manufacturing.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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
