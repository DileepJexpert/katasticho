package com.katasticho.erp.pharma.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.pharma.dto.PrescriptionRequest;
import com.katasticho.erp.pharma.dto.PrescriptionResponse;
import com.katasticho.erp.pharma.service.PrescriptionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/prescriptions")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
public class PrescriptionController {

    private final PrescriptionService prescriptionService;

    @PostMapping
    public ResponseEntity<ApiResponse<PrescriptionResponse>> create(
            @Valid @RequestBody PrescriptionRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(prescriptionService.create(request)));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<Page<PrescriptionResponse>>> list(
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(prescriptionService.list(pageable)));
    }

    @GetMapping("/by-contact/{contactId}")
    public ResponseEntity<ApiResponse<List<PrescriptionResponse>>> getByContact(
            @PathVariable UUID contactId) {
        return ResponseEntity.ok(ApiResponse.ok(prescriptionService.getByContact(contactId)));
    }

    @GetMapping("/by-receipt/{receiptId}")
    public ResponseEntity<ApiResponse<Optional<PrescriptionResponse>>> getByReceipt(
            @PathVariable UUID receiptId) {
        return ResponseEntity.ok(ApiResponse.ok(prescriptionService.getByReceipt(receiptId)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<PrescriptionResponse>> getById(
            @PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(prescriptionService.getById(id)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        prescriptionService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
