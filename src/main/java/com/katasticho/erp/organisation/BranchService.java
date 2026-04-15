package com.katasticho.erp.organisation;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.dto.BranchResponse;
import com.katasticho.erp.organisation.dto.CreateBranchRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class BranchService {

    private final BranchRepository branchRepository;
    private final AuditService auditService;

    @Transactional
    public BranchResponse createBranch(CreateBranchRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        String code = request.code().trim();
        if (branchRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, code)) {
            throw new BusinessException("Branch with code " + code + " already exists",
                    "ORG_DUPLICATE_BRANCH_CODE", HttpStatus.CONFLICT);
        }

        boolean makeDefault = Boolean.TRUE.equals(request.isDefault());
        if (makeDefault) {
            // Only one default per org — demote existing default if any.
            branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                    .ifPresent(existing -> {
                        existing.setDefault(false);
                        branchRepository.save(existing);
                    });
        } else {
            // First branch for this org becomes default automatically.
            if (branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId).isEmpty()) {
                makeDefault = true;
            }
        }

        Branch branch = Branch.builder()
                .code(code)
                .name(request.name().trim())
                .addressLine1(request.addressLine1())
                .addressLine2(request.addressLine2())
                .city(request.city())
                .state(request.state())
                .stateCode(request.stateCode())
                .postalCode(request.postalCode())
                .country(request.country() != null ? request.country() : "IN")
                .gstin(request.gstin())
                .isDefault(makeDefault)
                .active(true)
                .build();

        branch = branchRepository.save(branch);
        auditService.log("BRANCH", branch.getId(), "CREATE", null,
                "{\"code\":\"" + branch.getCode() + "\"}");
        return toResponse(branch);
    }

    @Transactional(readOnly = true)
    public List<BranchResponse> listBranches() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return branchRepository.findByOrgIdAndIsDeletedFalseOrderByName(orgId)
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public BranchResponse getBranch(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Branch b = branchRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Branch", id));
        return toResponse(b);
    }

    /**
     * Resolve a branchId for a create operation. If the caller explicitly
     * passed one, validate it. Otherwise fall back to the org's default
     * branch. Used by Invoice/Payment/Warehouse services when stamping
     * branch_id on new rows.
     */
    @Transactional(readOnly = true)
    public UUID resolveBranchId(UUID requested) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (requested != null) {
            branchRepository.findByIdAndOrgIdAndIsDeletedFalse(requested, orgId)
                    .orElseThrow(() -> BusinessException.notFound("Branch", requested));
            return requested;
        }
        return branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .map(Branch::getId)
                .orElse(null);
    }

    public BranchResponse toResponse(Branch b) {
        return new BranchResponse(
                b.getId(), b.getCode(), b.getName(),
                b.getAddressLine1(), b.getAddressLine2(),
                b.getCity(), b.getState(), b.getStateCode(),
                b.getPostalCode(), b.getCountry(), b.getGstin(),
                b.isDefault(), b.isActive(), b.getCreatedAt());
    }
}
