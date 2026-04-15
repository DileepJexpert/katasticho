package com.katasticho.erp.organisation;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.organisation.dto.BranchResponse;
import com.katasticho.erp.organisation.dto.CreateBranchRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/branches")
@RequiredArgsConstructor
public class BranchController {

    private final BranchService branchService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<BranchResponse>> createBranch(
            @Valid @RequestBody CreateBranchRequest request) {
        BranchResponse b = branchService.createBranch(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(b));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<BranchResponse>>> listBranches() {
        return ResponseEntity.ok(ApiResponse.ok(branchService.listBranches()));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<BranchResponse>> getBranch(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(branchService.getBranch(id)));
    }
}
