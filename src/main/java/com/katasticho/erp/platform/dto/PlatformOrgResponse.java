package com.katasticho.erp.platform.dto;

import com.katasticho.erp.organisation.Organisation;

import java.time.Instant;
import java.util.UUID;

public record PlatformOrgResponse(
        UUID id,
        String name,
        String phone,
        String email,
        String businessType,
        String industryCode,
        String planTier,
        String approvalStatus,
        String approvalNote,
        Instant createdAt,
        Instant approvedAt
) {
    public static PlatformOrgResponse from(Organisation org) {
        return new PlatformOrgResponse(
                org.getId(),
                org.getName(),
                org.getPhone(),
                org.getEmail(),
                org.getBusinessType(),
                org.getIndustryCode(),
                org.getPlanTier(),
                org.getApprovalStatus(),
                org.getApprovalNote(),
                org.getCreatedAt(),
                org.getApprovedAt()
        );
    }
}
