package com.katasticho.erp.banking.controller;

import com.katasticho.erp.banking.dto.BankRuleDtos.BankRuleRequest;
import com.katasticho.erp.banking.dto.BankRuleDtos.BankRuleResponse;
import com.katasticho.erp.banking.service.BankRuleService;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/**
 * User-defined bank matching rules — categorise non-document bank transactions
 * (charges, interest, utilities, salaries) to a GL account. Rules are org-scoped;
 * OWNER/ADMIN/ACCOUNTANT manage them (they drive automatic journal postings).
 */
@RestController
@RequestMapping("/api/v1/bank-rules")
@RequiredArgsConstructor
public class BankRuleController {

    private final BankRuleService bankRuleService;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<BankRuleResponse>>> list() {
        return ResponseEntity.ok(ApiResponse.ok(bankRuleService.list()));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<BankRuleResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(bankRuleService.get(id)));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BankRuleResponse>> create(@RequestBody BankRuleRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(bankRuleService.create(request)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BankRuleResponse>> update(
            @PathVariable UUID id, @RequestBody BankRuleRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(bankRuleService.update(id, request)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        bankRuleService.delete(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Bank rule removed"));
    }
}
