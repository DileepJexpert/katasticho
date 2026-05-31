package com.katasticho.erp.ar.controller;

import com.katasticho.erp.ar.dto.CustomerRiskResponse;
import com.katasticho.erp.ar.dto.OverdueCustomerResponse;
import com.katasticho.erp.ar.dto.ReminderTextResponse;
import com.katasticho.erp.ar.service.CreditReminderService;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/ar/credit-reminders")
@RequiredArgsConstructor
public class CreditReminderController {

    private final CreditReminderService creditReminderService;

    @GetMapping("/overdue")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<List<OverdueCustomerResponse>>> getOverdueCustomers() {
        List<OverdueCustomerResponse> result = creditReminderService.getOverdueCustomers();
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @GetMapping("/risk")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<List<CustomerRiskResponse>>> getCustomerRisk() {
        List<CustomerRiskResponse> result = creditReminderService.getCustomerRisk();
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @GetMapping("/{contactId}/outstanding")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<OverdueCustomerResponse>> getCustomerOutstanding(
            @PathVariable UUID contactId) {
        OverdueCustomerResponse result = creditReminderService.getCustomerOutstanding(contactId);
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @GetMapping("/{contactId}/reminder-text")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<ReminderTextResponse>> getReminderText(
            @PathVariable UUID contactId) {
        ReminderTextResponse result = creditReminderService.generateReminderMessage(contactId);
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @PostMapping("/{contactId}/mark-sent")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<Map<String, String>>> markReminderSent(
            @PathVariable UUID contactId,
            @RequestBody(required = false) Map<String, String> body) {
        String channel = body != null ? body.getOrDefault("channel", "WHATSAPP") : "WHATSAPP";
        creditReminderService.markReminderSent(contactId, channel);
        return ResponseEntity.ok(ApiResponse.ok(Map.of("status", "ok"), "Reminder marked as sent"));
    }
}
