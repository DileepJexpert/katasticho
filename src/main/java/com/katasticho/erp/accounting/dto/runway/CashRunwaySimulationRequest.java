package com.katasticho.erp.accounting.dto.runway;

import java.math.BigDecimal;
import java.util.Map;

public record CashRunwaySimulationRequest(
        Integer arDelayDays,
        Integer apExtensionDays,
        Double arCollectionEfficiency,
        Double revenueAdjustmentPct,
        Map<Integer, BigDecimal> plannedCapexByWeek
) {}