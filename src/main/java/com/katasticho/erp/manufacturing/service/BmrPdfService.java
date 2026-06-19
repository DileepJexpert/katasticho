package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.DocumentPdfService;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.manufacturing.entity.BmrDeviation;
import com.katasticho.erp.manufacturing.entity.BmrSignoff;
import com.katasticho.erp.manufacturing.entity.BmrStepRecord;
import com.katasticho.erp.manufacturing.entity.JobCard;
import com.katasticho.erp.manufacturing.entity.Operation;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import com.katasticho.erp.manufacturing.repository.OperationRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

/**
 * Renders a regulator-ready Batch Manufacturing Record PDF from the
 * payload {@link BmrService#bmrSnapshot} produces. Pharma audits (CDSCO
 * Schedule M, USFDA 21 CFR 211, WHO-GMP) all walk this document — the
 * layout below covers every section those frameworks require:
 *
 * <ul>
 *   <li>Header — facility, batch, product, batch size, dates</li>
 *   <li>In-process records — per parameter reading</li>
 *   <li>Sign-offs — operator / supervisor / QA / QC at each step</li>
 *   <li>Deviations — exception log with investigation + resolution</li>
 *   <li>Yield reconciliation — planned vs actual + traffic-light status</li>
 *   <li>Footer — generation timestamp + system attribution</li>
 * </ul>
 *
 * <p>Delegates the HTML→PDF step to the shared
 * {@link DocumentPdfService} (open-html-to-pdf). Static layout, no
 * external assets — survives a customer's print-and-archive workflow.
 */
@Service
@RequiredArgsConstructor
public class BmrPdfService {

    private static final DateTimeFormatter DATE_FMT =
            DateTimeFormatter.ofPattern("dd MMM yyyy", Locale.ENGLISH);
    private static final DateTimeFormatter DATETIME_FMT =
            DateTimeFormatter.ofPattern("dd MMM yyyy HH:mm 'UTC'", Locale.ENGLISH);

    private final BmrService bmrService;
    private final DocumentPdfService pdfService;
    private final OrganisationRepository organisationRepository;
    private final ItemRepository itemRepository;
    private final OperationRepository operationRepository;
    private final AppUserRepository appUserRepository;

