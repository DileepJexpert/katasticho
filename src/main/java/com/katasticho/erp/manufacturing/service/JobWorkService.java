package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.manufacturing.entity.JobWorkOrder;
import com.katasticho.erp.manufacturing.entity.JobWorkOrderLine;
import com.katasticho.erp.manufacturing.repository.JobWorkOrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class JobWorkService {

    private final JobWorkOrderRepository jobWorkOrderRepository;
    private final ItemRepository itemRepository;
    private final InventoryService inventoryService;

    @Transactional
    public JobWorkOrder createJobWorkOrder(UUID vendorId, UUID warehouseId,
                                            List<JobWorkLineInput> materials,
                                            BigDecimal processingCharges,
                                            LocalDate plannedSendDate, LocalDate plannedReturnDate,
                                            String notes) {
        return createJobWorkOrder(vendorId, warehouseId, materials, List.of(),
                processingCharges, plannedSendDate, plannedReturnDate, notes);
    }

    /**
     * Creates subcontracting work with separate raw-material and finished-good
     * lines. OUTPUT lines are the only lines eligible for finished stock receipt.
     */
    @Transactional
    public JobWorkOrder createJobWorkOrder(UUID vendorId, UUID warehouseId,
                                            List<JobWorkLineInput> materials,
                                            List<JobWorkLineInput> outputs,
                                            BigDecimal processingCharges,
                                            LocalDate plannedSendDate, LocalDate plannedReturnDate,
                                            String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();

        if (vendorId == null || warehouseId == null) {
            throw new BusinessException("Vendor and warehouse are required for job work",
                    "JW_VENDOR_AND_WAREHOUSE_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        if (materials == null || materials.isEmpty()) {
            throw new BusinessException("At least one material line is required",
                    "JW_NO_MATERIALS", HttpStatus.BAD_REQUEST);
        }

        int nextNum = jobWorkOrderRepository.findMaxJobWorkNumber(orgId) + 1;
        String jwNumber = String.format("JW-%05d", nextNum);

        JobWorkOrder jwo = JobWorkOrder.builder()
                .jobWorkNumber(jwNumber)
                .vendorId(vendorId)
                .warehouseId(warehouseId)
                .processingCharges(processingCharges != null ? processingCharges : BigDecimal.ZERO)
                .plannedSendDate(plannedSendDate)
                .plannedReturnDate(plannedReturnDate)
                .notes(notes)
                .lines(new ArrayList<>())
                .build();

        jwo = jobWorkOrderRepository.save(jwo);

        BigDecimal totalMaterialCost = BigDecimal.ZERO;
        for (JobWorkLineInput input : materials) {
            requirePositiveQuantity(input, "Material");
            var item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(input.itemId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("Item", input.itemId()));

            BigDecimal unitCost = item.getPurchasePrice() != null ? item.getPurchasePrice() : BigDecimal.ZERO;
            BigDecimal lineCost = unitCost.multiply(input.qty()).setScale(2, RoundingMode.HALF_UP);

            JobWorkOrderLine line = JobWorkOrderLine.builder()
                    .jobWorkOrder(jwo)
                    .itemId(input.itemId())
                    .lineType("MATERIAL")
                    .sentQty(input.qty())
                    .unitCost(unitCost)
                    .lineCost(lineCost)
                    .build();
            jwo.getLines().add(line);
            totalMaterialCost = totalMaterialCost.add(lineCost);
        }

        if (outputs != null) {
            for (JobWorkLineInput input : outputs) {
                requirePositiveQuantity(input, "Finished-good");
                itemRepository.findByIdAndOrgIdAndIsDeletedFalse(input.itemId(), orgId)
                        .orElseThrow(() -> BusinessException.notFound("Item", input.itemId()));
                jwo.getLines().add(JobWorkOrderLine.builder()
                        .jobWorkOrder(jwo)
                        .itemId(input.itemId())
                        .lineType("OUTPUT")
                        .sentQty(input.qty())
                        .unitCost(BigDecimal.ZERO)
                        .lineCost(BigDecimal.ZERO)
                        .build());
            }
        }

        jwo.setTotalMaterialCost(totalMaterialCost);
        jwo.setTotalCost(totalMaterialCost.add(jwo.getProcessingCharges()));
        jwo = jobWorkOrderRepository.save(jwo);

        log.info("Created job work order {} for vendor {} with {} lines for org {}",
                jwNumber, vendorId, materials.size(), orgId);
        return jwo;
    }

    @Transactional(readOnly = true)
    public JobWorkOrder getJobWorkOrder(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return jobWorkOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("JobWorkOrder", id));
    }

    @Transactional(readOnly = true)
    public Page<JobWorkOrder> listJobWorkOrders(String status, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (status != null && !status.isBlank()) {
            return jobWorkOrderRepository.findByOrgIdAndStatusAndIsDeletedFalse(orgId, status, pageable);
        }
        return jobWorkOrderRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pageable);
    }

    @Transactional
    public JobWorkOrder sendMaterials(UUID jobWorkOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        JobWorkOrder jwo = jobWorkOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(jobWorkOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("JobWorkOrder", jobWorkOrderId));

        if (!"DRAFT".equals(jwo.getStatus())) {
            throw new BusinessException("Only DRAFT job work orders can send materials, current: " + jwo.getStatus(),
                    "JW_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        for (JobWorkOrderLine line : jwo.getLines()) {
            if (line.isDeleted() || !"MATERIAL".equals(line.getLineType())) continue;

            inventoryService.recordMovement(new StockMovementRequest(
                    line.getItemId(),
                    jwo.getWarehouseId(),
                    MovementType.JOB_WORK_OUT,
                    line.getSentQty().negate(),
                    line.getUnitCost(),
                    LocalDate.now(),
                    ReferenceType.JOB_WORK_ORDER,
                    jwo.getId(),
                    jwo.getJobWorkNumber(),
                    "Materials sent to job worker — " + jwo.getJobWorkNumber()
            ));

            line.setStatus("SENT");
        }

        jwo.setStatus("SENT");
        jwo.setActualSendDate(LocalDate.now());
        jwo.setGstReturnDeadline(LocalDate.now().plusYears(1));
        jwo.setChallanNumber(jwo.getJobWorkNumber() + "-DC");

        jwo = jobWorkOrderRepository.save(jwo);
        log.info("Job work order {} materials sent, GST deadline {} for org {}",
                jwo.getJobWorkNumber(), jwo.getGstReturnDeadline(), orgId);
        return jwo;
    }

    @Transactional
    public JobWorkOrder receiveGoods(UUID jobWorkOrderId, List<JobWorkReceiveInput> receiptLines) {
        UUID orgId = TenantContext.getCurrentOrgId();

        JobWorkOrder jwo = jobWorkOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(jobWorkOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("JobWorkOrder", jobWorkOrderId));

        if (!"SENT".equals(jwo.getStatus()) && !"PARTIALLY_RECEIVED".equals(jwo.getStatus())) {
            throw new BusinessException(
                    "Only SENT or PARTIALLY_RECEIVED job work orders can receive goods, current: " + jwo.getStatus(),
                    "JW_CANNOT_RECEIVE", HttpStatus.BAD_REQUEST);
        }
        if (receiptLines == null || receiptLines.isEmpty()) {
            throw new BusinessException("At least one receipt line is required",
                    "JW_NO_RECEIPT_LINES", HttpStatus.BAD_REQUEST);
        }

        boolean hasOutputLines = jwo.getLines().stream()
                .anyMatch(l -> !l.isDeleted() && "OUTPUT".equals(l.getLineType()));
        String receiveLineType = hasOutputLines ? "OUTPUT" : "MATERIAL";

        for (JobWorkReceiveInput input : receiptLines) {
            requireNonNegativeReceipt(input);
            JobWorkOrderLine line = jwo.getLines().stream()
                    .filter(l -> !l.isDeleted() && l.getItemId().equals(input.itemId())
                            && receiveLineType.equals(l.getLineType()))
                    .findFirst()
                    .orElseThrow(() -> new BusinessException(
                            (hasOutputLines ? "Finished-good" : "Material")
                                    + " line not found for item " + input.itemId(),
                            "JW_LINE_NOT_FOUND", HttpStatus.BAD_REQUEST));

            BigDecimal newReceived = line.getReceivedQty().add(input.receivedQty());
            BigDecimal newWastage = input.wastageQty() != null
                    ? line.getWastageQty().add(input.wastageQty()) : line.getWastageQty();

            if (newReceived.add(newWastage).compareTo(line.getSentQty()) > 0) {
                throw new BusinessException(
                        "Received + wastage cannot exceed sent qty for item " + input.itemId(),
                        "JW_EXCEEDS_SENT", HttpStatus.BAD_REQUEST);
            }

            BigDecimal receiptUnitCost = hasOutputLines
                    ? outputUnitCost(jwo) : line.getUnitCost();
            line.setUnitCost(receiptUnitCost);
            line.setLineCost(receiptUnitCost.multiply(newReceived)
                    .setScale(2, RoundingMode.HALF_UP));

            inventoryService.recordMovement(new StockMovementRequest(
                    line.getItemId(),
                    jwo.getWarehouseId(),
                    MovementType.JOB_WORK_IN,
                    input.receivedQty(),
                    receiptUnitCost,
                    LocalDate.now(),
                    ReferenceType.JOB_WORK_ORDER,
                    jwo.getId(),
                    jwo.getJobWorkNumber(),
                    "Goods received from job worker — " + jwo.getJobWorkNumber()
            ));

            line.setReceivedQty(newReceived);
            line.setWastageQty(newWastage);

            if (newReceived.add(newWastage).compareTo(line.getSentQty()) >= 0) {
                line.setStatus("RECEIVED");
            } else {
                line.setStatus("PARTIAL");
            }
        }

        boolean allReceived = jwo.getLines().stream()
                .filter(l -> !l.isDeleted() && receiveLineType.equals(l.getLineType()))
                .allMatch(l -> "RECEIVED".equals(l.getStatus()));

        if (allReceived) {
            jwo.setStatus("COMPLETED");
            jwo.setActualReturnDate(LocalDate.now());
            if (hasOutputLines) {
                jwo.getLines().stream()
                        .filter(l -> !l.isDeleted() && "MATERIAL".equals(l.getLineType()))
                        .forEach(l -> l.setStatus("CONSUMED"));
            }
        } else {
            jwo.setStatus("PARTIALLY_RECEIVED");
        }

        jwo = jobWorkOrderRepository.save(jwo);
        log.info("Job work order {} received goods, status={} for org {}",
                jwo.getJobWorkNumber(), jwo.getStatus(), orgId);
        return jwo;
    }

    @Transactional
    public JobWorkOrder cancelJobWorkOrder(UUID jobWorkOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        JobWorkOrder jwo = jobWorkOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(jobWorkOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("JobWorkOrder", jobWorkOrderId));

        if ("COMPLETED".equals(jwo.getStatus())) {
            throw new BusinessException("Completed job work orders cannot be cancelled",
                    "JW_ALREADY_COMPLETED", HttpStatus.BAD_REQUEST);
        }
        if ("CANCELLED".equals(jwo.getStatus())) {
            throw new BusinessException("Job work order is already cancelled",
                    "JW_ALREADY_CANCELLED", HttpStatus.BAD_REQUEST);
        }

        boolean hasReceivedOutput = jwo.getLines().stream()
                .anyMatch(l -> !l.isDeleted() && "OUTPUT".equals(l.getLineType())
                        && (l.getReceivedQty().signum() > 0 || l.getWastageQty().signum() > 0));
        if (hasReceivedOutput) {
            throw new BusinessException(
                    "A job work order with returned output cannot be cancelled automatically; use a stock correction flow",
                    "JW_OUTPUT_RECEIVED_CANNOT_CANCEL", HttpStatus.BAD_REQUEST);
        }

        if ("SENT".equals(jwo.getStatus()) || "PARTIALLY_RECEIVED".equals(jwo.getStatus())) {
            for (JobWorkOrderLine line : jwo.getLines()) {
                if (line.isDeleted() || !"MATERIAL".equals(line.getLineType())) continue;
                BigDecimal unreceived = line.getSentQty().subtract(line.getReceivedQty()).subtract(line.getWastageQty());
                if (unreceived.compareTo(BigDecimal.ZERO) > 0) {
                    inventoryService.recordMovement(new StockMovementRequest(
                            line.getItemId(),
                            jwo.getWarehouseId(),
                            MovementType.ADJUSTMENT,
                            unreceived,
                            line.getUnitCost(),
                            LocalDate.now(),
                            ReferenceType.JOB_WORK_ORDER,
                            jwo.getId(),
                            jwo.getJobWorkNumber(),
                            "Reversal — job work " + jwo.getJobWorkNumber() + " cancelled"
                    ));
                }
            }
        }

        jwo.setStatus("CANCELLED");
        jwo.getLines().forEach(l -> { if (!l.isDeleted()) l.setStatus("CANCELLED"); });

        jwo = jobWorkOrderRepository.save(jwo);
        log.info("Job work order {} cancelled for org {}", jwo.getJobWorkNumber(), orgId);
        return jwo;
    }

    @Transactional(readOnly = true)
    private BigDecimal outputUnitCost(JobWorkOrder jwo) {
        BigDecimal plannedOutput = jwo.getLines().stream()
                .filter(l -> !l.isDeleted() && "OUTPUT".equals(l.getLineType()))
                .map(JobWorkOrderLine::getSentQty)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        if (plannedOutput.signum() <= 0) return BigDecimal.ZERO;
        return jwo.getTotalCost().divide(plannedOutput, 6, RoundingMode.HALF_UP);
    }
    public List<JobWorkOrder> getGstDeadlineAlerts(int daysBeforeDeadline) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate deadline = LocalDate.now().plusDays(daysBeforeDeadline);
        return jobWorkOrderRepository.findByOrgIdAndGstReturnDeadlineBeforeAndStatusNotAndIsDeletedFalse(
                orgId, deadline, "COMPLETED");
    }

    private void requirePositiveQuantity(JobWorkLineInput input, String lineLabel) {
        if (input == null || input.itemId() == null || input.qty() == null || input.qty().signum() <= 0) {
            throw new BusinessException(lineLabel + " item and positive quantity are required",
                    "JW_LINE_QTY_INVALID", HttpStatus.BAD_REQUEST);
        }
    }

    private void requireNonNegativeReceipt(JobWorkReceiveInput input) {
        if (input == null || input.itemId() == null || input.receivedQty() == null
                || input.receivedQty().signum() < 0
                || (input.wastageQty() != null && input.wastageQty().signum() < 0)) {
            throw new BusinessException("Receipt item, received quantity, and wastage must be non-negative",
                    "JW_RECEIPT_QTY_INVALID", HttpStatus.BAD_REQUEST);
        }
        if (input.receivedQty().signum() == 0
                && (input.wastageQty() == null || input.wastageQty().signum() == 0)) {
            throw new BusinessException("Receipt quantity or wastage must be greater than zero",
                    "JW_RECEIPT_QTY_INVALID", HttpStatus.BAD_REQUEST);
        }
    }

    public record JobWorkLineInput(UUID itemId, BigDecimal qty) {}
    public record JobWorkReceiveInput(UUID itemId, BigDecimal receivedQty, BigDecimal wastageQty) {}
}
