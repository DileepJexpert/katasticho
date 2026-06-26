package com.katasticho.erp.pricing.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.pricing.dto.CreatePriceListRequest;
import com.katasticho.erp.pricing.dto.PriceListItemRequest;
import com.katasticho.erp.pricing.dto.PriceListItemResponse;
import com.katasticho.erp.pricing.dto.PriceListResponse;
import com.katasticho.erp.pricing.service.PriceListService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * CRUD over price lists and their tier items (v2 Feature 3). The
 * resolver that applies prices at invoice-create time lives in
 * {@link PriceListService#resolvePrice} and is called from
 * {@code InvoiceService}, not from this controller — HTTP callers
 * never invoke it directly.
 */
@RestController
@RequestMapping("/api/v1/price-lists")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.INVENTORY)
public class PriceListController {

    private final PriceListService priceListService;

    // ── Price list CRUD ─────────────────────────────────────────────────

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<PriceListResponse>> create(
            @Valid @RequestBody CreatePriceListRequest request) {
        PriceListResponse response = PriceListResponse.from(priceListService.createPriceList(request));
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<PriceListResponse>>> list() {
        List<PriceListResponse> result = priceListService.listPriceLists().stream()
                .map(PriceListResponse::from)
                .toList();
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PriceListResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(
                PriceListResponse.from(priceListService.getPriceList(id))));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        priceListService.deletePriceList(id);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    // ── Price list item (tier) CRUD ─────────────────────────────────────

    @PostMapping("/{id}/items")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<PriceListItemResponse>> addItem(
            @PathVariable UUID id,
            @Valid @RequestBody PriceListItemRequest request) {
        PriceListItemResponse response = PriceListItemResponse.from(
                priceListService.addItem(id, request));
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    @GetMapping("/{id}/items")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<PriceListItemResponse>>> listItems(
            @PathVariable UUID id) {
        // Enriched variant joins each row with the item's SKU + name in
        // one batch lookup so the Flutter detail screen can group tiers
        // by item name without an N+1 fetch.
        List<PriceListItemResponse> result = priceListService.listItemsEnriched(id);
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @DeleteMapping("/items/{itemRowId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> deleteItem(@PathVariable UUID itemRowId) {
        priceListService.deleteItem(itemRowId);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    // ── Customer ↔ price-list assignment ────────────────────────────────

    /** Customers currently pinned to this price list. */
    @GetMapping("/{id}/customers")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> listCustomers(
            @PathVariable UUID id) {
        List<Map<String, Object>> result = priceListService.listContactsForPriceList(id).stream()
                .map(PriceListController::toCustomerRow)
                .toList();
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    /** Pin a customer to this price list. */
    @PostMapping("/{id}/customers/{contactId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> assignCustomer(
            @PathVariable UUID id, @PathVariable UUID contactId) {
        Contact saved = priceListService.assignContact(id, contactId);
        return ResponseEntity.ok(ApiResponse.ok(toCustomerRow(saved), "Customer assigned to price list"));
    }

    /** Remove a customer's pin (the path's price-list id is informational). */
    @DeleteMapping("/{id}/customers/{contactId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> unassignCustomer(
            @PathVariable UUID id, @PathVariable UUID contactId) {
        priceListService.unassignContact(contactId);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    private static Map<String, Object> toCustomerRow(Contact c) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", c.getId());
        m.put("displayName", c.getDisplayName());
        m.put("contactType", c.getContactType() != null ? c.getContactType().name() : null);
        m.put("phone", c.getPhone());
        m.put("defaultPriceListId", c.getDefaultPriceListId());
        return m;
    }
}
