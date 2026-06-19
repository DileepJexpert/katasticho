package com.katasticho.erp.manufacturing.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.inventory.entity.BomAlternate;
import com.katasticho.erp.inventory.entity.BomCoProduct;
import com.katasticho.erp.inventory.entity.BomComponent;
import com.katasticho.erp.manufacturing.entity.*;
import com.katasticho.erp.manufacturing.service.*;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/manufacturing")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.MANUFACTURING)
@PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
public class ManufacturingController {

    private final ManufacturingService service;
    private final RoutingService routingService;
    private final JobWorkService jobWorkService;
    private final QualityControlService qcService;
    private final ScrapService scrapService;
    private final MrpService mrpService;

    @PostMapping("/work-orders")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkOrder>> createWorkOrder(@RequestBody Map<String, Object> body) {
        UUID finishedGoodId = UUID.fromString((String) body.get("finishedGoodId"));
        UUID warehouseId = UUID.fromString((String) body.get("warehouseId"));
        BigDecimal qty = new BigDecimal(body.get("quantityToProduce").toString());
        LocalDate plannedStart = body.get("plannedStartDate") != null
                ? LocalDate.parse((String) body.get("plannedStartDate")) : null;
        LocalDate plannedEnd = body.get("plannedEndDate") != null
                ? LocalDate.parse((String) body.get("plannedEndDate")) : null;
        BigDecimal laborCost = body.get("directLaborCost") != null
                ? new BigDecimal(body.get("directLaborCost").toString()) : null;
        BigDecimal overhead = body.get("overheadCost") != null
                ? new BigDecimal(body.get("overheadCost").toString()) : null;
        String notes = (String) body.get("notes");
        boolean backflush = Boolean.TRUE.equals(body.get("backflushMode"));
        Integer bomVersion = body.get("bomVersion") != null
                ? Integer.parseInt(body.get("bomVersion").toString()) : null;
        String priority = (String) body.get("priority");

        return ResponseEntity.ok(ApiResponse.ok(
                service.createWorkOrder(finishedGoodId, warehouseId, qty,
                        plannedStart, plannedEnd, laborCost, overhead, notes,
                        backflush, bomVersion, false, priority),
                "Work order created"));
    }

