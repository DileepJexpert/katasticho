package com.katasticho.erp.accounting.controller;

import com.katasticho.erp.accounting.dto.AccountResponse;
import com.katasticho.erp.accounting.dto.AccountTransactionResponse;
import com.katasticho.erp.accounting.dto.CreateAccountRequest;
import com.katasticho.erp.accounting.dto.UpdateAccountRequest;
import com.katasticho.erp.accounting.service.AccountService;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/accounts")
@RequiredArgsConstructor
public class AccountController {

    private final AccountService accountService;
    private final JournalService journalService;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<AccountResponse>>> listAccounts() {
        List<AccountResponse> accounts = accountService.listAccounts(TenantContext.getCurrentOrgId());
        return ResponseEntity.ok(ApiResponse.ok(accounts));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<AccountResponse>> createAccount(@Valid @RequestBody CreateAccountRequest request) {
        AccountResponse account = accountService.createAccount(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(account));
    }

    @PostMapping("/template")
    @PreAuthorize("hasRole('OWNER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> seedTemplate(@RequestBody Map<String, String> request) {
        String industry = request.getOrDefault("industry", "TRADING");
        var result = accountService.seedFromTemplate(TenantContext.getCurrentOrgId(), industry);
        return ResponseEntity.ok(ApiResponse.ok(Map.of("result", result, "industry", industry)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<AccountResponse>> getAccount(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(accountService.getAccount(id)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<AccountResponse>> updateAccount(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateAccountRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(accountService.updateAccount(id, request)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> deleteAccount(@PathVariable UUID id) {
        accountService.deleteAccount(id);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    @PatchMapping("/{id}/activate")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> activateAccount(@PathVariable UUID id) {
        accountService.setActive(id, true);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    @PatchMapping("/{id}/deactivate")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> deactivateAccount(@PathVariable UUID id) {
        accountService.setActive(id, false);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }

    @GetMapping("/{id}/transactions")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<AccountTransactionResponse>>> getAccountTransactions(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(accountService.getAccountTransactions(id)));
    }

    @GetMapping("/{id}/balance")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getBalance(
            @PathVariable UUID id,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOfDate) {
        if (asOfDate == null) asOfDate = LocalDate.now();
        BigDecimal balance = journalService.getAccountBalance(id, TenantContext.getCurrentOrgId(), asOfDate);
        return ResponseEntity.ok(ApiResponse.ok(Map.of("accountId", id, "balance", balance, "asOfDate", asOfDate)));
    }
}
