package com.katasticho.erp.transport.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.transport.dto.TransportDtos.*;
import com.katasticho.erp.transport.service.FreightRateCardService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/transport/rate-cards")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.TRANSPORT)
public class FreightRateCardController {

    private final FreightRateCardService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<FreightRateCardResponse>> create(
            @Valid @RequestBody FreightRateCardRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(service.create(request)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        service.delete(id);
        return ResponseEntity.ok(ApiResponse.<Void>ok(null, "Rate card removed"));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<FreightRateCardResponse>>> list(
            @RequestParam(required = false) UUID transporterContactId) {
        return ResponseEntity.ok(ApiResponse.ok(service.list(transporterContactId)));
    }

    /** Quote freight for a lane + weight from the matching rate card. */
    @GetMapping("/quote")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<RateQuoteResponse>> quote(
            @RequestParam UUID transporterContactId,
            @RequestParam(required = false) String origin,
            @RequestParam(required = false) String destination,
            @RequestParam(required = false) String mode,
            @RequestParam(required = false) BigDecimal weightKg) {
        return ResponseEntity.ok(ApiResponse.ok(
                service.resolveRate(transporterContactId, origin, destination, mode, weightKg)));
    }
}
