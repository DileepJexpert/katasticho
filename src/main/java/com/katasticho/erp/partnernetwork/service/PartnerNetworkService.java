package com.katasticho.erp.partnernetwork.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.partnernetwork.dto.*;
import com.katasticho.erp.partnernetwork.entity.*;
import com.katasticho.erp.partnernetwork.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class PartnerNetworkService {

    private final TradingPartnerRepository tradingPartnerRepository;
    private final PublishedCatalogItemRepository catalogRepository;
    private final NetworkOrderRepository networkOrderRepository;
    private final NetworkOrderLineRepository orderLineRepository;
    private final NetworkOrderEventRepository eventRepository;
    private final OrganisationRepository organisationRepository;

    // ══════════════════════════════════════════════════════════════
    // Trading Partners
    // ══════════════════════════════════════════════════════════════

    @Transactional
    public TradingPartner requestPartnership(TradingPartnerRequest request) {
        UUID myOrgId = TenantContext.getCurrentOrgId();
        UUID targetOrgId = request.targetOrgId();

        if (myOrgId.equals(targetOrgId)) {
            throw new BusinessException("Cannot create partnership with own organisation", "PN_SELF_PARTNER", HttpStatus.BAD_REQUEST);
        }

        organisationRepository.findById(targetOrgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", targetOrgId));

        boolean isSeller = "SELLER".equalsIgnoreCase(request.role());
        UUID sellerOrgId = isSeller ? myOrgId : targetOrgId;
        UUID buyerOrgId = isSeller ? targetOrgId : myOrgId;

        tradingPartnerRepository.findBySellerOrgIdAndBuyerOrgIdAndIsDeletedFalse(sellerOrgId, buyerOrgId)
                .ifPresent(existing -> {
                    throw new BusinessException("Partnership already exists with status: " + existing.getStatus(),
                            "PN_DUPLICATE_PARTNER", HttpStatus.CONFLICT);
                });

        TradingPartner tp = TradingPartner.builder()
                .sellerOrgId(sellerOrgId)
                .buyerOrgId(buyerOrgId)
                .status("PENDING")
                .requestedByOrgId(myOrgId)
                .creditLimit(request.creditLimit())
                .paymentTerms(request.paymentTerms())
                .deliveryTerms(request.deliveryTerms())
                .notes(request.notes())
                .build();

        return tradingPartnerRepository.save(tp);
    }

    @Transactional
    public TradingPartner approvePartnership(UUID partnerId) {
        UUID myOrgId = TenantContext.getCurrentOrgId();
        TradingPartner tp = findPartner(partnerId);

        if (tp.getRequestedByOrgId().equals(myOrgId)) {
            throw new BusinessException("Cannot approve own partnership request", "PN_SELF_APPROVE", HttpStatus.BAD_REQUEST);
        }

        if (!tp.getSellerOrgId().equals(myOrgId) && !tp.getBuyerOrgId().equals(myOrgId)) {
            throw new BusinessException("Not part of this partnership", "PN_NOT_PARTY", HttpStatus.FORBIDDEN);
        }

        if (!"PENDING".equals(tp.getStatus())) {
            throw new BusinessException("Partnership is not pending", "PN_NOT_PENDING", HttpStatus.BAD_REQUEST);
        }

        tp.setStatus("APPROVED");
        tp.setApprovedAt(Instant.now());
        return tradingPartnerRepository.save(tp);
    }

    @Transactional
    public TradingPartner rejectPartnership(UUID partnerId) {
        UUID myOrgId = TenantContext.getCurrentOrgId();
        TradingPartner tp = findPartner(partnerId);

        if (!tp.getSellerOrgId().equals(myOrgId) && !tp.getBuyerOrgId().equals(myOrgId)) {
            throw new BusinessException("Not part of this partnership", "PN_NOT_PARTY", HttpStatus.FORBIDDEN);
        }

        if (!"PENDING".equals(tp.getStatus())) {
            throw new BusinessException("Partnership is not pending", "PN_NOT_PENDING", HttpStatus.BAD_REQUEST);
        }

        tp.setStatus("REJECTED");
        return tradingPartnerRepository.save(tp);
    }

    @Transactional
    public TradingPartner suspendPartnership(UUID partnerId) {
        UUID myOrgId = TenantContext.getCurrentOrgId();
        TradingPartner tp = findPartner(partnerId);

        if (!tp.getSellerOrgId().equals(myOrgId) && !tp.getBuyerOrgId().equals(myOrgId)) {
            throw new BusinessException("Not part of this partnership", "PN_NOT_PARTY", HttpStatus.FORBIDDEN);
        }

        if (!"APPROVED".equals(tp.getStatus())) {
            throw new BusinessException("Only approved partnerships can be suspended", "PN_NOT_APPROVED", HttpStatus.BAD_REQUEST);
        }

        tp.setStatus("SUSPENDED");
        return tradingPartnerRepository.save(tp);
    }

    @Transactional(readOnly = true)
    public List<TradingPartnerResponse> getMyPartners() {
        UUID myOrgId = TenantContext.getCurrentOrgId();
        List<TradingPartner> partners = tradingPartnerRepository.findAllByOrgId(myOrgId);
        return partners.stream().map(this::toPartnerResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<TradingPartnerResponse> getPendingRequests() {
        UUID myOrgId = TenantContext.getCurrentOrgId();
        return tradingPartnerRepository.findAllByOrgId(myOrgId).stream()
                .filter(tp -> "PENDING".equals(tp.getStatus()) && !tp.getRequestedByOrgId().equals(myOrgId))
                .map(this::toPartnerResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public TradingPartnerResponse getPartner(UUID partnerId) {
        return toPartnerResponse(findPartner(partnerId));
    }

    // ══════════════════════════════════════════════════════════════
    // Published Catalog
    // ══════════════════════════════════════════════════════════════

    @Transactional
    public PublishedCatalogItem publishCatalogItem(CatalogItemRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Optional<PublishedCatalogItem> existing = catalogRepository.findByOrgIdAndItemIdAndIsDeletedFalse(orgId, request.itemId());
        PublishedCatalogItem item;
        if (existing.isPresent()) {
            item = existing.get();
        } else {
            item = new PublishedCatalogItem();
            item.setItemId(request.itemId());
        }

        item.setDrugMasterId(request.drugMasterId());
        item.setDisplayName(request.displayName());
        item.setPublishedSku(request.publishedSku());
        item.setHsnCode(request.hsnCode());
        item.setManufacturer(request.manufacturer());
        item.setPackSize(request.packSize());
        item.setCategory(request.category());
        item.setDescription(request.description());
        item.setPublishedMrp(request.publishedMrp());
        item.setPublishedPtr(request.publishedPtr());
        item.setMinOrderQty(request.minOrderQty() != null ? request.minOrderQty() : BigDecimal.ONE);
        item.setAvailabilityStatus(request.availabilityStatus() != null ? request.availabilityStatus() : "AVAILABLE");
        item.setActive(true);

        return catalogRepository.save(item);
    }

    @Transactional
    public void unpublishCatalogItem(UUID catalogItemId) {
        PublishedCatalogItem item = catalogRepository.findByIdAndIsDeletedFalse(catalogItemId)
                .orElseThrow(() -> BusinessException.notFound("CatalogItem", catalogItemId));
        validateOrgOwnership(item.getOrgId());
        item.setActive(false);
        catalogRepository.save(item);
    }

    @Transactional(readOnly = true)
    public List<CatalogItemResponse> getMyCatalog() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return catalogRepository.findAllByOrgIdAndIsDeletedFalse(orgId).stream()
                .map(CatalogItemResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<CatalogItemResponse> searchSupplierCatalog(String search) {
        UUID myOrgId = TenantContext.getCurrentOrgId();
        List<UUID> approvedSellerOrgIds = tradingPartnerRepository
                .findAllByBuyerOrgIdAndStatusAndIsDeletedFalse(myOrgId, "APPROVED")
                .stream().map(TradingPartner::getSellerOrgId).toList();

        if (approvedSellerOrgIds.isEmpty()) {
            return List.of();
        }

        List<PublishedCatalogItem> items;
        if (search != null && !search.isBlank()) {
            items = catalogRepository.searchAcrossSuppliers(approvedSellerOrgIds, search.trim());
        } else {
            items = catalogRepository.findAllBySuppliers(approvedSellerOrgIds);
        }

        return items.stream().map(CatalogItemResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public List<CatalogItemResponse> searchByDrugMaster(UUID drugMasterId) {
        UUID myOrgId = TenantContext.getCurrentOrgId();
        List<UUID> approvedSellerOrgIds = tradingPartnerRepository
                .findAllByBuyerOrgIdAndStatusAndIsDeletedFalse(myOrgId, "APPROVED")
                .stream().map(TradingPartner::getSellerOrgId).toList();

        if (approvedSellerOrgIds.isEmpty()) return List.of();

        return catalogRepository.findByDrugMasterIdAcrossSuppliers(drugMasterId, approvedSellerOrgIds)
                .stream().map(CatalogItemResponse::from).toList();
    }

    // ══════════════════════════════════════════════════════════════
    // Network Orders — Buyer side
    // ══════════════════════════════════════════════════════════════

    @Transactional
    public NetworkOrder placeOrder(PlaceNetworkOrderRequest request) {
        UUID buyerOrgId = TenantContext.getCurrentOrgId();

        TradingPartner tp = findPartner(request.tradingPartnerId());
        if (!tp.getBuyerOrgId().equals(buyerOrgId)) {
            throw new BusinessException("You are not the buyer in this partnership", "PN_NOT_BUYER", HttpStatus.FORBIDDEN);
        }
        if (!"APPROVED".equals(tp.getStatus())) {
            throw new BusinessException("Partnership is not approved", "PN_PARTNER_NOT_APPROVED", HttpStatus.BAD_REQUEST);
        }

        if (request.lines() == null || request.lines().isEmpty()) {
            throw new BusinessException("Order must have at least one line", "PN_EMPTY_ORDER", HttpStatus.BAD_REQUEST);
        }

        int seq = networkOrderRepository.findMaxOrderNumber(buyerOrgId) + 1;
        String orderNumber = String.format("NO-%05d", seq);

        NetworkOrder order = NetworkOrder.builder()
                .orderNumber(orderNumber)
                .buyerOrgId(buyerOrgId)
                .sellerOrgId(tp.getSellerOrgId())
                .tradingPartnerId(tp.getId())
                .status("PLACED")
                .requestedDeliveryDate(request.requestedDeliveryDate())
                .buyerNotes(request.buyerNotes())
                .build();

        BigDecimal totalAmount = BigDecimal.ZERO;
        BigDecimal totalQty = BigDecimal.ZERO;

        for (PlaceNetworkOrderRequest.LineRequest lineReq : request.lines()) {
            BigDecimal lineTotal = lineReq.unitPrice().multiply(lineReq.quantity());
            NetworkOrderLine line = NetworkOrderLine.builder()
                    .networkOrder(order)
                    .catalogItemId(lineReq.catalogItemId())
                    .buyerItemId(lineReq.buyerItemId())
                    .orderedQty(lineReq.quantity())
                    .unitPrice(lineReq.unitPrice())
                    .lineTotal(lineTotal)
                    .status("PENDING")
                    .build();

            if (lineReq.catalogItemId() != null) {
                catalogRepository.findByIdAndIsDeletedFalse(lineReq.catalogItemId()).ifPresent(cat -> {
                    line.setSellerItemId(cat.getItemId());
                    line.setDrugMasterId(cat.getDrugMasterId());
                    line.setDisplayName(cat.getDisplayName());
                    line.setHsnCode(cat.getHsnCode());
                });
            }

            order.getLines().add(line);
            totalAmount = totalAmount.add(lineTotal);
            totalQty = totalQty.add(lineReq.quantity());
        }

        order.setTotalAmount(totalAmount);
        order.setTotalQty(totalQty);

        NetworkOrder saved = networkOrderRepository.save(order);
        recordEvent(saved.getId(), buyerOrgId, "ORDER_PLACED",
                Map.of("totalAmount", totalAmount, "lineCount", request.lines().size()));

        return saved;
    }

    @Transactional
    public NetworkOrder cancelOrder(UUID orderId) {
        UUID myOrgId = TenantContext.getCurrentOrgId();
        NetworkOrder order = findOrder(orderId);

        if (!order.getBuyerOrgId().equals(myOrgId)) {
            throw new BusinessException("Only the buyer can cancel", "PN_NOT_BUYER", HttpStatus.FORBIDDEN);
        }
        if (!"PLACED".equals(order.getStatus())) {
            throw new BusinessException("Only placed orders can be cancelled", "PN_CANCEL_INVALID", HttpStatus.BAD_REQUEST);
        }

        order.setStatus("CANCELLED");
        order.setCancelledAt(Instant.now());
        order.getLines().forEach(l -> l.setStatus("CANCELLED"));

        recordEvent(orderId, myOrgId, "ORDER_CANCELLED", null);
        return networkOrderRepository.save(order);
    }

    @Transactional(readOnly = true)
    public List<NetworkOrderResponse> getMyOutgoingOrders() {
        UUID myOrgId = TenantContext.getCurrentOrgId();
        return networkOrderRepository.findAllByBuyerOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(myOrgId)
                .stream().map(this::toOrderResponse).toList();
    }

    // ══════════════════════════════════════════════════════════════
    // Network Orders — Seller side
    // ══════════════════════════════════════════════════════════════

    @Transactional(readOnly = true)
    public List<NetworkOrderResponse> getMyIncomingOrders() {
        UUID myOrgId = TenantContext.getCurrentOrgId();
        return networkOrderRepository.findAllBySellerOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(myOrgId)
                .stream().map(this::toOrderResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<NetworkOrderResponse> getPendingIncomingOrders() {
        UUID myOrgId = TenantContext.getCurrentOrgId();
        return networkOrderRepository.findAllBySellerOrgIdAndStatusAndIsDeletedFalse(myOrgId, "PLACED")
                .stream().map(this::toOrderResponse).toList();
    }

    @Transactional
    public NetworkOrder confirmOrder(UUID orderId, ConfirmNetworkOrderRequest request) {
        UUID sellerOrgId = TenantContext.getCurrentOrgId();
        NetworkOrder order = findOrder(orderId);

        if (!order.getSellerOrgId().equals(sellerOrgId)) {
            throw new BusinessException("Only the seller can confirm", "PN_NOT_SELLER", HttpStatus.FORBIDDEN);
        }
        if (!"PLACED".equals(order.getStatus())) {
            throw new BusinessException("Only placed orders can be confirmed", "PN_CONFIRM_INVALID", HttpStatus.BAD_REQUEST);
        }

        Map<UUID, ConfirmNetworkOrderRequest.LineConfirmation> confirmations = request.lines() != null
                ? request.lines().stream().collect(Collectors.toMap(
                    ConfirmNetworkOrderRequest.LineConfirmation::lineId, l -> l))
                : Map.of();

        boolean allConfirmed = true;
        boolean anyConfirmed = false;

        for (NetworkOrderLine line : order.getLines()) {
            ConfirmNetworkOrderRequest.LineConfirmation conf = confirmations.get(line.getId());
            if (conf != null && conf.confirmedQty() != null && conf.confirmedQty().compareTo(BigDecimal.ZERO) > 0) {
                line.setConfirmedQty(conf.confirmedQty());
                line.setStatus("CONFIRMED");
                if (conf.sellerItemId() != null) line.setSellerItemId(conf.sellerItemId());
                if (conf.sellerNotes() != null) line.setSellerNotes(conf.sellerNotes());
                anyConfirmed = true;
            } else {
                line.setConfirmedQty(BigDecimal.ZERO);
                line.setStatus("REJECTED");
                allConfirmed = false;
            }
        }

        order.setStatus(allConfirmed ? "CONFIRMED" : (anyConfirmed ? "PARTIALLY_CONFIRMED" : "REJECTED"));
        order.setConfirmedAt(Instant.now());
        if (request.sellerNotes() != null) order.setSellerNotes(request.sellerNotes());

        recordEvent(orderId, sellerOrgId, "ORDER_CONFIRMED",
                Map.of("status", order.getStatus()));

        return networkOrderRepository.save(order);
    }

    @Transactional
    public NetworkOrder rejectOrder(UUID orderId, String reason) {
        UUID sellerOrgId = TenantContext.getCurrentOrgId();
        NetworkOrder order = findOrder(orderId);

        if (!order.getSellerOrgId().equals(sellerOrgId)) {
            throw new BusinessException("Only the seller can reject", "PN_NOT_SELLER", HttpStatus.FORBIDDEN);
        }
        if (!"PLACED".equals(order.getStatus())) {
            throw new BusinessException("Only placed orders can be rejected", "PN_REJECT_INVALID", HttpStatus.BAD_REQUEST);
        }

        order.setStatus("REJECTED");
        order.setSellerNotes(reason);
        order.getLines().forEach(l -> {
            l.setStatus("REJECTED");
            l.setConfirmedQty(BigDecimal.ZERO);
        });

        recordEvent(orderId, sellerOrgId, "ORDER_REJECTED", Map.of("reason", reason != null ? reason : ""));
        return networkOrderRepository.save(order);
    }

    @Transactional
    public NetworkOrder markDispatched(UUID orderId) {
        UUID sellerOrgId = TenantContext.getCurrentOrgId();
        NetworkOrder order = findOrder(orderId);

        if (!order.getSellerOrgId().equals(sellerOrgId)) {
            throw new BusinessException("Only the seller can dispatch", "PN_NOT_SELLER", HttpStatus.FORBIDDEN);
        }
        if (!order.getStatus().contains("CONFIRMED")) {
            throw new BusinessException("Only confirmed orders can be dispatched", "PN_DISPATCH_INVALID", HttpStatus.BAD_REQUEST);
        }

        order.setStatus("DISPATCHED");
        order.setDispatchedAt(Instant.now());
        order.getLines().stream()
                .filter(l -> "CONFIRMED".equals(l.getStatus()))
                .forEach(l -> {
                    l.setDispatchedQty(l.getConfirmedQty());
                    l.setStatus("DISPATCHED");
                });

        recordEvent(orderId, sellerOrgId, "ORDER_DISPATCHED", null);
        return networkOrderRepository.save(order);
    }

    @Transactional
    public NetworkOrder markDelivered(UUID orderId) {
        UUID buyerOrgId = TenantContext.getCurrentOrgId();
        NetworkOrder order = findOrder(orderId);

        if (!order.getBuyerOrgId().equals(buyerOrgId)) {
            throw new BusinessException("Only the buyer can confirm delivery", "PN_NOT_BUYER", HttpStatus.FORBIDDEN);
        }
        if (!"DISPATCHED".equals(order.getStatus())) {
            throw new BusinessException("Only dispatched orders can be marked delivered", "PN_DELIVER_INVALID", HttpStatus.BAD_REQUEST);
        }

        order.setStatus("DELIVERED");
        order.setDeliveredAt(Instant.now());
        order.getLines().stream()
                .filter(l -> "DISPATCHED".equals(l.getStatus()))
                .forEach(l -> l.setStatus("DELIVERED"));

        recordEvent(orderId, buyerOrgId, "ORDER_DELIVERED", null);
        return networkOrderRepository.save(order);
    }

    // ══════════════════════════════════════════════════════════════
    // Order detail + events
    // ══════════════════════════════════════════════════════════════

    @Transactional(readOnly = true)
    public NetworkOrderResponse getOrder(UUID orderId) {
        return toOrderResponse(findOrder(orderId));
    }

    @Transactional(readOnly = true)
    public List<NetworkOrderEvent> getOrderEvents(UUID orderId) {
        findOrder(orderId);
        return eventRepository.findAllByNetworkOrderIdOrderByCreatedAtAsc(orderId);
    }

    // ══════════════════════════════════════════════════════════════
    // SO/PO linking
    // ══════════════════════════════════════════════════════════════

    @Transactional
    public void linkBuyerPo(UUID orderId, UUID purchaseOrderId) {
        NetworkOrder order = findOrder(orderId);
        validateOrgIsParty(order);
        order.setBuyerPoId(purchaseOrderId);
        networkOrderRepository.save(order);
        recordEvent(orderId, TenantContext.getCurrentOrgId(), "BUYER_PO_LINKED",
                Map.of("purchaseOrderId", purchaseOrderId.toString()));
    }

    @Transactional
    public void linkSellerSo(UUID orderId, UUID salesOrderId) {
        NetworkOrder order = findOrder(orderId);
        validateOrgIsParty(order);
        order.setSellerSoId(salesOrderId);
        networkOrderRepository.save(order);
        recordEvent(orderId, TenantContext.getCurrentOrgId(), "SELLER_SO_LINKED",
                Map.of("salesOrderId", salesOrderId.toString()));
    }

    // ══════════════════════════════════════════════════════════════
    // Helpers
    // ══════════════════════════════════════════════════════════════

    private TradingPartner findPartner(UUID id) {
        return tradingPartnerRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> BusinessException.notFound("TradingPartner", id));
    }

    private NetworkOrder findOrder(UUID id) {
        NetworkOrder order = networkOrderRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> BusinessException.notFound("NetworkOrder", id));
        validateOrgIsParty(order);
        return order;
    }

    private void validateOrgIsParty(NetworkOrder order) {
        UUID myOrgId = TenantContext.getCurrentOrgId();
        if (!order.getBuyerOrgId().equals(myOrgId) && !order.getSellerOrgId().equals(myOrgId)) {
            throw new BusinessException("Not a party to this order", "PN_NOT_PARTY", HttpStatus.FORBIDDEN);
        }
    }

    private void validateOrgOwnership(UUID ownerOrgId) {
        if (!ownerOrgId.equals(TenantContext.getCurrentOrgId())) {
            throw new BusinessException("Not the owner of this resource", "PN_NOT_OWNER", HttpStatus.FORBIDDEN);
        }
    }

    private void recordEvent(UUID orderId, UUID actorOrgId, String eventType, Map<String, Object> payload) {
        eventRepository.save(NetworkOrderEvent.builder()
                .networkOrderId(orderId)
                .eventType(eventType)
                .actorOrgId(actorOrgId)
                .actorUserId(TenantContext.getCurrentUserId())
                .payload(payload)
                .build());
    }

    private TradingPartnerResponse toPartnerResponse(TradingPartner tp) {
        String sellerName = organisationRepository.findById(tp.getSellerOrgId())
                .map(Organisation::getName).orElse("Unknown");
        String buyerName = organisationRepository.findById(tp.getBuyerOrgId())
                .map(Organisation::getName).orElse("Unknown");
        return TradingPartnerResponse.from(tp, sellerName, buyerName);
    }

    private NetworkOrderResponse toOrderResponse(NetworkOrder order) {
        String buyerName = organisationRepository.findById(order.getBuyerOrgId())
                .map(Organisation::getName).orElse("Unknown");
        String sellerName = organisationRepository.findById(order.getSellerOrgId())
                .map(Organisation::getName).orElse("Unknown");
        return NetworkOrderResponse.from(order, buyerName, sellerName);
    }
}
