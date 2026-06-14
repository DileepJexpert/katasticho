package com.katasticho.erp.hr.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.hr.entity.EmployeeDocument;
import com.katasticho.erp.hr.service.EmployeeDocumentService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** HR Employee Document management — Core HR module 7. */
@RestController
@RequestMapping("/api/v1/hr/documents")
@RequiredArgsConstructor
public class EmployeeDocumentController {

    private final EmployeeDocumentService service;

    /** Self-service: upload one of my own documents. */
    @PostMapping(value = "/me", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<EmployeeDocument>> uploadMine(
            @RequestParam("file") MultipartFile file,
            @RequestParam(required = false) String category,
            @RequestParam String title,
            @RequestParam(required = false) String expiry) {
        EmployeeDocument doc = service.upload(
                TenantContext.getCurrentUserId(), category, title, parseDate(expiry), file);
        return ResponseEntity.ok(ApiResponse.ok(doc, "Document uploaded"));
    }

    /** HR uploads a document for an employee. */
    @PostMapping(value = "/{employeeUserId}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<EmployeeDocument>> uploadForEmployee(
            @PathVariable UUID employeeUserId,
            @RequestParam("file") MultipartFile file,
            @RequestParam(required = false) String category,
            @RequestParam String title,
            @RequestParam(required = false) String expiry) {
        EmployeeDocument doc = service.upload(employeeUserId, category, title, parseDate(expiry), file);
        return ResponseEntity.ok(ApiResponse.ok(doc, "Document uploaded"));
    }

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<List<EmployeeDocument>>> mine() {
        return ResponseEntity.ok(ApiResponse.ok(service.myDocuments()));
    }

    @GetMapping("/{employeeUserId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<EmployeeDocument>>> forEmployee(
            @PathVariable UUID employeeUserId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listForEmployee(employeeUserId)));
    }

    @GetMapping("/expiring")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<EmployeeDocument>>> expiring(
            @RequestParam(defaultValue = "30") int days) {
        return ResponseEntity.ok(ApiResponse.ok(service.expiring(days)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        service.delete(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Document deleted"));
    }

    private static LocalDate parseDate(String s) {
        return (s == null || s.isBlank()) ? null : LocalDate.parse(s);
    }
}
