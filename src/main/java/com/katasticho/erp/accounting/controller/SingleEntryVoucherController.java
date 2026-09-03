package com.katasticho.erp.accounting.controller;

import com.katasticho.erp.accounting.dto.JournalEntryResponse;
import com.katasticho.erp.accounting.dto.SingleEntryVoucherRequest;
import com.katasticho.erp.accounting.service.SingleEntryVoucherService;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/accounting/single-entry-vouchers")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.ACCOUNTING)
@PreAuthorize("hasAnyRole('OWNER', 'ADMIN', 'ACCOUNTANT')")
public class SingleEntryVoucherController {

    private final SingleEntryVoucherService singleEntryVoucherService;

    @PostMapping
    public ApiResponse<JournalEntryResponse> createSingleEntryVoucher(
            @Valid @RequestBody SingleEntryVoucherRequest request) {
        JournalEntryResponse response = singleEntryVoucherService.postSingleEntryVoucher(request);
        return ApiResponse.ok(response);
    }
}
