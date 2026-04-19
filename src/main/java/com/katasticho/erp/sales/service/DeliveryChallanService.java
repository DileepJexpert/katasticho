package com.katasticho.erp.sales.service;

import com.katasticho.erp.ar.entity.InvoiceNumberSequence;
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.organisation.Branch;
import com.katasticho.erp.organisation.BranchRepository;
import com.katasticho.erp.sales.dto.*;
import com.katasticho.erp.sales.entity.*;
import com.katasticho.erp.sales.repository.DeliveryChallanRepository;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import com.katasticho.erp.sales.repository.StockReservationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class DeliveryChallanService {

    private final DeliveryChallanRepository challanRepository;
    private final SalesOrderRepository salesOrderRepository;
    private final StockReservationRepository reservationRepository;
    private final ContactRepository contactRepository;
    private final ItemRepository itemRepository;
    private final WarehouseRepository warehouseRepository;
    private final StockBatchRepository batchRepository;
    private final BranchRepository branchRepository;
    private final InvoiceNumberSequenceRepository sequenceRepository;
    private final InventoryService inventoryService;
    private final SalesOrderService salesOrderService;
    private final CommentService commentService;

    @Transactional
    public DeliveryChallanResponse create(CreateDeliveryChallanRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        SalesOrder so = salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(request.salesOrderId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Sales Order", request.salesOrderId()));

        String status = so.getStatus();
        if (!"CONFIRMED".equals(status) && !"PARTIALLY_SHIPPED".equals(status)) {
            throw new BusinessException("Sales order must be CONFIRMED or PARTIALLY_SHIPPED to create a challan",
                    "DC_INVALID_SO_STATUS", HttpStatus.BAD_REQUEST);
        }

        Warehouse warehouse = warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .orElseThrow(() -> new BusinessException("No default warehouse configured",
                        "DC_NO_WAREHOUSE", HttpStatus.BAD_REQUEST));

        UUID branchId = branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .map(Branch::getId).orElse(null);

        int year = LocalDate.now().getYear();
        String challanNumber = generateNumber(orgId, "DC", year);
        LocalDate challanDate = request.challanDate() != null ? request.challanDate() : LocalDate.now();

        DeliveryChallan challan = DeliveryChallan.builder()
                .branchId(branchId)
                .challanNumber(challanNumber)
                .salesOrderId(so.getId())
                .contactId(so.getContactId())
                .challanDate(challanDate)
                .warehouseId(warehouse.getId())
                .deliveryMethod(request.deliveryMethod())
                .vehicleNumber(request.vehicleNumber())
                .trackingNumber(request.trackingNumber())
                .notes(request.notes())
                .shippingAddress(request.shippingAddress() != null ? request.shippingAddress() : so.getShippingAddress())
                .build();

        int lineNum = 1;
        for (CreateDeliveryChallanRequest.ChallanLineRequest lr : request.lines()) {
            SalesOrderLine soLine = so.getLines().stream()
                    .filter(l -> l.getId().equals(lr.soLineId()))
                    .findFirst()
                    .orElseThrow(() -> new BusinessException(
                            "SO line not found: " + lr.soLineId(),
                            "DC_SO_LINE_NOT_FOUND", HttpStatus.BAD_REQUEST));

            BigDecimal remainingShippable = soLine.getQuantity().subtract(soLine.getQuantityShipped());
            if (lr.quantity().compareTo(remainingShippable) > 0) {
                throw new BusinessException(
                        String.format("Cannot ship more than ordered for %s: Ordered=%.2f, Already Shipped=%.2f, Requesting=%.2f",
                                soLine.getDescription() != null ? soLine.getDescription() : soLine.getItemId().toString(),
                                soLine.getQuantity(), soLine.getQuantityShipped(), lr.quantity()),
                        "DC_EXCEEDS_ORDERED", HttpStatus.BAD_REQUEST);
            }

            DeliveryChallanLine line = DeliveryChallanLine.builder()
                    .salesOrderLineId(soLine.getId())
                    .lineNumber(lineNum++)
                    .itemId(soLine.getItemId())
                    .description(soLine.getDescription())
                    .quantity(lr.quantity())
                    .unit(soLine.getUnit())
                    .batchId(lr.batchId())
                    .build();
            challan.addLine(line);
        }

        challan = challanRepository.save(challan);

        commentService.addSystemComment("SALES_ORDER", so.getId(),
                "Delivery Challan " + challanNumber + " created");
        commentService.addSystemComment("DELIVERY_CHALLAN", challan.getId(),
                "Challan created from SO " + so.getSalesorderNumber());

        log.info("Delivery challan {} created for SO {}", challanNumber, so.getSalesorderNumber());
        return toResponse(challan);
    }

    @Transactional
    public DeliveryChallanResponse dispatch(UUID challanId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        DeliveryChallan challan = findOrThrow(challanId, orgId);
        if (!"DRAFT".equals(challan.getStatus())) {
            throw new BusinessException("Only DRAFT challans can be dispatched",
                    "DC_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        UUID salesOrderId = challan.getSalesOrderId();
        SalesOrder so = salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(salesOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Sales Order", salesOrderId));

        int deductedCount = 0;
        for (DeliveryChallanLine line : challan.getLines()) {
            SalesOrderLine soLine = so.getLines().stream()
                    .filter(l -> l.getId().equals(line.getSalesOrderLineId()))
                    .findFirst()
                    .orElseThrow();

            soLine.setQuantityShipped(soLine.getQuantityShipped().add(line.getQuantity()));

            if (line.getItemId() == null) continue;

            Item item = itemRepository.findById(line.getItemId()).orElse(null);
            if (item == null || !item.isTrackInventory()) continue;

            StockMovementRequest moveRequest = new StockMovementRequest(
                    line.getItemId(),
                    challan.getWarehouseId(),
                    MovementType.SALE,
                    line.getQuantity().negate(),
                    null,
                    challan.getChallanDate(),
                    ReferenceType.DELIVERY_CHALLAN,
                    challan.getId(),
                    challan.getChallanNumber(),
                    "Dispatch via " + challan.getChallanNumber(),
                    line.getBatchId());
            inventoryService.recordMovement(moveRequest);
            deductedCount++;

            StockReservation reservation = reservationRepository
                    .findBySourceTypeAndSourceLineId("SALES_ORDER", soLine.getId())
                    .orElse(null);
            if (reservation != null && "ACTIVE".equals(reservation.getStatus())) {
                BigDecimal newReserved = reservation.getQuantityReserved().subtract(line.getQuantity());
                if (newReserved.compareTo(BigDecimal.ZERO) <= 0) {
                    reservation.setStatus("FULFILLED");
                    reservation.setFulfilledAt(Instant.now());
                    reservation.setQuantityReserved(BigDecimal.ZERO);
                } else {
                    reservation.setQuantityReserved(newReserved);
                }
                reservationRepository.save(reservation);
            }
        }

        boolean allShipped = so.getLines().stream()
                .allMatch(l -> l.getQuantityShipped().compareTo(l.getQuantity()) >= 0);
        boolean anyShipped = so.getLines().stream()
                .anyMatch(l -> l.getQuantityShipped().compareTo(BigDecimal.ZERO) > 0);

        if (allShipped) {
            so.setShippedStatus("FULLY_SHIPPED");
        } else if (anyShipped) {
            so.setShippedStatus("PARTIALLY_SHIPPED");
        }

        salesOrderService.updateDerivedStatus(so);
        salesOrderRepository.save(so);

        challan.setStatus("DISPATCHED");
        challan.setDispatchDate(LocalDate.now());
        challan = challanRepository.save(challan);

        commentService.addSystemComment("SALES_ORDER", so.getId(),
                "Challan " + challan.getChallanNumber() + " dispatched. Stock deducted for " + deductedCount + " items.");
        commentService.addSystemComment("DELIVERY_CHALLAN", challan.getId(),
                "Dispatched. " + deductedCount + " stock movements recorded.");

        log.info("Delivery challan {} dispatched (PGI) — {} stock deductions", challan.getChallanNumber(), deductedCount);
        return toResponse(challan);
    }

    @Transactional
    public DeliveryChallanResponse markDelivered(UUID challanId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        DeliveryChallan challan = findOrThrow(challanId, orgId);

        if (!"DISPATCHED".equals(challan.getStatus())) {
            throw new BusinessException("Only DISPATCHED challans can be marked delivered",
                    "DC_NOT_DISPATCHED", HttpStatus.BAD_REQUEST);
        }

        challan.setStatus("DELIVERED");
        challan = challanRepository.save(challan);

        commentService.addSystemComment("DELIVERY_CHALLAN", challan.getId(), "Marked as delivered");
        return toResponse(challan);
    }

    @Transactional
    public void cancel(UUID challanId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        DeliveryChallan challan = findOrThrow(challanId, orgId);

        if (!"DRAFT".equals(challan.getStatus())) {
            throw new BusinessException("Only DRAFT challans can be cancelled. Dispatched challans require a return process.",
                    "DC_CANNOT_CANCEL", HttpStatus.BAD_REQUEST);
        }

        challan.setStatus("CANCELLED");
        challanRepository.save(challan);

        commentService.addSystemComment("DELIVERY_CHALLAN", challan.getId(), "Cancelled");
        commentService.addSystemComment("SALES_ORDER", challan.getSalesOrderId(),
                "Challan " + challan.getChallanNumber() + " cancelled");
    }

    @Transactional
    public void delete(UUID challanId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        DeliveryChallan challan = findOrThrow(challanId, orgId);

        if (!"DRAFT".equals(challan.getStatus())) {
            throw new BusinessException("Only DRAFT challans can be deleted",
                    "DC_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        challan.setDeleted(true);
        challanRepository.save(challan);
    }

    public DeliveryChallanResponse get(UUID challanId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return toResponse(findOrThrow(challanId, orgId));
    }

    public Page<DeliveryChallanResponse> list(String status, UUID salesOrderId, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Page<DeliveryChallan> page;
        if (salesOrderId != null) {
            page = challanRepository.findByOrgIdAndSalesOrderIdAndIsDeletedFalse(orgId, salesOrderId, pageable);
        } else if (status != null) {
            page = challanRepository.findByOrgIdAndStatusAndIsDeletedFalse(orgId, status, pageable);
        } else {
            page = challanRepository.findByOrgIdAndIsDeletedFalseOrderByChallanDateDesc(orgId, pageable);
        }

        return page.map(this::toResponse);
    }

    public List<DeliveryChallanResponse> getChallansForSalesOrder(UUID salesOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return challanRepository.findBySalesOrderIdAndOrgIdAndIsDeletedFalse(salesOrderId, orgId)
                .stream().map(this::toResponse).toList();
    }

    private DeliveryChallan findOrThrow(UUID challanId, UUID orgId) {
        return challanRepository.findByIdAndOrgIdAndIsDeletedFalse(challanId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Delivery Challan", challanId));
    }

    private String generateNumber(UUID orgId, String prefix, int year) {
        var seqOpt = sequenceRepository.findByOrgIdAndPrefixAndYear(orgId, prefix, year);
        long nextVal;
        if (seqOpt.isPresent()) {
            nextVal = seqOpt.get().getNextValue();
            sequenceRepository.incrementAndGet(orgId, prefix, year);
        } else {
            var seqId = new InvoiceNumberSequence.InvoiceNumberSequenceId(orgId, prefix, year);
            sequenceRepository.save(InvoiceNumberSequence.builder()
                    .id(seqId).nextValue(2L).build());
            nextVal = 1L;
        }
        return String.format("%s-%d-%06d", prefix, year, nextVal);
    }

    DeliveryChallanResponse toResponse(DeliveryChallan challan) {
        String contactName = contactRepository.findById(challan.getContactId())
                .map(Contact::getCompanyName).orElse(null);

        String warehouseName = challan.getWarehouseId() != null
                ? warehouseRepository.findById(challan.getWarehouseId())
                .map(Warehouse::getName).orElse(null)
                : null;

        String soNumber = salesOrderRepository.findById(challan.getSalesOrderId())
                .map(SalesOrder::getSalesorderNumber).orElse(null);

        List<DeliveryChallanLineResponse> lineResponses = challan.getLines().stream()
                .map(l -> {
                    String itemName = l.getItemId() != null
                            ? itemRepository.findById(l.getItemId()).map(Item::getName).orElse(null)
                            : null;
                    String batchNumber = l.getBatchId() != null
                            ? batchRepository.findById(l.getBatchId())
                            .map(b -> b.getBatchNumber()).orElse(null)
                            : null;
                    return new DeliveryChallanLineResponse(
                            l.getId(), l.getSalesOrderLineId(), l.getLineNumber(),
                            l.getItemId(), itemName, l.getDescription(),
                            l.getQuantity(), l.getUnit(), l.getBatchId(), batchNumber);
                }).toList();

        return new DeliveryChallanResponse(
                challan.getId(), challan.getChallanNumber(),
                challan.getSalesOrderId(), soNumber,
                challan.getContactId(), contactName,
                challan.getChallanDate(), challan.getStatus(),
                challan.getDispatchDate(),
                challan.getWarehouseId(), warehouseName,
                challan.getDeliveryMethod(), challan.getVehicleNumber(),
                challan.getTrackingNumber(), challan.getNotes(),
                challan.getShippingAddress(),
                lineResponses, challan.getCreatedAt());
    }
}
