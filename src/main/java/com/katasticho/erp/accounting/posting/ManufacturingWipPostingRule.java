package com.katasticho.erp.accounting.posting;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/**
 * Posts WIP journal entries at two points in the work order lifecycle:
 *
 * Issue to production (MANUFACTURING_WIP):
 *   DR WIP Inventory (1210) — raw material cost
 *   DR WIP Inventory (1210) — direct labor cost (if any)
 *   DR WIP Inventory (1210) — overhead cost (if any)
 *   CR Inventory Asset (1200) — raw materials consumed
 *   CR Direct Labor (5040) — labor accrued
 *   CR Manufacturing Overhead (5030) — overhead absorbed
 *
 * FG receipt / completion (MANUFACTURING_COMPLETION):
 *   DR Inventory Asset (1200) — finished goods at cost
 *   CR WIP Inventory (1210) — WIP relieved
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class ManufacturingWipPostingRule implements PostingRuleStrategy {

    private final DefaultAccountService defaultAccountService;

    @Override
    public boolean supports(String sourceType) {
        return PostingContext.MANUFACTURING_WIP.equals(sourceType)
                || PostingContext.MANUFACTURING_COMPLETION.equals(sourceType);
    }

    @Override
    public JournalPostRequest generate(PostingContext context) {
        WorkOrder wo = context.requireWorkOrder();

        if (PostingContext.MANUFACTURING_WIP.equals(context.sourceType())) {
            return generateWipEntry(wo);
        } else {
            return generateCompletionEntry(wo);
        }
    }

    private JournalPostRequest generateWipEntry(WorkOrder wo) {
        List<JournalLineRequest> lines = new ArrayList<>();
        String wipCode = resolveCode(wo, DefaultAccountPurpose.WIP_INVENTORY);

        BigDecimal rmCost = wo.getRawMaterialCost();
        if (rmCost.signum() > 0) {
            lines.add(new JournalLineRequest(wipCode,
                    rmCost, BigDecimal.ZERO,
                    "WIP RM: " + wo.getWorkOrderNumber(), null, null));
            lines.add(new JournalLineRequest(
                    resolveCode(wo, DefaultAccountPurpose.INVENTORY_ASSET),
                    BigDecimal.ZERO, rmCost,
                    "RM consumed: " + wo.getWorkOrderNumber(), null, null));
        }

        BigDecimal laborCost = wo.getDirectLaborCost();
        if (laborCost.signum() > 0) {
            lines.add(new JournalLineRequest(wipCode,
                    laborCost, BigDecimal.ZERO,
                    "WIP Labor: " + wo.getWorkOrderNumber(), null, null));
            lines.add(new JournalLineRequest(
                    resolveCode(wo, DefaultAccountPurpose.DIRECT_LABOR),
                    BigDecimal.ZERO, laborCost,
                    "Labor absorbed: " + wo.getWorkOrderNumber(), null, null));
        }

        BigDecimal overhead = wo.getOverheadCost();
        if (overhead.signum() > 0) {
            lines.add(new JournalLineRequest(wipCode,
                    overhead, BigDecimal.ZERO,
                    "WIP Overhead: " + wo.getWorkOrderNumber(), null, null));
            lines.add(new JournalLineRequest(
                    resolveCode(wo, DefaultAccountPurpose.MANUFACTURING_OVERHEAD),
                    BigDecimal.ZERO, overhead,
                    "Overhead absorbed: " + wo.getWorkOrderNumber(), null, null));
        }

        return new JournalPostRequest(
                wo.getActualStartDate() != null ? wo.getActualStartDate() : LocalDate.now(),
                "WIP Issue: " + wo.getWorkOrderNumber(),
                "MANUFACTURING",
                wo.getId(),
                lines,
                true);
    }

    private JournalPostRequest generateCompletionEntry(WorkOrder wo) {
        List<JournalLineRequest> lines = new ArrayList<>();

        // Relieve WIP by EXACTLY the total cost that was debited to it at issue, and
        // split the DEBIT side between finished-goods inventory and scrap. The old
        // shape credited WIP for totalCost + scrapCost while WIP only ever held
        // totalCost, driving WIP negative by the scrap amount on every scrapped WO.
        BigDecimal scrapCost = calculateMaterialVariance(wo); // >= 0
        BigDecimal fgValue = wo.getTotalCost().subtract(scrapCost);

        if (fgValue.signum() > 0) {
            lines.add(new JournalLineRequest(
                    resolveCode(wo, DefaultAccountPurpose.INVENTORY_ASSET),
                    fgValue, BigDecimal.ZERO,
                    "FG receipt: " + wo.getWorkOrderNumber(), null, null));
        }
        if (scrapCost.signum() > 0) {
            lines.add(new JournalLineRequest(
                    resolveCode(wo, DefaultAccountPurpose.MATERIAL_VARIANCE),
                    scrapCost, BigDecimal.ZERO,
                    "Production scrap: " + wo.getWorkOrderNumber(), null, null));
        }
        lines.add(new JournalLineRequest(
                resolveCode(wo, DefaultAccountPurpose.WIP_INVENTORY),
                BigDecimal.ZERO, wo.getTotalCost(),
                "WIP relieved: " + wo.getWorkOrderNumber(), null, null));

        return new JournalPostRequest(
                wo.getActualEndDate() != null ? wo.getActualEndDate() : LocalDate.now(),
                "FG Completion: " + wo.getWorkOrderNumber(),
                "MANUFACTURING",
                wo.getId(),
                lines,
                true);
    }

    private BigDecimal calculateMaterialVariance(WorkOrder wo) {
        if (wo.getScrapCost() == null) return BigDecimal.ZERO;
        return wo.getScrapCost();
    }

    private String resolveCode(WorkOrder wo, DefaultAccountPurpose purpose) {
        return defaultAccountService.getCode(wo.getOrgId(), purpose);
    }
}
