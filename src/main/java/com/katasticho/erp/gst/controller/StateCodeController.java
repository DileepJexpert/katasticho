package com.katasticho.erp.gst.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.gst.entity.GstStateCode;
import com.katasticho.erp.gst.service.GstStateCodeService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * GST state-code reference lookup. Deliberately NOT module-gated — every org
 * needs the state list for address/GSTIN entry regardless of the GST module.
 */
@RestController
@RequestMapping("/api/v1/reference/state-codes")
@RequiredArgsConstructor
public class StateCodeController {

    private final GstStateCodeService service;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<GstStateCode>>> list() {
        return ResponseEntity.ok(ApiResponse.ok(service.listAll()));
    }

    @GetMapping("/by-gstin/{gstin}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<GstStateCode>> byGstin(@PathVariable String gstin) {
        GstStateCode state = service.resolveFromGstin(gstin)
                .orElseThrow(() -> new BusinessException(
                        "No GST state matches the GSTIN prefix",
                        "GST_STATE_NOT_FOUND", HttpStatus.NOT_FOUND));
        return ResponseEntity.ok(ApiResponse.ok(state));
    }
}
