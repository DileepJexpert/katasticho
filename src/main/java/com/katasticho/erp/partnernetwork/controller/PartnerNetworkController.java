package com.katasticho.erp.partnernetwork.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.partnernetwork.dto.*;
import com.katasticho.erp.partnernetwork.entity.*;
import com.katasticho.erp.partnernetwork.service.PartnerNetworkService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/partner-network")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.PARTNER_NETWORK)
@PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
public class PartnerNetworkController {

    private final PartnerNetworkService service;

    // ── Trading Partners ──────────────────────────────────────────

    @GetMapping("/partners")
    public ResponseEntity<ApiResponse<List<TradingPartnerResponse>>> getPartners() {
        return ResponseEntity.ok(ApiResponse.ok(service.getMyPartners()));
    }

    @GetMapping("/partners/pending")
    public ResponseEntity<ApiResponse<List<TradingPartnerResponse>>> getPendingRequests() {
        return ResponseEntity.ok(ApiResponse.ok(service.getPendingRequests()));
    }

    @GetMapping("/partners/{id}")
    public ResponseEntity<ApiResponse<TradingPartnerResponse>> getPartner(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getPartner(id)));
    }

    @PostMapping("/partners/request")
    public ResponseEntity<ApiResponse<TradingPartner>> requestPartnership(@RequestBody TradingPartnerRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(service.requestPartnership(request), "Partnership request sent"));
    }

    @PostMapping("/partners/{id}/approve")
    public ResponseEntity<ApiResponse<TradingPartner>> approvePartnership(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.approvePartnership(id), "Partnership approved"));
    }

    @PostMapping("/partners/{id}/reject")
    public ResponseEntity<ApiResponse<TradingPartner>> rejectPartnership(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.rejectPartnership(id), "Partnership rejected"));
    }

    @PostMapping("/partners/{id}/suspend")
    public ResponseEntity<ApiResponse<TradingPartner>> suspendPartnership(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.suspendPartnership(id), "Partnership suspended"));
    }

    // ── Published Catalog ─────────────────────────────────────────

    @GetMapping("/catalog")
    public ResponseEntity<ApiResponse<List<CatalogItemResponse>>> getMyCatalog() {
        return ResponseEntity.ok(ApiResponse.ok(service.getMyCatalog()));
    }

    @PostMapping("/catalog")
    public ResponseEntity<ApiResponse<PublishedCatalogItem>> publishCatalogItem(@RequestBody CatalogItemRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(service.publishCatalogItem(request), "Item published to catalog"));
    }

    @PostMapping("/catalog/{id}/unpublish")
    public ResponseEntity<ApiResponse<Void>> unpublishCatalogItem(@PathVariable UUID id) {
        service.unpublishCatalogItem(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Item removed from catalog"));
    }

    // ── Supplier Search (buyer view) ──────────────────────────────

    @GetMapping("/supplier-search")
    public ResponseEntity<ApiResponse<List<CatalogItemResponse>>> searchSupplierCatalog(
            @RequestParam(required = false) String search) {
        return ResponseEntity.ok(ApiResponse.ok(service.searchSupplierCatalog(search)));
    }

    @GetMapping("/supplier-search/by-drug/{drugMasterId}")
    public ResponseEntity<ApiResponse<List<CatalogItemResponse>>> searchByDrugMaster(@PathVariable UUID drugMasterId) {
        return ResponseEntity.ok(ApiResponse.ok(service.searchByDrugMaster(drugMasterId)));
    }

    // ── Network Orders ────────────────────────────────────────────

    @PostMapping("/orders")
    public ResponseEntity<ApiResponse<NetworkOrderResponse>> placeOrder(@RequestBody PlaceNetworkOrderRequest request) {
        NetworkOrder order = service.placeOrder(request);
        return ResponseEntity.ok(ApiResponse.ok(service.getOrder(order.getId()), "Order placed"));
    }

    @GetMapping("/orders/outgoing")
    public ResponseEntity<ApiResponse<List<NetworkOrderResponse>>> getOutgoingOrders() {
        return ResponseEntity.ok(ApiResponse.ok(service.getMyOutgoingOrders()));
    }

    @GetMapping("/orders/incoming")
    public ResponseEntity<ApiResponse<List<NetworkOrderResponse>>> getIncomingOrders() {
        return ResponseEntity.ok(ApiResponse.ok(service.getMyIncomingOrders()));
    }

    @GetMapping("/orders/incoming/pending")
    public ResponseEntity<ApiResponse<List<NetworkOrderResponse>>> getPendingIncomingOrders() {
        return ResponseEntity.ok(ApiResponse.ok(service.getPendingIncomingOrders()));
    }

    @GetMapping("/orders/{id}")
    public ResponseEntity<ApiResponse<NetworkOrderResponse>> getOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getOrder(id)));
    }

    @GetMapping("/orders/{id}/events")
    public ResponseEntity<ApiResponse<List<NetworkOrderEvent>>> getOrderEvents(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getOrderEvents(id)));
    }

    @PostMapping("/orders/{id}/confirm")
    public ResponseEntity<ApiResponse<NetworkOrderResponse>> confirmOrder(
            @PathVariable UUID id, @RequestBody ConfirmNetworkOrderRequest request) {
        service.confirmOrder(id, request);
        return ResponseEntity.ok(ApiResponse.ok(service.getOrder(id), "Order confirmed"));
    }

    @PostMapping("/orders/{id}/reject")
    public ResponseEntity<ApiResponse<NetworkOrderResponse>> rejectOrder(
            @PathVariable UUID id, @RequestBody(required = false) Map<String, String> body) {
        String reason = body != null ? body.get("reason") : null;
        service.rejectOrder(id, reason);
        return ResponseEntity.ok(ApiResponse.ok(service.getOrder(id), "Order rejected"));
    }

    @PostMapping("/orders/{id}/cancel")
    public ResponseEntity<ApiResponse<NetworkOrderResponse>> cancelOrder(@PathVariable UUID id) {
        service.cancelOrder(id);
        return ResponseEntity.ok(ApiResponse.ok(service.getOrder(id), "Order cancelled"));
    }

    @PostMapping("/orders/{id}/dispatch")
    public ResponseEntity<ApiResponse<NetworkOrderResponse>> markDispatched(@PathVariable UUID id) {
        service.markDispatched(id);
        return ResponseEntity.ok(ApiResponse.ok(service.getOrder(id), "Order dispatched"));
    }

    @PostMapping("/orders/{id}/deliver")
    public ResponseEntity<ApiResponse<NetworkOrderResponse>> markDelivered(@PathVariable UUID id) {
        service.markDelivered(id);
        return ResponseEntity.ok(ApiResponse.ok(service.getOrder(id), "Order delivered"));
    }

    // ── SO/PO Linking ─────────────────────────────────────────────

    @PostMapping("/orders/{id}/link-po")
    public ResponseEntity<ApiResponse<Void>> linkBuyerPo(
            @PathVariable UUID id, @RequestBody Map<String, UUID> body) {
        service.linkBuyerPo(id, body.get("purchaseOrderId"));
        return ResponseEntity.ok(ApiResponse.ok(null, "Purchase order linked"));
    }

    @PostMapping("/orders/{id}/link-so")
    public ResponseEntity<ApiResponse<Void>> linkSellerSo(
            @PathVariable UUID id, @RequestBody Map<String, UUID> body) {
        service.linkSellerSo(id, body.get("salesOrderId"));
        return ResponseEntity.ok(ApiResponse.ok(null, "Sales order linked"));
    }
}
