package com.katasticho.erp.platform.dto;

import com.katasticho.erp.organisation.Organisation;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record PlatformOrgDetailResponse(
        UUID id,
        String name,
        String phone,
        String email,
        String businessType,
        String industryCode,
        List<String> subCategories,
        String planTier,
        String approvalStatus,
        String approvalNote,
        Instant createdAt,
        Instant approvedAt,
        boolean active,
        List<String> enabledModules,
        List<String> enabledFeatures,
        List<RecentAdminAction> recentAdminActions
) {
    public static PlatformOrgDetailResponse from(
            Organisation org,
            List<String> enabledModules,
            List<String> enabledFeatures,
            List<RecentAdminAction> recentAdminActions
    ) {
        return new PlatformOrgDetailResponse(
                org.getId(),
                org.getName(),
                org.getPhone(),
                org.getEmail(),
                org.getBusinessType(),
                org.getIndustryCode(),
                org.getSubCategories(),
                org.getPlanTier(),
                org.getApprovalStatus(),
                org.getApprovalNote(),
                org.getCreatedAt(),
                org.getApprovedAt(),
                org.isActive(),
                enabledModules,
                enabledFeatures,
                recentAdminActions
        );
    }

    public record RecentAdminAction(
            String actionType,
            String targetName,
            String reason,
            Instant performedAt
    ) {}
}
