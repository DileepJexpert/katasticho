package com.katasticho.erp.ca.service;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.ca.dto.CaFirmResponse;
import com.katasticho.erp.ca.dto.CreateCaFirmRequest;
import com.katasticho.erp.ca.entity.CaFirm;
import com.katasticho.erp.ca.repository.CaFirmRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.service.FeatureFlagService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CaFirmService {

    private final CaFirmRepository caFirmRepository;
    private final AppUserRepository appUserRepository;
    private final FeatureFlagService featureFlagService;

    @Transactional
    public CaFirmResponse createOrGet(CreateCaFirmRequest request) {
        String role = TenantContext.getCurrentRole();
        if (!"OWNER".equals(role) && !"ADMIN".equals(role) && !"CA_PARTNER".equals(role)) {
            throw new BusinessException("Only org owner/admin can enable CA Console",
                    "CA_FIRM_OWNER_REQUIRED", HttpStatus.FORBIDDEN);
        }
        var existing = caFirmRepository.findByOrgIdAndActiveTrue(TenantContext.getCurrentOrgId());
        if (existing.isPresent()) {
            return toResponse(existing.get());
        }
        CaFirm firm = caFirmRepository.save(CaFirm.builder()
                .orgId(TenantContext.getCurrentOrgId())
                .firmName(request.firmName() == null || request.firmName().isBlank()
                        ? "CA Firm"
                        : request.firmName().trim())
                .icaiNumber(request.icaiNumber())
                .active(true)
                .build());
        AppUser user = appUserRepository.findById(TenantContext.getCurrentUserId()).orElseThrow();
        user.setRole("CA_PARTNER");
        user.setCaFirmId(firm.getId());
        user.setDefaultLandingPage("/ca");
        appUserRepository.save(user);
        featureFlagService.enable(TenantContext.getCurrentOrgId(), ModuleCode.CA_CONSOLE);
        return toResponse(firm);
    }

    @Transactional(readOnly = true)
    public CaFirmResponse current() {
        return caFirmRepository.findByOrgIdAndActiveTrue(TenantContext.getCurrentOrgId())
                .map(this::toResponse)
                .orElse(null);
    }

    private CaFirmResponse toResponse(CaFirm firm) {
        return new CaFirmResponse(firm.getId(), firm.getOrgId(), firm.getFirmName(), firm.getIcaiNumber(), firm.isActive());
    }
}
