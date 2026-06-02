package com.katasticho.erp.sales.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.ar.dto.CreateInvoiceRequest;
import com.katasticho.erp.ar.dto.InvoiceLineRequest;
import com.katasticho.erp.ar.dto.InvoiceResponse;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.entity.InvoiceNumberSequence;
import com.katasticho.erp.ar.service.InvoiceService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.policy.CreditPolicy;
import com.katasticho.erp.common.policy.OverduePolicy;
import com.katasticho.erp.common.policy.PolicyResolverService;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.workflow.ApprovalWorkflowService;
import com.katasticho.erp.common.workflow.WorkflowDefinition;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.estimate.entity.Estimate;
import com.katasticho.erp.estimate.entity.EstimateLine;
import com.katasticho.erp.estimate.repository.EstimateRepository;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.organisation.BranchRepository;
import com.katasticho.erp.organisation.Branch;
import com.katasticho.erp.pricing.service.PriceListService;
import com.katasticho.erp.sales.dto.*;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.entity.SalesOrderLine;
import com.katasticho.erp.sales.entity.StockReservation;
import com.katasticho.erp.sales.repository.DeliveryChallanRepository;
import com.katasticho.erp.sales.repository.SalesOrderLineRepository;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import com.katasticho.erp.sales.repository.StockReservationRepository;
import com.katasticho.erp.tax.GenericTaxEngine;
import com.katasticho.erp.tax.TaxEngine.TaxCalculationResult;
import com.katasticho.erp.tax.TaxEngine.TransactionType;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class SalesOrderService {

    private final SalesOrderRepository salesOrderRepository;
    private final SalesOrderLineRepository soLineRepository;
    private final StockReservationRepository reservationRepository;
    private final ContactRepository contactRepository;
    private final ItemRepository itemRepository;
    private final WarehouseRepository warehouseRepository;
    private final StockBalanceRepository stockBalanceRepository;
    private final BranchRepository branchRepository;
    private final EstimateRepository estimateRepository;
    private final InvoiceService invoiceService;
    private final InvoiceRepository invoiceRepository;
    private final InvoiceNumberSequenceRepository sequenceRepository;
    private final DefaultAccountService defaultAccountService;
    private final GenericTaxEngine taxEngine;
    private final CommentService commentService;
    private final DeliveryChallanRepository challanRepository;
    private final PolicyResolverService policyResolverService;
    private final ApprovalWorkflowService approvalWorkflowService;
    private final PriceListService priceListService;

    // ── CREATE ──────────────────────────────────────────────────

    @Transactional
    public SalesOrderResponse create(CreateSalesOrderRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(request.contactId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", request.contactId()));
        validateContactType(contact);

        UUID branchId = branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .map(Branch::getId).orElse(null);

        int year = LocalDate.now().getYear();
        String soNumber = generateNumber(orgId, "SO", year);

        LocalDate orderDate = request.orderDate() != null ? request.orderDate() : LocalDate.now();

        SalesOrder so = SalesOrder.builder()
                .branchId(branchId)
                .salesorderNumber(soNumber)
                .referenceNumber(request.referenceNumber())
                .contactId(contact.getId())
                .orderDate(orderDate)
                .expectedShipmentDate(request.expectedShipmentDate())
                .discountType(request.discountType() != null ? request.discountType() : "ITEM_LEVEL")
                .deliveryMethod(request.deliveryMethod())
                .placeOfSupply(request.placeOfSupply())
                .notes(request.notes())
                .terms(request.terms())
                .billingAddress(request.billingAddress())
                .shippingAddress(request.shippingAddress())
                .allowBackorder(request.allowBackorder() != null && request.allowBackorder())
                .build();

        BigDecimal subtotal = BigDecimal.ZERO;
        BigDecimal totalTax = BigDecimal.ZERO;

        int lineNum = 1;
        for (SalesOrderLineRequest lr : request.lines()) {
            UUID itemId = lr.itemId();

            // Auto-create inventory item when none is linked
            if (itemId == null && lr.description() != null && !lr.description().isBlank()) {
                itemId = autoCreateItem(orgId, lr);
            }

            UUID resolvedItemId = itemId;
            BigDecimal effectiveRate = lr.rate();
            if (resolvedItemId != null) {
                effectiveRate = priceListService
                        .resolvePrice(contact.getId(), resolvedItemId, lr.quantity())
                        .map(resolved -> {
                            if (resolved.compareTo(lr.rate()) != 0) {
                                log.info("Sales order price list override item={}: client={} resolved={}",
                                        resolvedItemId, lr.rate(), resolved);
                            }
                            return resolved;
                        })
                        .orElse(lr.rate());
            }

            BigDecimal lineAmount = lr.quantity().multiply(effectiveRate);
            BigDecimal discountPct = lr.discountPct() != null ? lr.discountPct() : BigDecimal.ZERO;
            if (discountPct.compareTo(BigDecimal.ZERO) > 0) {
                lineAmount = lineAmount.multiply(BigDecimal.ONE.subtract(discountPct.divide(BigDecimal.valueOf(100), 4, RoundingMode.HALF_UP)))
                        .setScale(2, RoundingMode.HALF_UP);
            }

            BigDecimal taxRate = BigDecimal.ZERO;
            if (lr.taxGroupId() != null) {
                TaxCalculationResult taxResult = taxEngine.calculate(orgId, lr.taxGroupId(), lineAmount, TransactionType.SALE);
                taxRate = taxResult.totalTaxAmount().multiply(BigDecimal.valueOf(100))
                        .divide(lineAmount.compareTo(BigDecimal.ZERO) == 0 ? BigDecimal.ONE : lineAmount, 2, RoundingMode.HALF_UP);
                totalTax = totalTax.add(taxResult.totalTaxAmount());
            }

            subtotal = subtotal.add(lineAmount);

            SalesOrderLine line = SalesOrderLine.builder()
                    .lineNumber(lineNum++)
                    .itemId(itemId)
                    .description(lr.description())
                    .quantity(lr.quantity())
                    .unit(lr.unit())
                    .rate(effectiveRate)
                    .discountPct(discountPct)
                    .taxGroupId(lr.taxGroupId())
                    .taxRate(taxRate)
                    .hsnCode(lr.hsnCode())
                    .amount(lineAmount)
                    .build();
            so.addLine(line);
        }

        BigDecimal entityDiscount = BigDecimal.ZERO;
        if ("ENTITY_LEVEL".equals(so.getDiscountType()) && request.discountAmount() != null) {
            entityDiscount = request.discountAmount();
            subtotal = subtotal.subtract(entityDiscount);
        }

        BigDecimal shippingCharge = request.shippingCharge() != null ? request.shippingCharge() : BigDecimal.ZERO;
        BigDecimal adjustment = request.adjustment() != null ? request.adjustment() : BigDecimal.ZERO;

        so.setDiscountAmount(entityDiscount);
        so.setSubtotal(subtotal);
        so.setTaxAmount(totalTax);
        so.setShippingCharge(shippingCharge);
        so.setAdjustment(adjustment);
        so.setAdjustmentDescription(request.adjustmentDescription());
        so.setTotal(subtotal.add(totalTax).add(shippingCharge).add(adjustment));

        SalesOrderRiskDecision creditLimitDecision = evaluateCreditLimit(orgId, contact, so.getTotal());
        SalesOrderRiskDecision overdueDecision = evaluateOverdueInvoices(orgId, contact);
        SalesOrderRiskDecision approvalDecision = creditLimitDecision.requiresApproval()
                ? creditLimitDecision
                : overdueDecision.requiresApproval() ? overdueDecision : SalesOrderRiskDecision.none();
        if (approvalDecision.requiresApproval()) {
            so.setStatus("PENDING_APPROVAL");
        }

        so = salesOrderRepository.save(so);
        commentService.addSystemComment("SALES_ORDER", so.getId(), "Sales order created");
        if (creditLimitDecision.warningMessage() != null) {
            commentService.addSystemComment("SALES_ORDER", so.getId(), creditLimitDecision.warningMessage());
        }
        if (overdueDecision.warningMessage() != null) {
            commentService.addSystemComment("SALES_ORDER", so.getId(), overdueDecision.warningMessage());
        }
        if (approvalDecision.requiresApproval()) {
            approvalWorkflowService.requestApproval(
                    orgId,
                    approvalDecision.workflow(),
                    "SALES_ORDER",
                    so.getId(),
                    approvalDecision.warningMessage(),
                    approvalDecision.context());
            commentService.addSystemComment("SALES_ORDER", so.getId(),
                    "Sales order is pending approval: " + approvalDecision.warningMessage());
        }

        log.info("Sales order created: {} for contact {}", soNumber, contact.getId());
        String name = contact.getCompanyName() != null ? contact.getCompanyName() : contact.getDisplayName();
        return toResponse(so, name);
    }

    // ── CREATE FROM ESTIMATE ────────────────────────────────────

    @Transactional
    public SalesOrderResponse createFromEstimate(UUID estimateId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Estimate estimate = estimateRepository.findByIdAndOrgIdAndIsDeletedFalse(estimateId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Estimate", estimateId));

        if (!"ACCEPTED".equals(estimate.getStatus())) {
            throw new BusinessException("Only ACCEPTED estimates can be converted to sales orders",
                    "SO_ESTIMATE_NOT_ACCEPTED", HttpStatus.BAD_REQUEST);
        }

        List<SalesOrderLineRequest> lineRequests = estimate.getLines().stream()
                .map(el -> new SalesOrderLineRequest(
                        el.getItemId(), el.getDescription(), el.getQuantity(), el.getRate(),
                        el.getUnit(), el.getDiscountPct(), null, el.getHsnCode()))
                .toList();

        CreateSalesOrderRequest soRequest = new CreateSalesOrderRequest(
                estimate.getContactId(), lineRequests,
                LocalDate.now(), null, estimate.getReferenceNumber(),
                null, null, null, null, null,
                null, null, estimate.getNotes(), estimate.getTerms(),
                null, null, null);

        SalesOrderResponse response = create(soRequest);

        SalesOrder so = salesOrderRepository.findById(response.id()).orElseThrow();
        so.setEstimateId(estimateId);
        salesOrderRepository.save(so);

        commentService.addSystemComment("ESTIMATE", estimateId,
                "Converted to Sales Order " + response.salesOrderNumber());

        return toResponse(so, response.contactName());
    }

    // ── CONFIRM (reserves stock, supports backorder) ────────────

    @Transactional
    public SalesOrderResponse confirm(UUID soId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        SalesOrder so = findOrThrow(soId, orgId);
        if (!"DRAFT".equals(so.getStatus())) {
            throw new BusinessException("Only DRAFT sales orders can be confirmed",
                    "SO_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        Warehouse warehouse = warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .orElseThrow(() -> new BusinessException("No default warehouse configured",
                        "SO_NO_WAREHOUSE", HttpStatus.BAD_REQUEST));

        boolean hasBackorder = false;
        int reservedCount = 0;

        for (SalesOrderLine line : so.getLines()) {
            if (line.getItemId() == null) continue;

            Item item = itemRepository.findById(line.getItemId()).orElse(null);
            if (item == null || !item.isTrackInventory()) continue;

            StockBalance balance = stockBalanceRepository
                    .findByOrgIdAndItemIdAndWarehouseId(orgId, line.getItemId(), warehouse.getId())
                    .orElse(null);

            BigDecimal currentQty = balance != null ? balance.getQuantityOnHand() : BigDecimal.ZERO;
            BigDecimal reservedQty = reservationRepository.sumActiveReservations(line.getItemId(), warehouse.getId());
            BigDecimal availableQty = currentQty.subtract(reservedQty);

            if (!so.isAllowBackorder() && line.getQuantity().compareTo(availableQty) > 0) {
                throw new BusinessException(
                        String.format("Insufficient stock for %s: Available %.2f, Requested %.2f",
                                item.getName(), availableQty, line.getQuantity()),
                        "SO_INSUFFICIENT_STOCK", HttpStatus.BAD_REQUEST);
            }

            // Reserve as much as is available (capped to requested qty)
            BigDecimal toReserve = so.isAllowBackorder()
                    ? availableQty.max(BigDecimal.ZERO).min(line.getQuantity())
                    : line.getQuantity();
            BigDecimal backordered = line.getQuantity().subtract(toReserve);

            line.setQuantityBackordered(backordered);

            if (backordered.compareTo(BigDecimal.ZERO) > 0) {
                hasBackorder = true;
            }

            if (toReserve.compareTo(BigDecimal.ZERO) > 0) {
                StockReservation reservation = StockReservation.builder()
                        .orgId(orgId)
                        .itemId(line.getItemId())
                        .warehouseId(warehouse.getId())
                        .sourceType("SALES_ORDER")
                        .sourceId(so.getId())
                        .sourceLineId(line.getId())
                        .quantityReserved(toReserve)
                        .build();
                reservationRepository.save(reservation);
                reservedCount++;
            }
        }

        so.setStatus(hasBackorder ? "BACKORDER" : "CONFIRMED");
        so = salesOrderRepository.save(so);

        String comment = hasBackorder
                ? "Confirmed with backorder — " + reservedCount + " item(s) partially/fully reserved; remaining quantity awaiting stock."
                : "Confirmed. Stock reserved for " + reservedCount + " items.";
        commentService.addSystemComment("SALES_ORDER", so.getId(), comment);

        log.info("Sales order {} confirmed — status={}, backorder={}",
                so.getSalesorderNumber(), so.getStatus(), hasBackorder);
        return toResponseWithContactLookup(so);
    }

    // ── CLOSE BACKORDER LINES ────────────────────────────────────

    /**
     * Permanently closes specific backorder lines — sets quantityBackordered = 0,
     * releases any partial reservation, and promotes the SO to CONFIRMED if all
     * remaining backorder lines are now closed.
     * Use case: medicine cannot be sourced from any vendor; customer will buy elsewhere.
     */
    @Transactional
    public SalesOrderResponse closeBackorderLines(UUID soId, CloseBackorderLinesRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SalesOrder so = findOrThrow(soId, orgId);

        if (!"BACKORDER".equals(so.getStatus())) {
            throw new BusinessException("Only BACKORDER sales orders can have lines closed",
                    "SO_NOT_BACKORDER", HttpStatus.BAD_REQUEST);
        }

        StringBuilder closedNames = new StringBuilder();
        for (UUID lineId : request.lineIds()) {
            SalesOrderLine line = so.getLines().stream()
                    .filter(l -> l.getId().equals(lineId))
                    .findFirst()
                    .orElseThrow(() -> new BusinessException(
                            "SO line not found: " + lineId, "SO_LINE_NOT_FOUND", HttpStatus.BAD_REQUEST));

            if (line.getQuantityBackordered().compareTo(BigDecimal.ZERO) <= 0) continue;

            // Release any existing reservation for this line
            reservationRepository.findBySourceTypeAndSourceLineIdAndStatus("SALES_ORDER", lineId, "ACTIVE")
                    .ifPresent(r -> {
                        r.setStatus("CANCELLED");
                        r.setCancelledAt(Instant.now());
                        reservationRepository.save(r);
                    });

            line.setQuantityBackordered(BigDecimal.ZERO);
            soLineRepository.save(line);

            if (!closedNames.isEmpty()) closedNames.append(", ");
            closedNames.append(line.getDescription() != null ? line.getDescription() : lineId.toString());
        }

        boolean allFulfilled = so.getLines().stream()
                .allMatch(l -> l.getQuantityBackordered().compareTo(BigDecimal.ZERO) == 0);

        if (allFulfilled) {
            so.setStatus("CONFIRMED");
            salesOrderRepository.save(so);
        }

        String reason = request.reason() != null ? " — Reason: " + request.reason() : "";
        commentService.addSystemComment("SALES_ORDER", so.getId(),
                "Backorder lines closed for: " + closedNames + reason);

        log.info("SO {} backorder lines closed: {}", so.getSalesorderNumber(), closedNames);
        return toResponseWithContactLookup(so);
    }

    // ── CANCEL ──────────────────────────────────────────────────

    @Transactional
    public SalesOrderResponse cancel(UUID soId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SalesOrder so = findOrThrow(soId, orgId);

        if (!"DRAFT".equals(so.getStatus()) && !"CONFIRMED".equals(so.getStatus())
                && !"BACKORDER".equals(so.getStatus())) {
            throw new BusinessException("Only DRAFT, CONFIRMED, or BACKORDER orders can be cancelled",
                    "SO_CANNOT_CANCEL", HttpStatus.BAD_REQUEST);
        }

        if ("CONFIRMED".equals(so.getStatus()) || "BACKORDER".equals(so.getStatus())) {
            List<StockReservation> reservations = reservationRepository
                    .findBySourceTypeAndSourceId("SALES_ORDER", so.getId());
            for (StockReservation r : reservations) {
                if ("ACTIVE".equals(r.getStatus())) {
                    r.setStatus("CANCELLED");
                    r.setCancelledAt(Instant.now());
                    reservationRepository.save(r);
                }
            }
            // Clear any pending backorder quantities on lines
            for (SalesOrderLine line : so.getLines()) {
                line.setQuantityBackordered(BigDecimal.ZERO);
            }
        }

        so.setStatus("CANCELLED");
        so = salesOrderRepository.save(so);

        commentService.addSystemComment("SALES_ORDER", so.getId(),
                "Cancelled. Stock reservations released.");

        log.info("Sales order {} cancelled", so.getSalesorderNumber());
        return toResponseWithContactLookup(so);
    }

    // ── CONVERT TO INVOICE ──────────────────────────────────────

    @Transactional
    public InvoiceResponse convertToInvoice(UUID soId, ConvertToInvoiceRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SalesOrder so = findOrThrow(soId, orgId);

        String status = so.getStatus();
        if (!"CONFIRMED".equals(status) && !"PARTIALLY_SHIPPED".equals(status)
                && !"SHIPPED".equals(status) && !"PARTIALLY_INVOICED".equals(status)
                && !"BACKORDER".equals(status)) {
            throw new BusinessException("Sales order is not in a state that allows invoicing",
                    "SO_CANNOT_INVOICE", HttpStatus.BAD_REQUEST);
        }

        String revenueAccountCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.SALES_REVENUE);

        List<InvoiceLineRequest> invoiceLines = new ArrayList<>();

        for (ConvertToInvoiceRequest.InvoiceLineItem item : request.lines()) {
            SalesOrderLine soLine = so.getLines().stream()
                    .filter(l -> l.getId().equals(item.soLineId()))
                    .findFirst()
                    .orElseThrow(() -> new BusinessException(
                            "SO line not found: " + item.soLineId(),
                            "SO_LINE_NOT_FOUND", HttpStatus.BAD_REQUEST));

            BigDecimal remainingInvoiceable = soLine.getQuantityShipped().subtract(soLine.getQuantityInvoiced());
            if (item.quantity().compareTo(remainingInvoiceable) > 0) {
                String itemName = soLine.getDescription() != null ? soLine.getDescription() : soLine.getItemId().toString();
                throw new BusinessException(
                        String.format("Cannot invoice more than shipped for %s: Shipped=%.2f, Already Invoiced=%.2f, Requesting=%.2f",
                                itemName, soLine.getQuantityShipped(), soLine.getQuantityInvoiced(), item.quantity()),
                        "SO_INVOICE_EXCEEDS_SHIPPED", HttpStatus.BAD_REQUEST);
            }

            soLine.setQuantityInvoiced(soLine.getQuantityInvoiced().add(item.quantity()));

            invoiceLines.add(new InvoiceLineRequest(
                    soLine.getDescription(),
                    soLine.getHsnCode(),
                    item.quantity(),
                    soLine.getRate(),
                    soLine.getDiscountPct(),
                    soLine.getTaxRate(),
                    revenueAccountCode,
                    soLine.getItemId(),
                    null,
                    soLine.getTaxGroupId()));
        }

        CreateInvoiceRequest invoiceRequest = new CreateInvoiceRequest(
                so.getContactId(),
                so.getOrderDate(),
                null,
                so.getPlaceOfSupply(),
                false,
                so.getNotes(),
                so.getTerms(),
                invoiceLines);

        InvoiceResponse invoiceResponse = invoiceService.createInvoiceFromSalesOrder(invoiceRequest);

        Invoice invoice = invoiceRepository.findById(invoiceResponse.id()).orElseThrow();
        invoice.setSalesOrderId(so.getId());
        invoiceRepository.save(invoice);

        // Post the invoice — skip stock movement since stock was deducted on challan dispatch
        invoiceService.sendInvoice(invoice.getId(), true);

        // Update SO invoiced status
        boolean allInvoiced = so.getLines().stream()
                .allMatch(l -> l.getQuantityInvoiced().compareTo(l.getQuantity()) >= 0);
        so.setInvoicedStatus(allInvoiced ? "FULLY_INVOICED" : "PARTIALLY_INVOICED");

        updateDerivedStatus(so);
        salesOrderRepository.save(so);

        commentService.addSystemComment("SALES_ORDER", so.getId(),
                "Invoice " + invoiceResponse.invoiceNumber() + " created");

        log.info("Invoice {} created from SO {}", invoiceResponse.invoiceNumber(), so.getSalesorderNumber());
        return invoiceService.getInvoiceResponse(invoice.getId());
    }

    // ── STATUS DERIVATION ───────────────────────────────────────

    public void updateDerivedStatus(SalesOrder so) {
        String shipped = so.getShippedStatus();
        String invoiced = so.getInvoicedStatus();

        boolean hasBackorder = so.getLines().stream()
                .anyMatch(l -> l.getQuantityBackordered().compareTo(BigDecimal.ZERO) > 0);

        if (hasBackorder) {
            so.setStatus("BACKORDER");
        } else if ("NOT_SHIPPED".equals(shipped) && "NOT_INVOICED".equals(invoiced)) {
            so.setStatus("CONFIRMED");
        } else if ("PARTIALLY_SHIPPED".equals(shipped)) {
            so.setStatus("PARTIALLY_SHIPPED");
        } else if ("FULLY_SHIPPED".equals(shipped) && "NOT_INVOICED".equals(invoiced)) {
            so.setStatus("SHIPPED");
        } else if ("FULLY_SHIPPED".equals(shipped) && "PARTIALLY_INVOICED".equals(invoiced)) {
            so.setStatus("PARTIALLY_INVOICED");
        } else if ("FULLY_SHIPPED".equals(shipped) && "FULLY_INVOICED".equals(invoiced)) {
            so.setStatus("INVOICED");
        }
    }

    // ── UPDATE (DRAFT only) ─────────────────────────────────────

    @Transactional
    public SalesOrderResponse update(UUID soId, UpdateSalesOrderRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SalesOrder so = findOrThrow(soId, orgId);

        if (!"DRAFT".equals(so.getStatus())) {
            throw new BusinessException("Only DRAFT sales orders can be updated",
                    "SO_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        if (request.expectedShipmentDate() != null) so.setExpectedShipmentDate(request.expectedShipmentDate());
        if (request.referenceNumber() != null) so.setReferenceNumber(request.referenceNumber());
        if (request.deliveryMethod() != null) so.setDeliveryMethod(request.deliveryMethod());
        if (request.notes() != null) so.setNotes(request.notes());
        if (request.terms() != null) so.setTerms(request.terms());
        if (request.shippingAddress() != null) so.setShippingAddress(request.shippingAddress());

        so = salesOrderRepository.save(so);
        return toResponseWithContactLookup(so);
    }

    // ── DELETE (DRAFT only) ─────────────────────────────────────

    @Transactional
    public void delete(UUID soId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SalesOrder so = findOrThrow(soId, orgId);

        if (!"DRAFT".equals(so.getStatus())) {
            throw new BusinessException("Only DRAFT sales orders can be deleted",
                    "SO_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        so.setDeleted(true);
        salesOrderRepository.save(so);
        log.info("Sales order {} soft-deleted", so.getSalesorderNumber());
    }

    // ── GET ─────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public SalesOrderResponse get(UUID soId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SalesOrder so = findOrThrow(soId, orgId);
        return toResponseWithContactLookup(so);
    }

    // ── LIST ────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public Page<SalesOrderResponse> list(String status, UUID contactId, UUID branchId, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Page<SalesOrder> page;
        if (status != null) {
            page = salesOrderRepository.findByOrgIdAndStatusAndIsDeletedFalse(orgId, status, pageable);
        } else if (contactId != null) {
            page = salesOrderRepository.findByOrgIdAndContactIdAndIsDeletedFalse(orgId, contactId, pageable);
        } else if (branchId != null) {
            page = salesOrderRepository.findByOrgIdAndBranchIdAndIsDeletedFalse(orgId, branchId, pageable);
        } else {
            page = salesOrderRepository.findByOrgIdAndIsDeletedFalseOrderByOrderDateDesc(orgId, pageable);
        }

        return page.map(so -> {
            String contactName = contactRepository.findById(so.getContactId())
                    .map(c -> c.getCompanyName() != null ? c.getCompanyName() : c.getDisplayName())
                    .orElse(null);
            return toResponse(so, contactName);
        });
    }

    // ── RESERVATIONS ────────────────────────────────────────────

    public List<StockReservationResponse> getReservations(UUID soId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        findOrThrow(soId, orgId);

        List<StockReservation> reservations = reservationRepository
                .findBySourceTypeAndSourceId("SALES_ORDER", soId);

        return reservations.stream().map(r -> {
            String itemName = itemRepository.findById(r.getItemId())
                    .map(Item::getName).orElse(null);
            String warehouseName = warehouseRepository.findById(r.getWarehouseId())
                    .map(Warehouse::getName).orElse(null);
            return new StockReservationResponse(
                    r.getId(), r.getItemId(), itemName, r.getWarehouseId(), warehouseName,
                    r.getQuantityReserved(), r.getStatus(), r.getReservedAt());
        }).toList();
    }

    // ── LINKED INVOICES ─────────────────────────────────────────

    public List<InvoiceResponse> getLinkedInvoices(UUID soId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        findOrThrow(soId, orgId);
        List<Invoice> invoices = invoiceRepository.findBySalesOrderIdAndOrgId(soId, orgId);
        return invoices.stream().map(invoiceService::toResponse).toList();
    }

    // ── BACKORDER AUTO-FULFILLMENT ──────────────────────────────

    /**
     * Called by StockReceiptService.receive() after each GRN line is posted.
     * Finds BACKORDER SOs waiting for this item (FIFO) and creates or top-ups
     * their stock reservations using newly available stock.
     * When all lines on a SO reach quantityBackordered = 0, the SO is
     * promoted from BACKORDER → CONFIRMED automatically.
     */
    @Transactional
    public void onStockReceived(UUID orgId, UUID itemId, UUID warehouseId) {
        List<SalesOrderLine> backorderLines = soLineRepository.findBackorderedLinesForItem(orgId, itemId);
        if (backorderLines.isEmpty()) return;

        Set<UUID> updatedSoIds = new HashSet<>();

        for (SalesOrderLine line : backorderLines) {
            BigDecimal onHand = stockBalanceRepository
                    .findByOrgIdAndItemIdAndWarehouseId(orgId, itemId, warehouseId)
                    .map(StockBalance::getQuantityOnHand)
                    .orElse(BigDecimal.ZERO);
            BigDecimal alreadyReserved = reservationRepository.sumActiveReservations(itemId, warehouseId);
            BigDecimal available = onHand.subtract(alreadyReserved);

            if (available.compareTo(BigDecimal.ZERO) <= 0) break; // no free stock left

            BigDecimal toFulfill = available.min(line.getQuantityBackordered());
            if (toFulfill.compareTo(BigDecimal.ZERO) <= 0) continue;

            // Update existing reservation if one exists, otherwise create it
            Optional<StockReservation> existing = reservationRepository
                    .findBySourceTypeAndSourceLineIdAndStatus("SALES_ORDER", line.getId(), "ACTIVE");

            if (existing.isPresent()) {
                StockReservation r = existing.get();
                r.setQuantityReserved(r.getQuantityReserved().add(toFulfill));
                reservationRepository.save(r);
            } else {
                reservationRepository.save(StockReservation.builder()
                        .orgId(orgId)
                        .itemId(itemId)
                        .warehouseId(warehouseId)
                        .sourceType("SALES_ORDER")
                        .sourceId(line.getSalesOrder().getId())
                        .sourceLineId(line.getId())
                        .quantityReserved(toFulfill)
                        .build());
            }

            line.setQuantityBackordered(line.getQuantityBackordered().subtract(toFulfill));
            soLineRepository.save(line);

            updatedSoIds.add(line.getSalesOrder().getId());
        }

        // Promote any fully-fulfilled BACKORDER SOs to CONFIRMED
        for (UUID affectedSoId : updatedSoIds) {
            SalesOrder so = salesOrderRepository.findById(affectedSoId).orElse(null);
            if (so == null || !"BACKORDER".equals(so.getStatus())) continue;

            boolean allFulfilled = so.getLines().stream()
                    .allMatch(l -> l.getQuantityBackordered().compareTo(BigDecimal.ZERO) == 0);

            if (allFulfilled) {
                so.setStatus("CONFIRMED");
                salesOrderRepository.save(so);
                commentService.addSystemComment("SALES_ORDER", so.getId(),
                        "All backordered items are now in stock — order confirmed");
                log.info("SO {} backorder fully fulfilled → CONFIRMED", so.getSalesorderNumber());
            }
        }
    }

    // ── AUTO-CREATE ITEM ──────────────────────────────────────────

    private UUID autoCreateItem(UUID orgId, SalesOrderLineRequest lr) {
        String name = lr.description().trim();

        // Reuse an existing item with the same name to avoid UUID mismatches
        // between the SO line and the item a user later picks in a GRN.
        var existing = itemRepository.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, name);
        if (existing.isPresent()) {
            log.info("Reusing existing item '{}' (id={}) from catalog for SO line", name, existing.get().getId());
            return existing.get().getId();
        }

        String sku = "AUTO-" + System.currentTimeMillis() + "-" + (int) (Math.random() * 9000 + 1000);
        String unit = lr.unit() != null ? lr.unit() : "PCS";

        Item item = Item.builder()
                .sku(sku)
                .name(name)
                .hsnCode(lr.hsnCode())
                .unitOfMeasure(unit)
                .salePrice(lr.rate() != null ? lr.rate() : BigDecimal.ZERO)
                .trackInventory(true)
                .build();
        item.setOrgId(orgId);

        if (lr.taxGroupId() != null) {
            item.setDefaultTaxGroupId(lr.taxGroupId());
        }

        item = itemRepository.save(item);
        log.info("Auto-created item '{}' (SKU={}) from sales order line", name, sku);
        return item.getId();
    }

    // ── HELPERS ─────────────────────────────────────────────────

    private SalesOrder findOrThrow(UUID soId, UUID orgId) {
        return salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Sales Order", soId));
    }

    private void validateContactType(Contact contact) {
        if (!contact.isActive()) {
            throw new BusinessException("Cannot create sales order for an inactive contact",
                    "SO_CONTACT_INACTIVE", HttpStatus.BAD_REQUEST);
        }
        if (contact.isSalesHold()
                && (contact.getSalesHoldUntil() == null || !contact.getSalesHoldUntil().isBefore(LocalDate.now()))) {
            String reason = contact.getSalesHoldReason() != null && !contact.getSalesHoldReason().isBlank()
                    ? ": " + contact.getSalesHoldReason()
                    : "";
            throw new BusinessException("Customer is on sales hold" + reason,
                    "SO_CONTACT_SALES_HOLD", HttpStatus.BAD_REQUEST);
        }

        String type = contact.getContactType().name();
        if ("VENDOR".equals(type)) {
            throw new BusinessException("Cannot create sales order for a vendor-only contact",
                    "SO_INVALID_CONTACT_TYPE", HttpStatus.BAD_REQUEST);
        }
    }

    private String generateNumber(UUID orgId, String prefix, int year) {
        var seqId = new InvoiceNumberSequence.InvoiceNumberSequenceId(orgId, prefix, year);
        var seqOpt = sequenceRepository.findByOrgIdAndPrefixAndYear(orgId, prefix, year);
        long nextVal;
        if (seqOpt.isPresent()) {
            nextVal = seqOpt.get().getNextValue();
            sequenceRepository.incrementAndGet(orgId, prefix, year);
        } else {
            sequenceRepository.save(InvoiceNumberSequence.builder()
                    .id(seqId).nextValue(2L).build());
            nextVal = 1L;
        }
        return String.format("%s-%d-%06d", prefix, year, nextVal);
    }

    private SalesOrderRiskDecision evaluateCreditLimit(UUID orgId, Contact contact, BigDecimal orderTotal) {
        BigDecimal creditLimit = nonNull(contact.getCreditLimit());
        if (creditLimit.compareTo(BigDecimal.ZERO) <= 0) {
            return SalesOrderRiskDecision.none();
        }

        BigDecimal outstandingAr = nonNull(contact.getOutstandingAr());
        BigDecimal exposure = outstandingAr.add(nonNull(orderTotal));
        if (exposure.compareTo(creditLimit) <= 0) {
            return SalesOrderRiskDecision.none();
        }

        String contactName = contact.getCompanyName() != null ? contact.getCompanyName() : contact.getDisplayName();
        String message = String.format(
                "Credit limit exceeded for %s: outstanding %s + order %s = exposure %s, limit %s",
                contactName != null ? contactName : contact.getId(),
                outstandingAr, nonNull(orderTotal), exposure, creditLimit);

        Map<String, Object> context = Map.of(
                "credit.outstandingAr", outstandingAr,
                "credit.orderTotal", nonNull(orderTotal),
                "credit.exposureAmount", exposure,
                "credit.creditLimit", creditLimit,
                "contact.id", contact.getId().toString());

        Optional<WorkflowDefinition> workflow = approvalWorkflowService
                .findMatchingWorkflow(orgId, "SALES_ORDER", context);
        if (workflow.isPresent()) {
            return SalesOrderRiskDecision.approval(message, workflow.get(), context);
        }

        CreditPolicy policy = policyResolverService.creditPolicy(orgId);
        if (policy == CreditPolicy.BLOCK) {
            throw new BusinessException(message, "SO_CREDIT_LIMIT_EXCEEDED", HttpStatus.BAD_REQUEST);
        }
        if (policy == CreditPolicy.APPROVAL_REQUIRED) {
            throw new BusinessException(
                    "Credit approval workflow is not active for this organisation",
                    "SO_CREDIT_APPROVAL_WORKFLOW_MISSING",
                    HttpStatus.BAD_REQUEST);
        }

        return SalesOrderRiskDecision.warning(message);
    }

    private SalesOrderRiskDecision evaluateOverdueInvoices(UUID orgId, Contact contact) {
        int graceDays = policyResolverService.overdueGraceDays(orgId);
        LocalDate cutoffDate = LocalDate.now().minusDays(graceDays);
        List<Invoice> overdueInvoices = invoiceRepository.findOutstandingByContact(orgId, contact.getId()).stream()
                .filter(invoice -> invoice.getDueDate() != null && invoice.getDueDate().isBefore(cutoffDate))
                .toList();

        if (overdueInvoices.isEmpty()) {
            return SalesOrderRiskDecision.none();
        }

        BigDecimal overdueAmount = overdueInvoices.stream()
                .map(Invoice::getBalanceDue)
                .map(this::nonNull)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        LocalDate oldestDueDate = overdueInvoices.stream()
                .map(Invoice::getDueDate)
                .min(LocalDate::compareTo)
                .orElse(null);

        String contactName = contact.getCompanyName() != null ? contact.getCompanyName() : contact.getDisplayName();
        String message = String.format(
                "Customer %s has %d overdue invoice(s), amount %s, oldest due date %s",
                contactName != null ? contactName : contact.getId(),
                overdueInvoices.size(),
                overdueAmount,
                oldestDueDate);

        Map<String, Object> context = Map.of(
                "overdue.count", overdueInvoices.size(),
                "overdue.amount", overdueAmount,
                "overdue.oldestDueDate", oldestDueDate != null ? oldestDueDate.toString() : "",
                "overdue.graceDays", graceDays,
                "contact.id", contact.getId().toString());

        Optional<WorkflowDefinition> workflow = approvalWorkflowService
                .findMatchingWorkflow(orgId, "SALES_ORDER", context);
        if (workflow.isPresent()) {
            return SalesOrderRiskDecision.approval(message, workflow.get(), context);
        }

        OverduePolicy policy = policyResolverService.overduePolicy(orgId);
        if (policy == OverduePolicy.BLOCK) {
            throw new BusinessException(message, "SO_OVERDUE_INVOICES", HttpStatus.BAD_REQUEST);
        }
        if (policy == OverduePolicy.APPROVAL_REQUIRED) {
            throw new BusinessException(
                    "Overdue invoice approval workflow is not active for this organisation",
                    "SO_OVERDUE_APPROVAL_WORKFLOW_MISSING",
                    HttpStatus.BAD_REQUEST);
        }

        return SalesOrderRiskDecision.warning(message);
    }

    private BigDecimal nonNull(BigDecimal value) {
        return value != null ? value : BigDecimal.ZERO;
    }

    private SalesOrderResponse toResponseWithContactLookup(SalesOrder so) {
        String contactName = contactRepository.findById(so.getContactId())
                .map(c -> c.getCompanyName() != null ? c.getCompanyName() : c.getDisplayName())
                .orElse(null);
        return toResponse(so, contactName);
    }

    SalesOrderResponse toResponse(SalesOrder so, String contactName) {
        List<SalesOrderLineResponse> lineResponses = so.getLines().stream()
                .map(l -> {
                    String itemName = l.getItemId() != null
                            ? itemRepository.findById(l.getItemId()).map(Item::getName).orElse(null)
                            : null;
                    return new SalesOrderLineResponse(
                            l.getId(), l.getLineNumber(), l.getItemId(), itemName,
                            l.getDescription(), l.getQuantity(), l.getQuantityShipped(),
                            l.getQuantityInvoiced(), l.getQuantityBackordered(),
                            l.getUnit(), l.getRate(),
                            l.getDiscountPct(), l.getTaxGroupId(), l.getTaxRate(),
                            l.getHsnCode(), l.getAmount());
                }).toList();

        int invoiceCount = invoiceRepository.countBySalesOrderId(so.getId());

        return new SalesOrderResponse(
                so.getId(), so.getSalesorderNumber(),
                so.getContactId(), contactName,
                so.getOrderDate(), so.getExpectedShipmentDate(),
                so.getReferenceNumber(),
                so.getStatus(), so.getShippedStatus(), so.getInvoicedStatus(),
                so.getEstimateId(), so.getBranchId(), so.getCurrency(),
                so.getDiscountType(), so.getDiscountAmount(),
                so.getSubtotal(), so.getTaxAmount(), so.getShippingCharge(),
                so.getAdjustment(), so.getAdjustmentDescription(), so.getTotal(),
                so.getDeliveryMethod(), so.getPlaceOfSupply(),
                so.getNotes(), so.getTerms(),
                so.getBillingAddress(), so.getShippingAddress(),
                lineResponses,
                invoiceCount, challanRepository.countBySalesOrderIdAndIsDeletedFalse(so.getId()),
                so.isAllowBackorder(),
                so.getCreatedAt());
    }

    private record SalesOrderRiskDecision(
            String warningMessage,
            WorkflowDefinition workflow,
            Map<String, Object> context
    ) {
        static SalesOrderRiskDecision none() {
            return new SalesOrderRiskDecision(null, null, Map.of());
        }

        static SalesOrderRiskDecision warning(String message) {
            return new SalesOrderRiskDecision(message, null, Map.of());
        }

        static SalesOrderRiskDecision approval(String message, WorkflowDefinition workflow, Map<String, Object> context) {
            return new SalesOrderRiskDecision(message, workflow, context);
        }

        boolean requiresApproval() {
            return workflow != null;
        }
    }
}
