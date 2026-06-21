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

    public record ParseRequest(String message, UUID contactId) {}
}
