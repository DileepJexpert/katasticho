package com.katasticho.erp.fieldsales.dto;

import com.katasticho.erp.fieldsales.entity.MerchandisingAuditType;
import com.katasticho.erp.fieldsales.entity.PlanogramCompliance;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record StoreMerchandisingAuditRequest(
        @NotNull(message = "Field visit ID is required")
        UUID fieldVisitId,

        @NotNull(message = "Route execution ID is required")
        UUID routeExecutionId,

        @NotNull(message = "Contact ID is required")
        UUID contactId,

        MerchandisingAuditType auditType,
        String photoUrl,
        BigDecimal shelfSharePct,
        Integer facingCount,
        Boolean isStockOut,
        String competitorBrandNames,
        PlanogramCompliance planogramCompliance,
        String notes
) {}