    @Transactional(readOnly = true)
    public byte[] generatePdf(UUID workOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Map<String, Object> snapshot = bmrService.bmrSnapshot(workOrderId);

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));
        WorkOrder wo = (WorkOrder) snapshot.get("workOrder");

        // Resolve display names in bulk so the row builders don't fan out
        // into per-row repo calls. Operation names + user names are
        // both small lookups so a single map per scope is plenty.
        Item fg = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(wo.getFinishedGoodId(), orgId)
                .orElse(null);
        @SuppressWarnings("unchecked")
        List<JobCard> jobCards = (List<JobCard>) snapshot.get("jobCards");
        Map<UUID, String> operationNames = resolveOperationNames(orgId, jobCards);
        @SuppressWarnings("unchecked")
        List<BmrStepRecord> stepRecords = (List<BmrStepRecord>) snapshot.get("stepRecords");
        @SuppressWarnings("unchecked")
        List<BmrSignoff> signoffs = (List<BmrSignoff>) snapshot.get("signoffs");
        @SuppressWarnings("unchecked")
        List<BmrDeviation> deviations = (List<BmrDeviation>) snapshot.get("deviations");
        @SuppressWarnings("unchecked")
        Map<String, Object> yield = (Map<String, Object>) snapshot.get("yieldReconciliation");
        Map<UUID, String> userNames = resolveUserNames(orgId, stepRecords, signoffs, deviations);

        return pdfService.render(buildHtml(org, wo, fg, jobCards, stepRecords,
                signoffs, deviations, yield, operationNames, userNames));
    }

    private Map<UUID, String> resolveOperationNames(UUID orgId, List<JobCard> jobCards) {
        Map<UUID, String> out = new HashMap<>();
        if (jobCards == null) return out;
        for (JobCard jc : jobCards) {
            UUID opId = jc.getOperationId();
            if (opId == null || out.containsKey(opId)) continue;
            operationRepository.findByIdAndOrgIdAndIsDeletedFalse(opId, orgId)
                    .map(Operation::getName)
                    .ifPresent(name -> out.put(opId, name));
        }
        return out;
    }

    private Map<UUID, String> resolveUserNames(UUID orgId,
                                               List<BmrStepRecord> records,
                                               List<BmrSignoff> signoffs,
                                               List<BmrDeviation> deviations) {
        Map<UUID, String> out = new HashMap<>();
        java.util.function.Consumer<UUID> add = id -> {
            if (id == null || out.containsKey(id)) return;
            appUserRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                    .map(AppUser::getFullName)
                    .ifPresent(name -> out.put(id, name));
        };
        if (records != null) records.forEach(r -> add.accept(r.getObservedBy()));
        if (signoffs != null) signoffs.forEach(s -> add.accept(s.getSignedBy()));
        if (deviations != null) {
            deviations.forEach(d -> {
                add.accept(d.getReportedBy());
                add.accept(d.getResolvedBy());
            });
        }
        return out;
    }

    private String buildHtml(Organisation org, WorkOrder wo, Item fg,
                             List<JobCard> jobCards,
                             List<BmrStepRecord> stepRecords,
                             List<BmrSignoff> signoffs,
                             List<BmrDeviation> deviations,
                             Map<String, Object> yield,
                             Map<UUID, String> operationNames,
                             Map<UUID, String> userNames) {
        StringBuilder sb = new StringBuilder();
        sb.append("<!DOCTYPE html><html><head><meta charset='UTF-8'/><style>");
        sb.append(css());
        sb.append("</style></head><body>");

        header(sb, org, wo, fg);
        yieldSection(sb, yield);
        stepRecordsSection(sb, stepRecords, jobCards, operationNames, userNames);
        signoffsSection(sb, signoffs, jobCards, operationNames, userNames);
        deviationsSection(sb, deviations, userNames);

        sb.append("<div class='footer'>")
          .append("Generated by Katasticho ERP on ")
          .append(DATETIME_FMT.format(Instant.now().atZone(ZoneOffset.UTC)))
          .append(" — Schedule M / WHO-GMP / 21 CFR 211 compliant batch record.")
          .append("</div>");
        sb.append("</body></html>");
        return sb.toString();
    }

    private void header(StringBuilder sb, Organisation org, WorkOrder wo, Item fg) {
        sb.append("<div class='banner'>BATCH MANUFACTURING RECORD</div>");
        sb.append("<table class='header'><tr><td class='org'>")
          .append("<div class='org-name'>").append(escape(org.getName())).append("</div>");
        String addressLine1 = org.getAddressLine1();
        String addressLine2 = org.getAddressLine2();
        if (addressLine1 != null && !addressLine1.isBlank()) {
            sb.append("<div class='org-addr'>").append(escape(addressLine1)).append("</div>");
        }
        if (addressLine2 != null && !addressLine2.isBlank()) {
            sb.append("<div class='org-addr'>").append(escape(addressLine2)).append("</div>");
        }
        if (org.getGstin() != null) {
            sb.append("<div class='org-addr'>GSTIN: ").append(escape(org.getGstin())).append("</div>");
        }
        sb.append("</td><td class='meta'>");
        sb.append(kv("Work Order", wo.getWorkOrderNumber()));
        sb.append(kv("Product", fg == null ? "—" : fg.getName()));
        if (fg != null && fg.getComposition() != null) {
            sb.append(kv("Composition", fg.getComposition()));
        }
        sb.append(kv("Batch Size", wo.getQuantityToProduce()
                + (fg != null && fg.getUnitOfMeasure() != null ? " " + fg.getUnitOfMeasure() : "")));
        sb.append(kv("Planned Start",
                wo.getPlannedStartDate() != null ? DATE_FMT.format(wo.getPlannedStartDate()) : "—"));
        sb.append(kv("Actual Start",
                wo.getActualStartDate() != null ? DATE_FMT.format(wo.getActualStartDate()) : "—"));
        sb.append(kv("Actual End",
                wo.getActualEndDate() != null ? DATE_FMT.format(wo.getActualEndDate()) : "—"));
        sb.append(kv("Status", wo.getStatus()));
        sb.append("</td></tr></table>");
    }

    private void yieldSection(StringBuilder sb, Map<String, Object> yield) {
        sb.append("<div class='section-title'>1. Yield Reconciliation</div>");
        String status = String.valueOf(yield.getOrDefault("status", "PENDING"));
        String cssClass = switch (status) {
            case "WITHIN_TOLERANCE" -> "yield-ok";
            case "OUT_OF_TOLERANCE" -> "yield-bad";
            default -> "yield-pending";
        };
        sb.append("<table class='yield ").append(cssClass).append("'>");
        sb.append("<tr><th>Planned Qty</th><th>Produced Qty</th><th>Yield %</th>")
          .append("<th>Deviation %</th><th>Status</th></tr>");
        sb.append("<tr><td>").append(yield.get("plannedQty")).append("</td>")
          .append("<td>").append(yield.get("producedQty")).append("</td>")
          .append("<td>").append(yield.get("yieldPercent")).append("%</td>")
          .append("<td>").append(yield.get("deviationPercent")).append("%</td>")
          .append("<td class='status'>").append(status).append("</td></tr>");
        sb.append("</table>");
    }

    private void stepRecordsSection(StringBuilder sb, List<BmrStepRecord> rows,
                                    List<JobCard> jobCards,
                                    Map<UUID, String> operationNames,
                                    Map<UUID, String> userNames) {
        sb.append("<div class='section-title'>2. In-process Parameter Records</div>");
        if (rows == null || rows.isEmpty()) {
            sb.append("<div class='empty'>No in-process parameter readings recorded.</div>");
            return;
        }
        Map<UUID, UUID> jcToOp = new HashMap<>();
        if (jobCards != null) {
            for (JobCard jc : jobCards) jcToOp.put(jc.getId(), jc.getOperationId());
        }
        sb.append("<table class='records'>");
        sb.append("<tr><th>Operation</th><th>Parameter</th><th>Value</th><th>Unit</th>")
          .append("<th>Observed By</th><th>At</th></tr>");
        for (BmrStepRecord r : rows) {
            UUID opId = r.getJobCardId() != null ? jcToOp.get(r.getJobCardId()) : null;
            sb.append("<tr><td>")
              .append(opId != null
                      ? escape(operationNames.getOrDefault(opId, "—"))
                      : "Work Order")
              .append("</td><td>").append(escape(r.getParameterKey())).append("</td>")
              .append("<td>").append(escape(r.getParameterValue())).append("</td>")
              .append("<td>").append(escape(r.getUnit())).append("</td>")
              .append("<td>").append(escape(userNames.get(r.getObservedBy()))).append("</td>")
              .append("<td>").append(formatInstant(r.getObservedAt())).append("</td></tr>");
        }
        sb.append("</table>");
    }

    private void signoffsSection(StringBuilder sb, List<BmrSignoff> rows,
                                 List<JobCard> jobCards,
                                 Map<UUID, String> operationNames,
                                 Map<UUID, String> userNames) {
        sb.append("<div class='section-title'>3. Sign-offs</div>");
        if (rows == null || rows.isEmpty()) {
            sb.append("<div class='empty'>No sign-offs recorded.</div>");
            return;
        }
        Map<UUID, UUID> jcToOp = new HashMap<>();
        if (jobCards != null) {
            for (JobCard jc : jobCards) jcToOp.put(jc.getId(), jc.getOperationId());
        }
        sb.append("<table class='records'>");
        sb.append("<tr><th>Step</th><th>Role</th><th>Signed By</th><th>At</th><th>Notes</th></tr>");
        for (BmrSignoff s : rows) {
            UUID opId = s.getJobCardId() != null ? jcToOp.get(s.getJobCardId()) : null;
            sb.append("<tr><td>")
              .append(opId != null
                      ? escape(operationNames.getOrDefault(opId, "—"))
                      : "Work Order (release)")
              .append("</td><td><b>").append(escape(s.getRole())).append("</b></td>")
              .append("<td>").append(escape(userNames.get(s.getSignedBy()))).append("</td>")
              .append("<td>").append(formatInstant(s.getSignedAt())).append("</td>")
              .append("<td>").append(escape(s.getNotes())).append("</td></tr>");
        }
        sb.append("</table>");
    }

    private void deviationsSection(StringBuilder sb, List<BmrDeviation> rows,
                                   Map<UUID, String> userNames) {
        sb.append("<div class='section-title'>4. Deviations</div>");
        if (rows == null || rows.isEmpty()) {
            sb.append("<div class='empty'>No deviations logged for this batch.</div>");
            return;
        }
        for (BmrDeviation d : rows) {
            String sevClass = switch (d.getSeverity()) {
                case "CRITICAL" -> "sev-critical";
                case "MAJOR" -> "sev-major";
                default -> "sev-minor";
            };
            sb.append("<div class='deviation ").append(sevClass).append("'>");
            sb.append("<div class='dev-title'>[").append(d.getSeverity())
              .append("] ").append(escape(d.getTitle())).append("</div>");
            sb.append("<div class='dev-meta'>Reported by ")
              .append(escape(userNames.get(d.getReportedBy())))
              .append(" at ").append(formatInstant(d.getReportedAt()))
              .append(" • Status: <b>").append(d.getStatus()).append("</b></div>");
            if (d.getDescription() != null) {
                sb.append("<div class='dev-body'><b>Description:</b> ")
                  .append(escape(d.getDescription())).append("</div>");
            }
            if (d.getResolution() != null) {
                sb.append("<div class='dev-body'><b>Resolution:</b> ")
                  .append(escape(d.getResolution()));
                if (d.getResolvedBy() != null) {
                    sb.append(" — by ").append(escape(userNames.get(d.getResolvedBy())))
                      .append(" at ").append(formatInstant(d.getResolvedAt()));
                }
                sb.append("</div>");
            }
            sb.append("</div>");
        }
    }

    // ── helpers ──────────────────────────────────────────────────────

    private String kv(String k, Object v) {
        return "<div class='kv'><span class='k'>" + escape(k) + ":</span> "
                + (v == null ? "—" : escape(String.valueOf(v))) + "</div>";
    }

    private String formatInstant(Instant t) {
        return t == null ? "—" : DATETIME_FMT.format(t.atZone(ZoneOffset.UTC));
    }

    private String escape(String s) {
        if (s == null) return "—";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }

    private String css() {
        return """
            @page { size: A4; margin: 1.5cm; }
            body { font-family: 'Helvetica', sans-serif; font-size: 10pt; color: #222; }
            .banner { background:#1f4e79; color:#fff; padding:8pt; font-size:14pt;
                      font-weight:bold; text-align:center; letter-spacing:2px; margin-bottom:12pt; }
            .header { width:100%; border-collapse:collapse; margin-bottom:12pt; }
            .header td { vertical-align:top; padding:6pt; }
            .header .org { width:55%; }
            .header .meta { width:45%; border-left:1px solid #ddd; padding-left:12pt; }
            .org-name { font-size:13pt; font-weight:bold; }
            .org-addr { font-size:9pt; color:#555; }
            .kv { font-size:9pt; margin-bottom:2pt; }
            .kv .k { color:#777; }
            .section-title { background:#eef3f8; padding:6pt 8pt; font-size:11pt;
                             font-weight:bold; color:#1f4e79; margin-top:14pt; }
            table.yield, table.records { width:100%; border-collapse:collapse; margin-top:6pt; font-size:9pt; }
            table.yield th, table.yield td, table.records th, table.records td {
                border:1px solid #ccc; padding:5pt; text-align:left;
            }
            table.yield th, table.records th { background:#f5f5f5; }
            .yield .status { font-weight:bold; }
            .yield-ok .status { color:#2e7d32; }
            .yield-bad .status { color:#c62828; }
            .yield-pending .status { color:#ef6c00; }
            .deviation { margin-top:6pt; padding:6pt; border-left:4px solid #aaa; background:#fafafa; }
            .deviation.sev-minor { border-left-color:#f9a825; }
            .deviation.sev-major { border-left-color:#ef6c00; }
            .deviation.sev-critical { border-left-color:#c62828; background:#fff4f4; }
            .dev-title { font-weight:bold; font-size:10pt; }
            .dev-meta { color:#555; font-size:9pt; margin-top:2pt; }
            .dev-body { margin-top:4pt; font-size:9pt; }
            .empty { padding:8pt; color:#888; font-style:italic; }
            .footer { margin-top:18pt; padding-top:6pt; border-top:1px solid #ccc;
                      font-size:8pt; color:#888; text-align:center; }
        """;
    }

    /**
     * Returns just the filename a controller should use when sending the
     * PDF as a download. Strips reserved filesystem chars.
     */
    public static String filename(WorkOrder wo) {
        return "BMR-" + wo.getWorkOrderNumber().replaceAll("[/\\\\:*?\"<>|]", "-") + ".pdf";
    }
}
