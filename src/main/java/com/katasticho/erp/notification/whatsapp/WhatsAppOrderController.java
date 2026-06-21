package com.katasticho.erp.notification.whatsapp;

import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

/**
 * WhatsApp inbound order parsing endpoints. The webhook receiver (still to
 * land) will feed messages into {@link WhatsAppOrderService#parseForContact};
 * for now these endpoints let the user / a test harness post a message and
 * see the parsed draft.
 */
@RestController
@RequestMapping("/api/v1/whatsapp/orders")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
public class WhatsAppOrderController {

    private final WhatsAppOrderService orderService;

    @PostMapping("/parse")
    public ResponseEntity<ApiResponse<Map<String, Object>>> parse(
            @RequestBody ParseRequest req) {
        var parsed = req.contactId() == null
                ? orderService.parse(req.message())
                : orderService.parseForContact(req.message(), req.contactId());
        return ResponseEntity.ok(ApiResponse.ok(orderService.toResponse(parsed)));
    }

    /**
     * Parse the message AND create a DRAFT Sales Order in one step.
     * Used by the confirm-on-WhatsApp flow once the customer (or owner) has
     * approved the parsed lines.
     */
    @PostMapping("/confirm")
    public ResponseEntity<ApiResponse<com.katasticho.erp.sales.dto.SalesOrderResponse>> confirm(
            @RequestBody ConfirmRequest req) {
        var parsed = orderService.parseForContact(req.message(), req.contactId());
        return ResponseEntity.ok(ApiResponse.ok(
                orderService.confirmAndCreate(parsed, req.contactId(), req.referenceTag()),
                "Sales order drafted from WhatsApp message"));
    }

    public record ParseRequest(String message, UUID contactId) {}
    public record ConfirmRequest(String message, UUID contactId, String referenceTag) {}
}
