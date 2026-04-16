package com.katasticho.erp.tax.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.tax.dto.TaxGroupResponse;
import com.katasticho.erp.tax.entity.TaxGroup;
import com.katasticho.erp.tax.entity.TaxGroupRate;
import com.katasticho.erp.tax.entity.TaxRate;
import com.katasticho.erp.tax.repository.TaxGroupRateRepository;
import com.katasticho.erp.tax.repository.TaxGroupRepository;
import com.katasticho.erp.tax.repository.TaxRateRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Objects;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/tax-groups")
@RequiredArgsConstructor
public class TaxGroupController {

    private final TaxGroupRepository taxGroupRepository;
    private final TaxGroupRateRepository taxGroupRateRepository;
    private final TaxRateRepository taxRateRepository;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<TaxGroupResponse>>> listTaxGroups() {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<TaxGroup> groups = taxGroupRepository.findByOrgIdAndActiveTrue(orgId);
        List<TaxGroupResponse> responses = groups.stream()
                .map(this::toResponse)
                .toList();
        return ResponseEntity.ok(ApiResponse.ok(responses));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<TaxGroupResponse>> getTaxGroup(@PathVariable UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        TaxGroup group = taxGroupRepository.findByIdAndOrgId(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("TaxGroup", id));
        return ResponseEntity.ok(ApiResponse.ok(toResponse(group)));
    }

    private TaxGroupResponse toResponse(TaxGroup group) {
        List<TaxGroupRate> groupRates = taxGroupRateRepository.findByTaxGroupId(group.getId());
        List<TaxGroupResponse.TaxRateInfo> rateInfos = groupRates.stream()
                .map(gr -> taxRateRepository.findById(gr.getTaxRateId())
                        .map(r -> new TaxGroupResponse.TaxRateInfo(
                                r.getId(), r.getRateCode(), r.getName(),
                                r.getPercentage(), r.getTaxType(), r.isRecoverable()))
                        .orElse(null))
                .filter(Objects::nonNull)
                .toList();
        return new TaxGroupResponse(group.getId(), group.getName(), group.getDescription(),
                group.isActive(), rateInfos);
    }
}
