package com.katasticho.erp.banking.controller;

import com.katasticho.erp.banking.dto.BankTransactionImportResponse;
import com.katasticho.erp.banking.dto.BankTransactionResponse;
import com.katasticho.erp.banking.dto.ImportBankTransactionsRequest;
import com.katasticho.erp.banking.service.BankReconciliationService;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.common.exception.BusinessException;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/banking")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.BANK_RECON)
public class BankReconciliationController {

    private final BankReconciliationService bankReconciliationService;

    @PostMapping("/transactions/import-csv")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BankTransactionImportResponse>> importCsv(
            @Valid @RequestBody ImportBankTransactionsRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(bankReconciliationService.importCsv(request)));
    }

    /** Upload the bank's statement export (.csv/.xlsx) — header auto-detected, AI fallback. */
    @PostMapping(value = "/transactions/import-file", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BankTransactionImportResponse>> importFile(
            @RequestParam("file") MultipartFile file) {
        try {
            if (file == null || file.isEmpty()) {
                throw new BusinessException("Upload your bank's statement export (.csv or .xlsx)",
                        "BANK_STATEMENT_FILE_REQUIRED", HttpStatus.BAD_REQUEST);
            }
            return ResponseEntity.ok(ApiResponse.ok(
                    bankReconciliationService.importFile(file.getOriginalFilename(), file.getBytes()),
                    "Statement imported"));
        } catch (IOException e) {
            throw new BusinessException("Could not read the uploaded file",
                    "BANK_STATEMENT_FILE_UNREADABLE", HttpStatus.BAD_REQUEST);
        }
    }

    @GetMapping("/summary")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> summary() {
        return ResponseEntity.ok(ApiResponse.ok(bankReconciliationService.summary()));
    }

    @GetMapping("/transactions")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<PagedResponse<BankTransactionResponse>>> listTransactions(
            @RequestParam(required = false) String status,
            Pageable pageable
    ) {
        return ResponseEntity.ok(ApiResponse.ok(bankReconciliationService.list(status, pageable)));
    }

    @PostMapping("/transactions/{id}/rerun-match")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BankTransactionResponse>> rerunMatch(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(bankReconciliationService.rerunMatches(id)));
    }

    @PostMapping("/transactions/{id}/ignore")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BankTransactionResponse>> ignoreTransaction(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(bankReconciliationService.ignoreTransaction(id)));
    }

    @PostMapping("/matches/{id}/accept")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BankTransactionResponse>> acceptMatch(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(bankReconciliationService.acceptMatch(id)));
    }

    @PostMapping("/matches/{id}/reject")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BankTransactionResponse>> rejectMatch(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(bankReconciliationService.rejectMatch(id)));
    }
}
