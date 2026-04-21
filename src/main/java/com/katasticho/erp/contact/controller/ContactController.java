package com.katasticho.erp.contact.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.contact.dto.*;
import com.katasticho.erp.contact.service.ContactImportService;
import com.katasticho.erp.contact.service.ContactService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.nio.charset.StandardCharsets;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/contacts")
@RequiredArgsConstructor
public class ContactController {

    private final ContactService contactService;
    private final ContactImportService contactImportService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<ContactResponse> create(@Valid @RequestBody CreateContactRequest req) {
        return ApiResponse.created(contactService.create(req));
    }

    @GetMapping
    public ApiResponse<Page<ContactResponse>> list(
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String search,
            @PageableDefault(size = 20) Pageable pageable) {
        return ApiResponse.ok(contactService.list(type, search, pageable));
    }

    @GetMapping("/{id}")
    public ApiResponse<ContactResponse> get(@PathVariable UUID id) {
        return ApiResponse.ok(contactService.get(id));
    }

    @PutMapping("/{id}")
    public ApiResponse<ContactResponse> update(
            @PathVariable UUID id,
            @Valid @RequestBody CreateContactRequest req) {
        return ApiResponse.ok(contactService.update(id, req));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID id) {
        contactService.delete(id);
    }

    @PostMapping("/{id}/persons")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<ContactPersonResponse> addPerson(
            @PathVariable UUID id,
            @Valid @RequestBody ContactPersonRequest req) {
        return ApiResponse.created(contactService.addPerson(id, req));
    }

    @DeleteMapping("/{id}/persons/{personId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deletePerson(@PathVariable UUID id, @PathVariable UUID personId) {
        contactService.deletePerson(id, personId);
    }

    @PostMapping(value = "/import", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<ContactImportResult>> importContacts(
            @RequestParam("file") MultipartFile file) {
        ContactImportResult result = contactImportService.importContacts(file);
        String message = result.created() + " contacts imported, " + result.skipped() + " skipped";
        return ResponseEntity.ok(ApiResponse.ok(result, message));
    }

    @PostMapping(value = "/import/preview", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<ContactImportPreview>> previewImport(
            @RequestParam("file") MultipartFile file) {
        ContactImportPreview preview = contactImportService.previewImport(file);
        String message = preview.validRows() + " valid, " + preview.errorRows() + " with errors";
        return ResponseEntity.ok(ApiResponse.ok(preview, message));
    }

    @GetMapping(value = "/import/template", produces = "text/csv")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<byte[]> downloadImportTemplate() {
        String csv = ContactImportService.TEMPLATE_HEADER + "\n"
                + "Rajesh Builder,CUSTOMER,9876543210,rajesh@example.com,,MG Road,Mumbai,Maharashtra,30,0\n";
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename=\"contact_import_template.csv\"")
                .body(csv.getBytes(StandardCharsets.UTF_8));
    }
}
