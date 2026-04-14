package com.katasticho.erp.contact.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.contact.dto.*;
import com.katasticho.erp.contact.service.ContactService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/contacts")
@RequiredArgsConstructor
public class ContactController {

    private final ContactService contactService;

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
}
