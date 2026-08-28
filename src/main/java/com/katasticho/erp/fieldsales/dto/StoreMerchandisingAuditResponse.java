package com.katasticho.erp.fieldsales.dto;

import com.katasticho.erp.fieldsales.entity.MerchandisingAuditType;
import com.katasticho.erp.fieldsales.entity.PlanogramCompliance;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record StoreMerchandisingAuditResponse(
        UUID id,
        UUID fieldVisitId,
        UUID routeExecutionId,
        UUID contactId,
        String customerName,
        UUID salespersonId,
        String salespersonName,
        MerchandisingAuditType auditType,
        String photoUrl,
        BigDecimal shelfSharePct,
        Integer facingCount,
        boolean isStockOut,
        String competitorBrandNames,
        PlanogramCompliance planogramCompliance,
        String notes,
        Instant auditedAt
) {}
