package com.katasticho.erp.pharma.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.pharma.dto.DrugLicenseRequest;
import com.katasticho.erp.pharma.dto.DrugLicenseResponse;
import com.katasticho.erp.pharma.entity.DrugLicense;
import com.katasticho.erp.pharma.repository.DrugLicenseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class DrugLicenseService {

    private final DrugLicenseRepository drugLicenseRepository;

    @Transactional
    public DrugLicenseResponse create(DrugLicenseRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        DrugLicense license = DrugLicense.builder()
                .licenseType(request.licenseType())
                .licenseNumber(request.licenseNumber())
                .issuedBy(request.issuedBy())
                .issueDate(request.issueDate())
                .expiryDate(request.expiryDate())
                .notes(request.notes())
                .build();
        license.setOrgId(orgId);
        return toResponse(drugLicenseRepository.save(license));
    }

    @Transactional
    public DrugLicenseResponse update(UUID id, DrugLicenseRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        DrugLicense license = drugLicenseRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("DrugLicense", id));
        license.setLicenseType(request.licenseType());
        license.setLicenseNumber(request.licenseNumber());
        license.setIssuedBy(request.issuedBy());
        license.setIssueDate(request.issueDate());
        license.setExpiryDate(request.expiryDate());
        license.setNotes(request.notes());
        return toResponse(drugLicenseRepository.save(license));
    }

    @Transactional
    public void delete(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        DrugLicense license = drugLicenseRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("DrugLicense", id));
        license.setDeleted(true);
        drugLicenseRepository.save(license);
    }

    @Transactional(readOnly = true)
    public List<DrugLicenseResponse> list() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return drugLicenseRepository.findByOrgIdAndIsDeletedFalseOrderByExpiryDateAsc(orgId)
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<DrugLicenseResponse> getExpiring(int withinDays) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();
        LocalDate threshold = today.plusDays(withinDays);
        return drugLicenseRepository.findExpiringWithin(orgId, today, threshold)
                .stream().map(this::toResponse).toList();
    }

    private DrugLicenseResponse toResponse(DrugLicense license) {
        long days = ChronoUnit.DAYS.between(LocalDate.now(), license.getExpiryDate());
        String status;
        if (days < 0) {
            status = "EXPIRED";
        } else if (days <= 30) {
            status = "CRITICAL";
        } else if (days <= 90) {
            status = "WARNING";
        } else {
            status = "OK";
        }
        return new DrugLicenseResponse(
                license.getId(),
                license.getLicenseType(),
                license.getLicenseNumber(),
                license.getIssuedBy(),
                license.getIssueDate(),
                license.getExpiryDate(),
                license.getNotes(),
                (int) days,
                status
        );
    }
}
