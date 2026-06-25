package com.katasticho.erp.banking.controller;

import com.katasticho.erp.banking.dto.BankAccountRequest;
import com.katasticho.erp.banking.dto.BankAccountResponse;
import com.katasticho.erp.banking.service.BankAccountService;
import com.katasticho.erp.common.dto.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/bank-accounts")
@RequiredArgsConstructor
public class BankAccountController {

    private final BankAccountService bankAccountService;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<BankAccountResponse>>> list(
            @RequestParam(name = "active_only", defaultValue = "false") boolean activeOnly) {
        return ResponseEntity.ok(ApiResponse.ok(bankAccountService.list(activeOnly)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<BankAccountResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(bankAccountService.get(id)));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BankAccountResponse>> create(
            @Valid @RequestBody BankAccountRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(bankAccountService.create(request)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BankAccountResponse>> update(
            @PathVariable UUID id, @Valid @RequestBody BankAccountRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(bankAccountService.update(id, request)));
    }

    @PostMapping("/{id}/set-default")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BankAccountResponse>> setDefault(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(bankAccountService.setDefault(id), "Default bank account updated"));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        bankAccountService.delete(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Bank account removed"));
    }
}
