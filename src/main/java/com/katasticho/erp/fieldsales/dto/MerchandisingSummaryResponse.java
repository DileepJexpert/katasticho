package com.katasticho.erp.fieldsales.dto;

import com.katasticho.erp.fieldsales.entity.MerchandisingAuditType;
import com.katasticho.erp.fieldsales.entity.PlanogramCompliance;

import java.math.BigDecimal;
import java.util.Map;

public record MerchandisingSummaryResponse(
        long totalAudits,
        long totalPhotosCaptured,
        BigDecimal averageShelfSharePct,
        double complianceRatePct,
        long stockOutCount,
        Map<MerchandisingAuditType, Long> auditsByType,
        Map<PlanogramCompliance, Long> auditsByCompliance
) {}
