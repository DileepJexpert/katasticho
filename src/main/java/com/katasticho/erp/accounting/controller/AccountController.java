package com.katasticho.erp.accounting.controller;

import com.katasticho.erp.accounting.dto.AccountResponse;
import com.katasticho.erp.accounting.dto.CreateAccountRequest;
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
        int count = accountService.seedFromTemplate(TenantContext.getCurrentOrgId(), industry);
        return ResponseEntity.ok(ApiResponse.ok(Map.of("accountsCreated", count, "industry", industry)));
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
