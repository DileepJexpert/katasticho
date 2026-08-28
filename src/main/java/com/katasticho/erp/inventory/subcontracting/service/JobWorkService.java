package com.katasticho.erp.inventory.subcontracting.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.inventory.subcontracting.entity.JobWorkIssueLine;
import com.katasticho.erp.inventory.subcontracting.entity.JobWorkOrder;
import com.katasticho.erp.inventory.subcontracting.entity.JobWorkReceiptLine;
import com.katasticho.erp.inventory.subcontracting.repository.JobWorkIssueLineRepository;
import com.katasticho.erp.inventory.subcontracting.repository.JobWorkOrderRepository;
import com.katasticho.erp.inventory.subcontracting.repository.JobWorkReceiptLineRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class JobWorkService {

    private final JobWorkOrderRepository orderRepository;
    private final JobWorkIssueLineRepository issueLineRepository;
    private final JobWorkReceiptLineRepository receiptLineRepository;
    private final ContactRepository contactRepository;
    private final ItemRepository itemRepository;
    private final InventoryService inventoryService;
    private final WarehouseRepository warehouseRepository;

    public record CreateJobWorkOrderRequest(
            UUID jobWorkerId,
            LocalDate orderDate,
            LocalDate expectedReturnDate,
            String processDescription,
            String notes,
            List<IssueLineRequest> issueLines
    ) {}

    public record IssueLineRequest(
            String challanNumber,
            LocalDate challanDate,
            UUID itemId,
            BigDecimal issuedQuantity,
            BigDecimal unitRate,
            BigDecimal gstRate,
            String natureOfProcessing
    ) {}

    public record ReceiveJobWorkRequest(
            String inwardChallanNumber,
            LocalDate receiptDate,
            UUID finishedItemId,
            BigDecimal receivedQuantity,
            UUID consumedRawItemId,
            BigDecimal consumedQuantity,
            BigDecimal scrapQuantity,
            BigDecimal jobWorkCharges,
            String notes
    ) {}

    public record IssueLineResponse(
            UUID id,
            UUID jobWorkOrderId,
            String challanNumber,
            LocalDate challanDate,
            UUID itemId,
            String itemName,
            String hsnCode,
            String uom,
            BigDecimal issuedQuantity,
            BigDecimal returnedQuantity,
            BigDecimal pendingQuantity,
            BigDecimal unitRate,
            BigDecimal taxableValue,
            BigDecimal gstRate,
            String natureOfProcessing
    ) {}

    public record ReceiptLineResponse(
            UUID id,
            UUID jobWorkOrderId,
            String inwardChallanNumber,
            LocalDate receiptDate,
            UUID finishedItemId,
            String finishedItemName,
            String uom,
            BigDecimal receivedQuantity,
            UUID consumedRawItemId,
            String consumedRawItemName,
            BigDecimal consumedQuantity,
            BigDecimal scrapQuantity,
            BigDecimal jobWorkCharges,
            String notes
    ) {}

    public record JobWorkOrderResponse(
            UUID id,
            String orderNumber,
            UUID jobWorkerId,
            String jobWorkerName,
            String jobWorkerGstin,
            LocalDate orderDate,
            LocalDate expectedReturnDate,
            String status,
            String processDescription,
            BigDecimal totalIssuedValue,
            BigDecimal totalReceivedValue,
            String notes,
            List<IssueLineResponse> issueLines,
            List<ReceiptLineResponse> receiptLines
    ) {}

    public record Itc04Line(
            String challanNumber,
            LocalDate challanDate,
            String jobWorkerName,
            String jobWorkerGstin,
            String itemName,
            String hsnCode,
            String uom,
            BigDecimal quantity,
            BigDecimal taxableValue,
            String natureOfProcessing,
            String recordType // "SENT_INPUTS" | "RECEIVED_BACK"
    ) {}

    public record Itc04SummaryResponse(
            String quarter,
            int year,
            int totalChallans,
            BigDecimal totalIssuedValue,
            BigDecimal totalReturnedValue,
            BigDecimal pendingValue,
            List<Itc04Line> table4InputsSent,
            List<Itc04Line> table5AReceivedBack
    ) {}

    @Transactional
    public JobWorkOrderResponse createOrder(CreateJobWorkOrderRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Contact worker = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(req.jobWorkerId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", req.jobWorkerId()));

        UUID warehouseId = resolveWarehouse(orgId);
        String orderNo = "JWO-" + System.currentTimeMillis() % 1000000;

        JobWorkOrder order = JobWorkOrder.builder()
                .orderNumber(orderNo)
                .jobWorkerId(req.jobWorkerId())
                .orderDate(req.orderDate() != null ? req.orderDate() : LocalDate.now())
                .expectedReturnDate(req.expectedReturnDate())
                .status("ISSUED")
                .processDescription(req.processDescription())
                .notes(req.notes())
                .build();
        order.setOrgId(orgId);
        order = orderRepository.save(order);

        BigDecimal totalIssued = BigDecimal.ZERO;
        List<JobWorkIssueLine> savedIssues = new ArrayList<>();

        if (req.issueLines() != null) {
            for (IssueLineRequest lineReq : req.issueLines()) {
                Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(lineReq.itemId(), orgId)
                        .orElseThrow(() -> BusinessException.notFound("Item", lineReq.itemId()));

                BigDecimal qty = lineReq.issuedQuantity() != null ? lineReq.issuedQuantity() : BigDecimal.ZERO;
                BigDecimal rate = lineReq.unitRate() != null ? lineReq.unitRate() : item.getPurchasePrice();
                BigDecimal taxVal = qty.multiply(rate);
                totalIssued = totalIssued.add(taxVal);

                JobWorkIssueLine issue = JobWorkIssueLine.builder()
                        .jobWorkOrderId(order.getId())
                        .challanNumber(lineReq.challanNumber() != null ? lineReq.challanNumber() : "CH45-" + orderNo)
                        .challanDate(lineReq.challanDate() != null ? lineReq.challanDate() : order.getOrderDate())
                        .itemId(item.getId())
                        .hsnCode(item.getHsnCode())
                        .uom(item.getUnitOfMeasure())
                        .issuedQuantity(qty)
                        .returnedQuantity(BigDecimal.ZERO)
                        .unitRate(rate)
                        .taxableValue(taxVal)
                        .gstRate(lineReq.gstRate() != null ? lineReq.gstRate() : item.getGstRate())
                        .natureOfProcessing(lineReq.natureOfProcessing() != null ? lineReq.natureOfProcessing() : req.processDescription())
                        .build();
                issue.setOrgId(orgId);
                savedIssues.add(issueLineRepository.save(issue));

                // Record inventory stock deduction for Challan 45 raw materials outward dispatch
                if (warehouseId != null && qty.compareTo(BigDecimal.ZERO) > 0) {
                    try {
                        inventoryService.recordMovement(new StockMovementRequest(
                                item.getId(),
                                warehouseId,
                                MovementType.JOB_WORK_OUT,
                                qty.negate(),
                                rate,
                                issue.getChallanDate(),
                                ReferenceType.JOB_WORK_ORDER,
                                order.getId(),
                                issue.getChallanNumber(),
                                "Challan 45 raw material issue for Job Work: " + order.getOrderNumber()
                        ));
                    } catch (Exception e) {
                        log.warn("[JobWorkService] Non-blocking stock movement record warning for item {}: {}",
                                item.getId(), e.getMessage());
                    }
                }
            }
        }

        order.setTotalIssuedValue(totalIssued);
        order = orderRepository.save(order);

        return toOrderResponse(order, worker, savedIssues, List.of());
    }

    @Transactional
    public JobWorkOrderResponse recordReceipt(UUID orderId, ReceiveJobWorkRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        JobWorkOrder order = orderRepository.findByIdAndOrgIdAndIsDeletedFalse(orderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("JobWorkOrder", orderId));

        UUID warehouseId = resolveWarehouse(orgId);
        UUID workerId = order.getJobWorkerId();
        Contact worker = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(workerId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", workerId));

        Item finishedItem = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(req.finishedItemId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", req.finishedItemId()));

        JobWorkReceiptLine receipt = JobWorkReceiptLine.builder()
                .jobWorkOrderId(order.getId())
                .inwardChallanNumber(req.inwardChallanNumber() != null ? req.inwardChallanNumber() : "INW-" + System.currentTimeMillis() % 100000)
                .receiptDate(req.receiptDate() != null ? req.receiptDate() : LocalDate.now())
                .finishedItemId(finishedItem.getId())
                .uom(finishedItem.getUnitOfMeasure())
                .receivedQuantity(req.receivedQuantity() != null ? req.receivedQuantity() : BigDecimal.ZERO)
                .consumedRawItemId(req.consumedRawItemId())
                .consumedQuantity(req.consumedQuantity() != null ? req.consumedQuantity() : BigDecimal.ZERO)
                .scrapQuantity(req.scrapQuantity() != null ? req.scrapQuantity() : BigDecimal.ZERO)
                .jobWorkCharges(req.jobWorkCharges() != null ? req.jobWorkCharges() : BigDecimal.ZERO)
                .notes(req.notes())
                .build();
        receipt.setOrgId(orgId);
        receiptLineRepository.save(receipt);

        // Record stock inward for finished goods received back
        if (warehouseId != null && receipt.getReceivedQuantity().compareTo(BigDecimal.ZERO) > 0) {
            try {
                inventoryService.recordMovement(new StockMovementRequest(
                        finishedItem.getId(),
                        warehouseId,
                        MovementType.JOB_WORK_IN,
                        receipt.getReceivedQuantity(),
                        finishedItem.getPurchasePrice(),
                        receipt.getReceiptDate(),
                        ReferenceType.JOB_WORK_ORDER,
                        order.getId(),
                        receipt.getInwardChallanNumber(),
                        "Finished goods receipt from Job Work: " + order.getOrderNumber()
                ));
            } catch (Exception e) {
                log.warn("[JobWorkService] Non-blocking finished goods stock receipt warning: {}", e.getMessage());
            }
        }

        // Update returned / consumed qty on corresponding issue line if matching raw item
        List<JobWorkIssueLine> issueLines = issueLineRepository.findByOrgIdAndJobWorkOrderIdAndIsDeletedFalse(orgId, order.getId());
        BigDecimal totalReturned = BigDecimal.ZERO;
        boolean allReturned = true;

        for (JobWorkIssueLine issue : issueLines) {
            if (req.consumedRawItemId() != null && req.consumedRawItemId().equals(issue.getItemId())) {
                BigDecimal newReturned = issue.getReturnedQuantity().add(
                        req.consumedQuantity() != null ? req.consumedQuantity() : BigDecimal.ZERO);
                issue.setReturnedQuantity(newReturned);
                issueLineRepository.save(issue);
            }
            totalReturned = totalReturned.add(issue.getReturnedQuantity().multiply(issue.getUnitRate()));
            if (issue.getReturnedQuantity().compareTo(issue.getIssuedQuantity()) < 0) {
                allReturned = false;
            }
        }

        order.setTotalReceivedValue(totalReturned);
        order.setStatus(allReturned ? "COMPLETED" : "PARTIALLY_RECEIVED");
        order = orderRepository.save(order);

        List<JobWorkReceiptLine> receipts = receiptLineRepository.findByOrgIdAndJobWorkOrderIdAndIsDeletedFalse(orgId, order.getId());
        return toOrderResponse(order, worker, issueLines, receipts);
    }

    private UUID resolveWarehouse(UUID orgId) {
        return warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .map(Warehouse::getId)
                .or(() -> warehouseRepository.findByOrgIdAndIsDeletedFalseOrderByName(orgId).stream()
                        .map(Warehouse::getId).findFirst())
                .orElse(null);
    }

    @Transactional(readOnly = true)
    public JobWorkOrderResponse getOrder(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        JobWorkOrder order = orderRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("JobWorkOrder", id));

        UUID workerId = order.getJobWorkerId();
        Contact worker = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(workerId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", workerId));

        List<JobWorkIssueLine> issues = issueLineRepository.findByOrgIdAndJobWorkOrderIdAndIsDeletedFalse(orgId, order.getId());
        List<JobWorkReceiptLine> receipts = receiptLineRepository.findByOrgIdAndJobWorkOrderIdAndIsDeletedFalse(orgId, order.getId());

        return toOrderResponse(order, worker, issues, receipts);
    }

    @Transactional(readOnly = true)
    public Page<JobWorkOrderResponse> listOrders(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Page<JobWorkOrder> page = orderRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pageable);

        return page.map(order -> {
            Contact worker = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(order.getJobWorkerId(), orgId).orElse(null);
            List<JobWorkIssueLine> issues = issueLineRepository.findByOrgIdAndJobWorkOrderIdAndIsDeletedFalse(orgId, order.getId());
            List<JobWorkReceiptLine> receipts = receiptLineRepository.findByOrgIdAndJobWorkOrderIdAndIsDeletedFalse(orgId, order.getId());
            return toOrderResponse(order, worker, issues, receipts);
        });
    }

    @Transactional(readOnly = true)
    public Itc04SummaryResponse getItc04Summary(String quarter, int year) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate startDate = getQuarterStartDate(quarter, year);
        LocalDate endDate = getQuarterEndDate(quarter, year);

        List<JobWorkIssueLine> issues = issueLineRepository.findByOrgIdAndChallanDateBetweenAndIsDeletedFalse(orgId, startDate, endDate);
        List<JobWorkReceiptLine> receipts = receiptLineRepository.findByOrgIdAndReceiptDateBetweenAndIsDeletedFalse(orgId, startDate, endDate);

        BigDecimal totalIssued = issues.stream().map(JobWorkIssueLine::getTaxableValue).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalReturned = issues.stream()
                .map(i -> i.getReturnedQuantity().multiply(i.getUnitRate()))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal pending = totalIssued.subtract(totalReturned);

        List<Itc04Line> table4 = new ArrayList<>();
        for (JobWorkIssueLine iss : issues) {
            Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(iss.getItemId(), orgId).orElse(null);
            JobWorkOrder order = orderRepository.findByIdAndOrgIdAndIsDeletedFalse(iss.getJobWorkOrderId(), orgId).orElse(null);
            Contact worker = order != null ? contactRepository.findByIdAndOrgIdAndIsDeletedFalse(order.getJobWorkerId(), orgId).orElse(null) : null;

            table4.add(new Itc04Line(
                    iss.getChallanNumber(),
                    iss.getChallanDate(),
                    worker != null ? worker.getDisplayName() : "Unknown Worker",
                    worker != null ? worker.getGstin() : null,
                    item != null ? item.getName() : "Item",
                    iss.getHsnCode(),
                    iss.getUom(),
                    iss.getIssuedQuantity(),
                    iss.getTaxableValue(),
                    iss.getNatureOfProcessing(),
                    "SENT_INPUTS"
            ));
        }

        List<Itc04Line> table5A = new ArrayList<>();
        for (JobWorkReceiptLine rec : receipts) {
            Item finItem = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(rec.getFinishedItemId(), orgId).orElse(null);
            JobWorkOrder order = orderRepository.findByIdAndOrgIdAndIsDeletedFalse(rec.getJobWorkOrderId(), orgId).orElse(null);
            Contact worker = order != null ? contactRepository.findByIdAndOrgIdAndIsDeletedFalse(order.getJobWorkerId(), orgId).orElse(null) : null;

            table5A.add(new Itc04Line(
                    rec.getInwardChallanNumber(),
                    rec.getReceiptDate(),
                    worker != null ? worker.getDisplayName() : "Unknown Worker",
                    worker != null ? worker.getGstin() : null,
                    finItem != null ? finItem.getName() : "Finished Good",
                    finItem != null ? finItem.getHsnCode() : null,
                    rec.getUom(),
                    rec.getReceivedQuantity(),
                    rec.getJobWorkCharges(),
                    "Received Processed Good",
                    "RECEIVED_BACK"
            ));
        }

        return new Itc04SummaryResponse(
                quarter != null ? quarter : "Q1",
                year > 0 ? year : LocalDate.now().getYear(),
                issues.size(),
                totalIssued,
                totalReturned,
                pending,
                table4,
                table5A
        );
    }

    private LocalDate getQuarterStartDate(String quarter, int year) {
        int y = year > 0 ? year : LocalDate.now().getYear();
        if ("Q2".equalsIgnoreCase(quarter)) return LocalDate.of(y, 4, 1);
        if ("Q3".equalsIgnoreCase(quarter)) return LocalDate.of(y, 7, 1);
        if ("Q4".equalsIgnoreCase(quarter)) return LocalDate.of(y, 10, 1);
        return LocalDate.of(y, 1, 1); // Q1 default
    }

    private LocalDate getQuarterEndDate(String quarter, int year) {
        int y = year > 0 ? year : LocalDate.now().getYear();
        if ("Q2".equalsIgnoreCase(quarter)) return LocalDate.of(y, 6, 30);
        if ("Q3".equalsIgnoreCase(quarter)) return LocalDate.of(y, 9, 30);
        if ("Q4".equalsIgnoreCase(quarter)) return LocalDate.of(y, 12, 31);
        return LocalDate.of(y, 3, 31); // Q1 default
    }

    private JobWorkOrderResponse toOrderResponse(
            JobWorkOrder order, Contact worker,
            List<JobWorkIssueLine> issues, List<JobWorkReceiptLine> receipts) {

        List<IssueLineResponse> issueResps = issues.stream().map(iss -> {
            Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(iss.getItemId(), order.getOrgId()).orElse(null);
            BigDecimal pending = iss.getIssuedQuantity().subtract(iss.getReturnedQuantity());
            return new IssueLineResponse(
                    iss.getId(),
                    iss.getJobWorkOrderId(),
                    iss.getChallanNumber(),
                    iss.getChallanDate(),
                    iss.getItemId(),
                    item != null ? item.getName() : "Item",
                    iss.getHsnCode(),
                    iss.getUom(),
                    iss.getIssuedQuantity(),
                    iss.getReturnedQuantity(),
                    pending,
                    iss.getUnitRate(),
                    iss.getTaxableValue(),
                    iss.getGstRate(),
                    iss.getNatureOfProcessing()
            );
        }).toList();

        List<ReceiptLineResponse> receiptResps = receipts.stream().map(rec -> {
            Item fin = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(rec.getFinishedItemId(), order.getOrgId()).orElse(null);
            Item raw = rec.getConsumedRawItemId() != null
                    ? itemRepository.findByIdAndOrgIdAndIsDeletedFalse(rec.getConsumedRawItemId(), order.getOrgId()).orElse(null)
                    : null;
            return new ReceiptLineResponse(
                    rec.getId(),
                    rec.getJobWorkOrderId(),
                    rec.getInwardChallanNumber(),
                    rec.getReceiptDate(),
                    rec.getFinishedItemId(),
                    fin != null ? fin.getName() : "Finished Item",
                    rec.getUom(),
                    rec.getReceivedQuantity(),
                    rec.getConsumedRawItemId(),
                    raw != null ? raw.getName() : null,
                    rec.getConsumedQuantity(),
                    rec.getScrapQuantity(),
                    rec.getJobWorkCharges(),
                    rec.getNotes()
            );
        }).toList();

        return new JobWorkOrderResponse(
                order.getId(),
                order.getOrderNumber(),
                order.getJobWorkerId(),
                worker != null ? worker.getDisplayName() : "Unknown Worker",
                worker != null ? worker.getGstin() : null,
                order.getOrderDate(),
                order.getExpectedReturnDate(),
                order.getStatus(),
                order.getProcessDescription(),
                order.getTotalIssuedValue(),
                order.getTotalReceivedValue(),
                order.getNotes(),
                issueResps,
                receiptResps
        );
    }
}