    @GetMapping("/work-orders")
    public ResponseEntity<ApiResponse<Page<WorkOrder>>> listWorkOrders(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String priority,
            Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(service.listWorkOrders(status, priority, pageable)));
    }

    @GetMapping("/work-orders/{id}")
    public ResponseEntity<ApiResponse<WorkOrder>> getWorkOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getWorkOrder(id)));
    }

    /** Shop-floor lookup by the printed/scanned WO number (e.g. WO-00042). */
    @GetMapping("/work-orders/by-number/{number}")
    public ResponseEntity<ApiResponse<WorkOrder>> getWorkOrderByNumber(
            @PathVariable("number") String number) {
        return ResponseEntity.ok(ApiResponse.ok(service.getWorkOrderByNumber(number)));
    }

    @PostMapping("/work-orders/{id}/issue")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkOrder>> issueToProduction(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.issueToProduction(id), "Issued to production"));
    }

    @PostMapping("/work-orders/{id}/receive")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkOrder>> receiveFinishedGoods(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        BigDecimal qty = new BigDecimal(body.get("quantityReceived").toString());
        String batchNumber = body.get("batchNumber") == null
                ? null : body.get("batchNumber").toString();
        java.time.LocalDate expiry = body.get("expiryDate") == null
                ? null : java.time.LocalDate.parse(body.get("expiryDate").toString());
        return ResponseEntity.ok(ApiResponse.ok(
                service.receiveFinishedGoods(id, qty, batchNumber, expiry),
                "Finished goods received"));
    }

    @PutMapping("/work-orders/{id}/costs")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkOrder>> updateCosts(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body) {
        BigDecimal laborCost = body.get("directLaborCost") != null
                ? new BigDecimal(body.get("directLaborCost").toString()) : null;
        BigDecimal overhead = body.get("overheadCost") != null
                ? new BigDecimal(body.get("overheadCost").toString()) : null;
        return ResponseEntity.ok(ApiResponse.ok(
                service.updateCosts(id, laborCost, overhead), "Costs updated"));
    }

    @PostMapping("/work-orders/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkOrder>> cancelWorkOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.cancelWorkOrder(id), "Work order cancelled"));
    }

    @RequestMapping(value = "/work-orders/{id}/priority",
            method = {RequestMethod.POST, RequestMethod.PATCH})
    public ResponseEntity<ApiResponse<WorkOrder>> updatePriority(
            @PathVariable UUID id, @RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.updatePriority(id, (String) body.get("priority")),
                "Priority updated"));
    }

    @PostMapping("/work-orders/{id}/clone")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkOrder>> cloneWorkOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.cloneWorkOrder(id), "Work order cloned"));
    }

    @PostMapping("/work-orders/from-sales-order")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<WorkOrder>>> createFromSalesOrder(
            @RequestBody Map<String, Object> body) {
        UUID salesOrderId = UUID.fromString((String) body.get("salesOrderId"));
        UUID warehouseId = body.get("warehouseId") != null
                ? UUID.fromString((String) body.get("warehouseId")) : null;
        return ResponseEntity.ok(ApiResponse.ok(
                service.createWorkOrdersFromSalesOrder(salesOrderId, warehouseId),
                "Work orders created from sales order"));
    }

    /**
     * Auto-create DRAFT work orders for every COMPOSITE item below its
     * reorder level (tracker #66). Idempotent — skips items that
     * already have an open WO. Run from an admin "Replenish now"
     * button or hook to an MRP cron later.
     */
    @PostMapping("/work-orders/from-reorder")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<WorkOrder>>> createFromReorder() {
        List<WorkOrder> created = service.autoCreateWorkOrdersFromReorder();
        return ResponseEntity.ok(ApiResponse.ok(created,
                "Created " + created.size() + " work order(s) from reorder sweep"));
    }

    // ── Workstations ──────────────────────────────────────────────

    @PostMapping("/workstations")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Workstation>> createWorkstation(@RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(routingService.createWorkstation(
                (String) body.get("code"), (String) body.get("name"),
                (String) body.get("description"),
                body.get("hourlyRate") != null ? new BigDecimal(body.get("hourlyRate").toString()) : null,
                body.get("capacityHoursPerDay") != null ? new BigDecimal(body.get("capacityHoursPerDay").toString()) : null
        ), "Workstation created"));
    }

    @GetMapping("/workstations")
    public ResponseEntity<ApiResponse<List<Workstation>>> listWorkstations() {
        return ResponseEntity.ok(ApiResponse.ok(routingService.listWorkstations()));
    }

    @GetMapping("/workstations/{id}")
    public ResponseEntity<ApiResponse<Workstation>> getWorkstation(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(routingService.getWorkstation(id)));
    }

    // ── Operations ────────────────────────────────────────────────

    @PostMapping("/operations")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Operation>> createOperation(@RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(routingService.createOperation(
                (String) body.get("code"), (String) body.get("name"),
                (String) body.get("description"),
                body.get("defaultWorkstationId") != null ? UUID.fromString((String) body.get("defaultWorkstationId")) : null,
                body.get("setupTimeMinutes") != null ? Integer.parseInt(body.get("setupTimeMinutes").toString()) : 0,
                body.get("runTimeMinutesPerUnit") != null ? new BigDecimal(body.get("runTimeMinutesPerUnit").toString()) : null
        ), "Operation created"));
    }

    @GetMapping("/operations")
    public ResponseEntity<ApiResponse<List<Operation>>> listOperations() {
        return ResponseEntity.ok(ApiResponse.ok(routingService.listOperations()));
    }

    @GetMapping("/operations/{id}")
    public ResponseEntity<ApiResponse<Operation>> getOperation(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(routingService.getOperation(id)));
    }

    // ── Routings ──────────────────────────────────────────────────

    @SuppressWarnings("unchecked")
    @PostMapping("/routings")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Routing>> createRouting(@RequestBody Map<String, Object> body) {
        List<RoutingService.RoutingOperationInput> ops = null;
        var rawOps = body.get("operations");
        if (rawOps instanceof List<?> list) {
            ops = list.stream().map(o -> {
                Map<String, Object> m = (Map<String, Object>) o;
                return new RoutingService.RoutingOperationInput(
                        UUID.fromString(m.get("operationId").toString()),
                        m.get("workstationId") != null ? UUID.fromString(m.get("workstationId").toString()) : null,
                        m.get("sequenceNumber") != null ? Integer.parseInt(m.get("sequenceNumber").toString()) : 0,
                        m.get("setupTimeOverride") != null ? Integer.parseInt(m.get("setupTimeOverride").toString()) : null,
                        m.get("runTimeOverride") != null ? new BigDecimal(m.get("runTimeOverride").toString()) : null
                );
            }).toList();
        }
        return ResponseEntity.ok(ApiResponse.ok(routingService.createRouting(
                (String) body.get("name"),
                body.get("itemId") != null ? UUID.fromString((String) body.get("itemId")) : null,
                Boolean.TRUE.equals(body.get("isDefault")),
                ops
        ), "Routing created"));
    }

    @GetMapping("/routings")
    public ResponseEntity<ApiResponse<List<Routing>>> listRoutings() {
        return ResponseEntity.ok(ApiResponse.ok(routingService.listRoutings()));
    }

    @GetMapping("/routings/{id}")
    public ResponseEntity<ApiResponse<Routing>> getRouting(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(routingService.getRouting(id)));
    }

    // ── Job Cards ─────────────────────────────────────────────────

    @GetMapping("/work-orders/{id}/job-cards")
    public ResponseEntity<ApiResponse<List<JobCard>>> getJobCards(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(routingService.getJobCardsForWorkOrder(id)));
    }

    @PostMapping("/job-cards/{id}/start")
    public ResponseEntity<ApiResponse<JobCard>> startJobCard(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(routingService.startJobCard(id), "Job card started"));
    }

    @PostMapping("/job-cards/{id}/complete")
    public ResponseEntity<ApiResponse<JobCard>> completeJobCard(
            @PathVariable UUID id, @RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(routingService.completeJobCard(id,
                body.get("completedQty") != null ? new BigDecimal(body.get("completedQty").toString()) : null,
                body.get("scrapQty") != null ? new BigDecimal(body.get("scrapQty").toString()) : null,
                body.get("timeLoggedMinutes") != null ? Integer.parseInt(body.get("timeLoggedMinutes").toString()) : 0,
                (String) body.get("notes")
        ), "Job card completed"));
    }

    // ── Job Work (Subcontracting) ─────────────────────────────────

    @SuppressWarnings("unchecked")
    @PostMapping("/job-work")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<JobWorkOrder>> createJobWorkOrder(@RequestBody Map<String, Object> body) {
        UUID vendorId = UUID.fromString((String) body.get("vendorId"));
        UUID warehouseId = UUID.fromString((String) body.get("warehouseId"));
        BigDecimal charges = body.get("processingCharges") != null
                ? new BigDecimal(body.get("processingCharges").toString()) : null;
        LocalDate sendDate = body.get("plannedSendDate") != null
                ? LocalDate.parse((String) body.get("plannedSendDate")) : null;
        LocalDate returnDate = body.get("plannedReturnDate") != null
                ? LocalDate.parse((String) body.get("plannedReturnDate")) : null;

        List<JobWorkService.JobWorkLineInput> materials = ((List<Map<String, Object>>) body.get("materials"))
                .stream().map(m -> new JobWorkService.JobWorkLineInput(
                        UUID.fromString(m.get("itemId").toString()),
                        new BigDecimal(m.get("qty").toString())
                )).toList();

        return ResponseEntity.ok(ApiResponse.ok(
                jobWorkService.createJobWorkOrder(vendorId, warehouseId, materials, charges,
                        sendDate, returnDate, (String) body.get("notes")),
                "Job work order created"));
    }

    @GetMapping("/job-work")
    public ResponseEntity<ApiResponse<Page<JobWorkOrder>>> listJobWorkOrders(
            @RequestParam(required = false) String status, Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(jobWorkService.listJobWorkOrders(status, pageable)));
    }

    @GetMapping("/job-work/{id}")
    public ResponseEntity<ApiResponse<JobWorkOrder>> getJobWorkOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(jobWorkService.getJobWorkOrder(id)));
    }

    @PostMapping("/job-work/{id}/send")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<JobWorkOrder>> sendMaterials(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                jobWorkService.sendMaterials(id), "Materials sent to job worker"));
    }

    @SuppressWarnings("unchecked")
    @PostMapping("/job-work/{id}/receive")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<JobWorkOrder>> receiveJobWorkGoods(
            @PathVariable UUID id, @RequestBody Map<String, Object> body) {
        List<JobWorkService.JobWorkReceiveInput> lines = ((List<Map<String, Object>>) body.get("lines"))
                .stream().map(m -> new JobWorkService.JobWorkReceiveInput(
                        UUID.fromString(m.get("itemId").toString()),
                        new BigDecimal(m.get("receivedQty").toString()),
                        m.get("wastageQty") != null ? new BigDecimal(m.get("wastageQty").toString()) : null
                )).toList();
        return ResponseEntity.ok(ApiResponse.ok(
                jobWorkService.receiveGoods(id, lines), "Goods received from job worker"));
    }

    @PostMapping("/job-work/{id}/cancel")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<JobWorkOrder>> cancelJobWorkOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                jobWorkService.cancelJobWorkOrder(id), "Job work order cancelled"));
    }

    @GetMapping("/job-work/gst-alerts")
    public ResponseEntity<ApiResponse<List<JobWorkOrder>>> gstDeadlineAlerts(
            @RequestParam(defaultValue = "30") int days) {
        return ResponseEntity.ok(ApiResponse.ok(jobWorkService.getGstDeadlineAlerts(days)));
    }

    // ── Quality Control ───────────────────────────────────────────

    @SuppressWarnings("unchecked")
    @PostMapping("/qc/templates")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<QcTemplate>> createQcTemplate(@RequestBody Map<String, Object> body) {
        List<QualityControlService.QcParameterInput> params = null;
        var rawParams = body.get("parameters");
        if (rawParams instanceof List<?> list) {
            params = list.stream().map(p -> {
                Map<String, Object> m = (Map<String, Object>) p;
                return new QualityControlService.QcParameterInput(
                        (String) m.get("name"), (String) m.get("description"),
                        (String) m.get("parameterType"), (String) m.get("unit"),
                        m.get("minValue") != null ? new BigDecimal(m.get("minValue").toString()) : null,
                        m.get("maxValue") != null ? new BigDecimal(m.get("maxValue").toString()) : null,
                        (String) m.get("acceptableValues"),
                        m.get("isMandatory") != null ? (Boolean) m.get("isMandatory") : null
                );
            }).toList();
        }
        return ResponseEntity.ok(ApiResponse.ok(qcService.createTemplate(
                (String) body.get("name"),
                body.get("itemId") != null ? UUID.fromString((String) body.get("itemId")) : null,
                (String) body.get("inspectionType"), params
        ), "QC template created"));
    }

    @GetMapping("/qc/templates")
    public ResponseEntity<ApiResponse<List<QcTemplate>>> listQcTemplates() {
        return ResponseEntity.ok(ApiResponse.ok(qcService.listTemplates()));
    }

    @GetMapping("/qc/templates/{id}")
    public ResponseEntity<ApiResponse<QcTemplate>> getQcTemplate(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(qcService.getTemplate(id)));
    }

    @PostMapping("/qc/inspections")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<QcInspection>> createInspection(@RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(qcService.createInspection(
                body.get("templateId") != null ? UUID.fromString((String) body.get("templateId")) : null,
                (String) body.get("inspectionType"),
                (String) body.get("referenceType"),
                body.get("referenceId") != null ? UUID.fromString((String) body.get("referenceId")) : null,
                UUID.fromString((String) body.get("itemId")),
                body.get("batchId") != null ? UUID.fromString((String) body.get("batchId")) : null,
                body.get("inspectedQty") != null ? new BigDecimal(body.get("inspectedQty").toString()) : null
        ), "QC inspection created"));
    }

    @GetMapping("/qc/inspections")
    public ResponseEntity<ApiResponse<Page<QcInspection>>> listInspections(Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(qcService.listInspections(pageable)));
    }

    @GetMapping("/qc/inspections/{id}")
    public ResponseEntity<ApiResponse<QcInspection>> getInspection(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(qcService.getInspection(id)));
    }

    @SuppressWarnings("unchecked")
    @PostMapping("/qc/inspections/{id}/results")
    public ResponseEntity<ApiResponse<QcInspection>> recordResults(
            @PathVariable UUID id, @RequestBody Map<String, Object> body) {
        List<QualityControlService.QcResultInput> results = ((List<Map<String, Object>>) body.get("results"))
                .stream().map(m -> new QualityControlService.QcResultInput(
                        UUID.fromString(m.get("parameterId").toString()),
                        (String) m.get("measuredValue"),
                        m.get("numericValue") != null ? new BigDecimal(m.get("numericValue").toString()) : null,
                        m.get("isPassed") != null ? (Boolean) m.get("isPassed") : null,
                        (String) m.get("notes")
                )).toList();
        return ResponseEntity.ok(ApiResponse.ok(
                qcService.recordResults(id, results), "Results recorded"));
    }

    @PostMapping("/qc/inspections/{id}/finalize")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<QcInspection>> finalizeInspection(
            @PathVariable UUID id, @RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(qcService.finalizeInspection(id,
                body.get("acceptedQty") != null ? new BigDecimal(body.get("acceptedQty").toString()) : null,
                body.get("rejectedQty") != null ? new BigDecimal(body.get("rejectedQty").toString()) : null,
                (String) body.get("notes")
        ), "Inspection finalized"));
    }

    @PostMapping("/qc-inspections/{id}/disposition")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<QcInspection>> recordDisposition(
            @PathVariable UUID id, @RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(qcService.recordDisposition(id,
                (String) body.get("decision"),
                body.get("acceptedQty") != null ? new BigDecimal(body.get("acceptedQty").toString()) : null,
                body.get("rejectedQty") != null ? new BigDecimal(body.get("rejectedQty").toString()) : null,
                body.get("holdQty") != null ? new BigDecimal(body.get("holdQty").toString()) : null,
                body.get("quarantineZoneId") != null ? UUID.fromString((String) body.get("quarantineZoneId")) : null,
                (String) body.get("notes")
        ), "Disposition recorded"));
    }

    @GetMapping("/qc-inspections/{id}/coa")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getCertificateOfAnalysis(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(qcService.generateCoa(id)));
    }

    // ── Non-Conformance Reports ───────────────────────────────────

    @PostMapping("/qc/ncrs")
    public ResponseEntity<ApiResponse<NonConformanceReport>> createNcr(@RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(qcService.createNcr(
                body.get("qcInspectionId") != null ? UUID.fromString((String) body.get("qcInspectionId")) : null,
                UUID.fromString((String) body.get("itemId")),
                (String) body.get("batchNumber"),
                (String) body.get("severity"),
                (String) body.get("reason"),
                (String) body.get("description")
        ), "NCR created"));
    }

    @GetMapping("/qc/ncrs")
    public ResponseEntity<ApiResponse<Page<NonConformanceReport>>> listNcrs(
            @RequestParam(required = false) String status, Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(qcService.listNcrs(status, pageable)));
    }

    @GetMapping("/qc/ncrs/{id}")
    public ResponseEntity<ApiResponse<NonConformanceReport>> getNcr(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(qcService.getNcr(id)));
    }

    @PutMapping("/qc/ncrs/{id}")
    public ResponseEntity<ApiResponse<NonConformanceReport>> updateNcr(
            @PathVariable UUID id, @RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(qcService.updateNcr(id,
                (String) body.get("correctiveAction"),
                (String) body.get("rootCause"),
                (String) body.get("status")
        ), "NCR updated"));
    }

    @PostMapping("/qc/ncrs/{id}/close")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<NonConformanceReport>> closeNcr(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(qcService.closeNcr(id), "NCR closed"));
    }

    // ── Scrap ─────────────────────────────────────────────────────

    @PostMapping("/scrap/reason-codes")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<ScrapReasonCode>> createReasonCode(@RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(
                scrapService.createReasonCode((String) body.get("code"), (String) body.get("description")),
                "Reason code created"));
    }

    @GetMapping("/scrap/reason-codes")
    public ResponseEntity<ApiResponse<List<ScrapReasonCode>>> listReasonCodes() {
        return ResponseEntity.ok(ApiResponse.ok(scrapService.listReasonCodes()));
    }

    @PostMapping("/work-orders/{id}/scrap")
    public ResponseEntity<ApiResponse<ProductionScrap>> recordScrap(
            @PathVariable UUID id, @RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(scrapService.recordScrap(id,
                UUID.fromString((String) body.get("itemId")),
                new BigDecimal(body.get("scrapQty").toString()),
                body.get("reasonCodeId") != null ? UUID.fromString((String) body.get("reasonCodeId")) : null,
                body.get("jobCardId") != null ? UUID.fromString((String) body.get("jobCardId")) : null,
                (String) body.get("notes")
        ), "Scrap recorded"));
    }

    @GetMapping("/work-orders/{id}/scrap")
    public ResponseEntity<ApiResponse<List<ProductionScrap>>> getScrapForWorkOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(scrapService.getScrapForWorkOrder(id)));
    }

    // ── Disassembly ──────────────────────────────────────────────────

    @PostMapping("/work-orders/disassembly")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkOrder>> createDisassemblyOrder(@RequestBody Map<String, Object> body) {
        UUID finishedGoodId = UUID.fromString((String) body.get("finishedGoodId"));
        UUID warehouseId = UUID.fromString((String) body.get("warehouseId"));
        BigDecimal qty = new BigDecimal(body.get("quantity").toString());
        return ResponseEntity.ok(ApiResponse.ok(
                service.createDisassemblyOrder(finishedGoodId, warehouseId, qty,
                        (String) body.get("notes")),
                "Disassembly order created"));
    }

    @PostMapping("/work-orders/{id}/disassemble")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkOrder>> executeDisassembly(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.executeDisassembly(id), "Disassembly executed"));
    }

    // ── BOM Versioning ───────────────────────────────────────────────

    @PostMapping("/bom/{parentItemId}/version")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> createBomVersion(
            @PathVariable UUID parentItemId,
            @RequestBody Map<String, Object> body) {
        int version = service.createBomVersion(parentItemId, (String) body.get("changeNotes"));
        return ResponseEntity.ok(ApiResponse.ok(
                Map.of("version", version, "parentItemId", parentItemId),
                "BOM version " + version + " created"));
    }

    @GetMapping("/bom/{parentItemId}/version/{version}")
    public ResponseEntity<ApiResponse<List<BomComponent>>> getBomVersion(
            @PathVariable UUID parentItemId, @PathVariable int version) {
        return ResponseEntity.ok(ApiResponse.ok(service.getBomVersion(parentItemId, version)));
    }

    @GetMapping("/bom/{parentItemId}/latest-version")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getLatestBomVersion(
            @PathVariable UUID parentItemId) {
        int version = service.getLatestBomVersion(parentItemId);
        return ResponseEntity.ok(ApiResponse.ok(Map.of("version", version)));
    }

    /**
     * Diff two BOM versions of the same parent item (tracker #41).
     * Returns added / removed / changed sections so the UI can render
     * a single diff table.
     */
    @GetMapping("/bom/{parentItemId}/diff")
    public ResponseEntity<ApiResponse<Map<String, Object>>> diffBomVersions(
            @PathVariable UUID parentItemId,
            @RequestParam int fromVersion,
            @RequestParam int toVersion) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.diffBomVersions(parentItemId, fromVersion, toVersion)));
    }

    // ── BOM Alternates (substitute materials) ────────────────────────

    @GetMapping("/bom-alternates")
    public ResponseEntity<ApiResponse<List<BomAlternate>>> listBomAlternates(
            @RequestParam UUID bomComponentId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listBomAlternates(bomComponentId)));
    }

    @PostMapping("/bom-alternates")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<BomAlternate>> addBomAlternate(@RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(service.addBomAlternate(
                UUID.fromString((String) body.get("bomComponentId")),
                UUID.fromString((String) body.get("alternateItemId")),
                body.get("priority") != null ? Integer.parseInt(body.get("priority").toString()) : null,
                (String) body.get("notes")
        ), "BOM alternate registered"));
    }

    @DeleteMapping("/bom-alternates/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteBomAlternate(@PathVariable UUID id) {
        service.deleteBomAlternate(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "BOM alternate removed"));
    }

    @PostMapping("/work-orders/{id}/lines/{lineId}/substitute")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<WorkOrder>> substituteWorkOrderLine(
            @PathVariable UUID id, @PathVariable UUID lineId,
            @RequestBody Map<String, Object> body) {
        UUID alternateItemId = UUID.fromString((String) body.get("alternateItemId"));
        return ResponseEntity.ok(ApiResponse.ok(
                service.substituteWorkOrderLine(id, lineId, alternateItemId),
                "Component substituted"));
    }

    // ── Co-products / By-products ────────────────────────────────────

    @GetMapping("/bom-co-products")
    public ResponseEntity<ApiResponse<List<BomCoProduct>>> listCoProducts(
            @RequestParam UUID parentItemId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listCoProducts(parentItemId)));
    }

    @PostMapping("/bom-co-products")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<BomCoProduct>> addCoProduct(@RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(service.addCoProduct(
                UUID.fromString((String) body.get("parentItemId")),
                UUID.fromString((String) body.get("coProductItemId")),
                new BigDecimal(body.get("quantityPerUnit").toString()),
                body.get("costAllocationPercent") != null
                        ? new BigDecimal(body.get("costAllocationPercent").toString()) : null
        ), "Co-product defined"));
    }

    @DeleteMapping("/bom-co-products/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteCoProduct(@PathVariable UUID id) {
        service.deleteCoProduct(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Co-product removed"));
    }

    // ── BOM Cost Roll-up ─────────────────────────────────────────────

    @GetMapping("/bom/{itemId}/cost-rollup")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getBomCostRollup(@PathVariable UUID itemId) {
        return ResponseEntity.ok(ApiResponse.ok(service.getBomCostRollup(itemId)));
    }

    // ── Production Reports ───────────────────────────────────────────

    @GetMapping("/reports/cost-variance")
    public ResponseEntity<ApiResponse<Page<ProductionCostSummary>>> listCostVariances(Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(service.listCostVariances(pageable)));
    }

    @GetMapping("/reports/cost-variance/{workOrderId}")
    public ResponseEntity<ApiResponse<ProductionCostSummary>> getCostVariance(@PathVariable UUID workOrderId) {
        return ResponseEntity.ok(ApiResponse.ok(service.getCostVariance(workOrderId)));
    }

    @GetMapping("/reports/wip-valuation")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getWipValuation() {
        return ResponseEntity.ok(ApiResponse.ok(service.getWipValuation()));
    }

    @GetMapping("/reports/consumption")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getConsumptionReport(
            @RequestParam(required = false) UUID finishedGoodId) {
        return ResponseEntity.ok(ApiResponse.ok(service.getConsumptionReport(finishedGoodId)));
    }

    @GetMapping("/reports/production-summary")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getProductionSummary(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate) {
        return ResponseEntity.ok(ApiResponse.ok(service.getProductionSummary(fromDate, toDate)));
    }

    @GetMapping("/reports/production-trends")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getProductionTrends(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate) {
        return ResponseEntity.ok(ApiResponse.ok(service.productionTrends(fromDate, toDate)));
    }

    @GetMapping("/reports/work-order-profitability")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getWorkOrderProfitability(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate) {
        return ResponseEntity.ok(ApiResponse.ok(service.workOrderProfitability(fromDate, toDate)));
    }

    @GetMapping("/reports/scrap-rate")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getScrapRateDashboard(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate) {
        return ResponseEntity.ok(ApiResponse.ok(service.scrapRateDashboard(fromDate, toDate)));
    }

    // ── MRP ──────────────────────────────────────────────────────────────────

    @PostMapping("/mrp/run")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<MrpRun>> runMrp(@RequestBody(required = false) Map<String, Object> body) {
        int horizonDays = body != null && body.containsKey("horizonDays")
                ? Integer.parseInt(body.get("horizonDays").toString()) : 90;
        return ResponseEntity.ok(ApiResponse.ok(mrpService.runMrp(horizonDays), "MRP run completed"));
    }

    @GetMapping("/mrp/runs")
    public ResponseEntity<ApiResponse<List<MrpRun>>> listMrpRuns() {
        return ResponseEntity.ok(ApiResponse.ok(mrpService.listMrpRuns()));
    }

    @GetMapping("/mrp/runs/{id}")
    public ResponseEntity<ApiResponse<MrpRun>> getMrpRun(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(mrpService.getMrpRun(id)));
    }

    @PostMapping("/mrp/planned-orders/{id}/convert-po")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<PlannedOrder>> convertPlannedToPO(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                mrpService.convertPlannedToPO(id), "Converted planned order to Purchase Order"));
    }

    @PostMapping("/mrp/planned-orders/{id}/convert-wo")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<PlannedOrder>> convertPlannedToWO(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                mrpService.convertPlannedToWO(id), "Converted planned order to Work Order"));
    }
}
