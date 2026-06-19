package com.katasticho.erp.portal.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.contact.dto.ContactLedgerResponse;
import com.katasticho.erp.portal.service.PortalAuthService;
import com.katasticho.erp.portal.service.PortalDataService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

/**
 * The logged-in portal user's own data — invoices/outstanding/ledger (customer)
 * or POs/bills (vendor). Authenticated by the portal JWT (ROLE_PORTAL); every
 * query is scoped to the user's own contact inside {@link PortalDataService}.
 */
@RestController
@RequestMapping("/api/v1/portal")
@RequiredArgsConstructor
@PreAuthorize("hasRole('PORTAL')")
public class PortalSelfController {

    private final PortalDataService dataService;
    private final PortalAuthService authService;

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<Map<String, Object>>> me() {
        return ResponseEntity.ok(ApiResponse.ok(dataService.me()));
    }

    @GetMapping("/dashboard")
    public ResponseEntity<ApiResponse<Map<String, Object>>> dashboard() {
        return ResponseEntity.ok(ApiResponse.ok(dataService.dashboard()));
    }

    // Customer
    @GetMapping("/invoices")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> invoices() {
        return ResponseEntity.ok(ApiResponse.ok(dataService.invoices()));
    }

    @GetMapping("/statement")
    public ResponseEntity<ApiResponse<ContactLedgerResponse>> statement(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(ApiResponse.ok(dataService.statement(from, to)));
    }

    // Vendor
    @GetMapping("/purchase-orders")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> purchaseOrders() {
        return ResponseEntity.ok(ApiResponse.ok(dataService.purchaseOrders()));
    }

    @GetMapping("/bills")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> bills() {
        return ResponseEntity.ok(ApiResponse.ok(dataService.bills()));
    }

    @PostMapping("/change-password")
    public ResponseEntity<ApiResponse<Void>> changePassword(@RequestBody Map<String, Object> body) {
        authService.changePassword((String) body.get("currentPassword"), (String) body.get("newPassword"));
        return ResponseEntity.ok(ApiResponse.ok(null, "Password changed"));
    }
}
