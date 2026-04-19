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
import com.katasticho.erp.common.service.CommentService;
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
import com.katasticho.erp.sales.dto.*;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.entity.SalesOrderLine;
import com.katasticho.erp.sales.entity.StockReservation;
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
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class SalesOrderService {

    private final SalesOrderRepository salesOrderRepository;
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
                .build();

        BigDecimal subtotal = BigDecimal.ZERO;
        BigDecimal totalTax = BigDecimal.ZERO;

        int lineNum = 1;
        for (SalesOrderLineRequest lr : request.lines()) {
            BigDecimal lineAmount = lr.quantity().multiply(lr.rate());
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
                    .itemId(lr.itemId())
                    .description(lr.description())
                    .quantity(lr.quantity())
                    .unit(lr.unit())
                    .rate(lr.rate())
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

        so = salesOrderRepository.save(so);
        commentService.addSystemComment("SALES_ORDER", so.getId(), "Sales order created");

        log.info("Sales order created: {} for contact {}", soNumber, contact.getId());
        return toResponse(so, contact.getCompanyName());
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
                null, null);

        SalesOrderResponse response = create(soRequest);

        SalesOrder so = salesOrderRepository.findById(response.id()).orElseThrow();
        so.setEstimateId(estimateId);
        salesOrderRepository.save(so);

        commentService.addSystemComment("ESTIMATE", estimateId,
                "Converted to Sales Order " + response.salesOrderNumber());

        return toResponse(so, response.contactName());
    }

    // ── CONFIRM (reserves stock) ────────────────────────────────

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

            if (line.getQuantity().compareTo(availableQty) > 0) {
                throw new BusinessException(
                        String.format("Insufficient stock for %s: Available %.2f, Requested %.2f",
                                item.getName(), availableQty, line.getQuantity()),
                        "SO_INSUFFICIENT_STOCK", HttpStatus.BAD_REQUEST);
            }

            StockReservation reservation = StockReservation.builder()
                    .orgId(orgId)
                    .itemId(line.getItemId())
                    .warehouseId(warehouse.getId())
                    .sourceType("SALES_ORDER")
                    .sourceId(so.getId())
                    .sourceLineId(line.getId())
                    .quantityReserved(line.getQuantity())
                    .build();
            reservationRepository.save(reservation);
            reservedCount++;
        }

        so.setStatus("CONFIRMED");
        so = salesOrderRepository.save(so);

        commentService.addSystemComment("SALES_ORDER", so.getId(),
                "Confirmed. Stock reserved for " + reservedCount + " items.");

        log.info("Sales order {} confirmed with {} stock reservations", so.getSalesorderNumber(), reservedCount);
        return toResponseWithContactLookup(so);
    }

    // ── CANCEL ──────────────────────────────────────────────────

    @Transactional
    public SalesOrderResponse cancel(UUID soId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SalesOrder so = findOrThrow(soId, orgId);

        if (!"DRAFT".equals(so.getStatus()) && !"CONFIRMED".equals(so.getStatus())) {
            throw new BusinessException("Only DRAFT or CONFIRMED orders can be cancelled",
                    "SO_CANNOT_CANCEL", HttpStatus.BAD_REQUEST);
        }

        if ("CONFIRMED".equals(so.getStatus())) {
            List<StockReservation> reservations = reservationRepository
                    .findBySourceTypeAndSourceId("SALES_ORDER", so.getId());
            for (StockReservation r : reservations) {
                if ("ACTIVE".equals(r.getStatus())) {
                    r.setStatus("CANCELLED");
                    r.setCancelledAt(Instant.now());
                    reservationRepository.save(r);
                }
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
                && !"SHIPPED".equals(status) && !"PARTIALLY_INVOICED".equals(status)) {
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

        InvoiceResponse invoiceResponse = invoiceService.createInvoice(invoiceRequest);

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

        if ("NOT_SHIPPED".equals(shipped) && "NOT_INVOICED".equals(invoiced)) {
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

    public SalesOrderResponse get(UUID soId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SalesOrder so = findOrThrow(soId, orgId);
        return toResponseWithContactLookup(so);
    }

    // ── LIST ────────────────────────────────────────────────────

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
                    .map(Contact::getCompanyName).orElse(null);
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

    // ── HELPERS ─────────────────────────────────────────────────

    private SalesOrder findOrThrow(UUID soId, UUID orgId) {
        return salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Sales Order", soId));
    }

    private void validateContactType(Contact contact) {
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

    private SalesOrderResponse toResponseWithContactLookup(SalesOrder so) {
        String contactName = contactRepository.findById(so.getContactId())
                .map(Contact::getCompanyName).orElse(null);
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
                            l.getQuantityInvoiced(), l.getUnit(), l.getRate(),
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
                invoiceCount, 0,
                so.getCreatedAt());
    }
}
