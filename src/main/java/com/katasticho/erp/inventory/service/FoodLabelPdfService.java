package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.DocumentPdfService;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

/**
 * FSSAI-compliant food label PDF generator. Renders the print-ready
 * label every Indian retail food pack legally needs to display under
 * FSSAI 2.4 (Labelling Regulations) + 2.2.2 (Nutritional Information):
 *
 * <ul>
 *   <li>Product name + brand (item name)</li>
 *   <li>Veg/non-veg dot or triangle — the mandatory coloured symbol</li>
 *   <li>Allergen declaration: "Contains: …" + traces line</li>
 *   <li>Nutritional information table (per 100g/100ml + per serving)</li>
 *   <li>Date marking type + MFG date + computed expiry from shelf life</li>
 *   <li>Batch / lot number (when a batch is supplied)</li>
 *   <li>Net quantity (item.unitOfMeasure)</li>
 *   <li>FBO license (14-digit FSSAI number)</li>
 *   <li>Manufacturer name + address</li>
 *   <li>Footer note: "For consumer queries…" + system attribution</li>
 * </ul>
 *
 * <p>Pulls the HTML→PDF rendering pass through the shared
 * {@link DocumentPdfService} (open-html-to-pdf). Same pattern as
 * {@code BmrPdfService} so the layout pipeline stays consistent.
 */
@Service
@RequiredArgsConstructor
public class FoodLabelPdfService {

    private static final DateTimeFormatter DATE_FMT =
            DateTimeFormatter.ofPattern("dd MMM yyyy", Locale.ENGLISH);

    private final ItemRepository itemRepository;
    private final StockBatchRepository stockBatchRepository;
    private final OrganisationRepository organisationRepository;
    private final DocumentPdfService pdfService;

    /**
     * Render the label PDF for an item, optionally tied to a specific
     * stock batch. When {@code batchId} is null we render a "master
     * label" with placeholder dates — useful for proof printing
     * before a batch exists.
     */
    @Transactional(readOnly = true)
    public byte[] generateLabel(UUID itemId, UUID batchId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", itemId));
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        StockBatch batch = null;
        if (batchId != null) {
            batch = stockBatchRepository.findByIdAndOrgIdAndIsDeletedFalse(batchId, orgId)
                    .orElseThrow(() -> BusinessException.notFound("StockBatch", batchId));
            if (!batch.getItemId().equals(itemId)) {
                throw new BusinessException(
                        "Batch does not belong to this item",
                        "FSSAI_LABEL_BATCH_ITEM_MISMATCH",
                        HttpStatus.BAD_REQUEST);
            }
        }

        return pdfService.render(buildHtml(item, org, batch));
    }

    public static String filename(Item item, StockBatch batch) {
        String safeName = item.getName() == null
                ? item.getSku() : item.getName().replaceAll("[/\\\\:*?\"<>|]", "-");
        String suffix = batch == null ? "" : "-" + batch.getBatchNumber()
                .replaceAll("[/\\\\:*?\"<>|]", "-");
        return "label-" + safeName + suffix + ".pdf";
    }

    private String buildHtml(Item item, Organisation org, StockBatch batch) {
        StringBuilder sb = new StringBuilder();
        sb.append("<!DOCTYPE html><html><head><meta charset='UTF-8'/><style>");
        sb.append(css());
        sb.append("</style></head><body>");
        sb.append("<div class='label'>");

        productHeader(sb, item);
        vegMark(sb, item.getVegClassification());
        allergens(sb, item.getAllergens());
        nutrition(sb, item.getNutritionalInfo());
        manufacturingInfo(sb, item, batch);
        compliance(sb, item, org);
        footer(sb);

        sb.append("</div></body></html>");
        return sb.toString();
    }

    private void productHeader(StringBuilder sb, Item item) {
        sb.append("<div class='product'>");
        sb.append("<div class='product-name'>")
          .append(escape(item.getName()))
          .append("</div>");
        if (item.getComposition() != null && !item.getComposition().isBlank()) {
            sb.append("<div class='composition'>")
              .append(escape(item.getComposition()))
              .append("</div>");
        }
        sb.append("</div>");
    }

    private void vegMark(StringBuilder sb, String vegClass) {
        // The FSSAI mark is the symbol every consumer instinctively
        // looks for. We render the right colour swatch + label.
        sb.append("<div class='veg-row'>");
        switch (vegClass == null ? "" : vegClass) {
            case "VEGETARIAN" -> sb.append("<span class='veg-mark veg'></span> <b>Vegetarian</b>");
            case "NON_VEGETARIAN" -> sb.append("<span class='veg-mark nonveg'></span> <b>Non-Vegetarian</b>");
            case "VEGAN" -> sb.append("<span class='veg-mark vegan'></span> <b>Vegan</b>");
            case "EGG" -> sb.append("<span class='veg-mark egg'></span> <b>Contains Egg</b>");
            default -> sb.append("<span class='veg-mark unknown'></span> <i>Veg classification not declared</i>");
        }
        sb.append("</div>");
    }

    private void allergens(StringBuilder sb, List<String> allergens) {
        sb.append("<div class='section-title'>Allergens</div>");
        if (allergens == null) {
            sb.append("<div class='warn'>Not declared — required by FSSAI 2.2.2.4 before sale.</div>");
        } else if (allergens.isEmpty()) {
            sb.append("<div class='ok'>None of the major allergens listed under FSSAI 2.2.2.4.</div>");
        } else {
            sb.append("<div class='contains'>Contains: <b>")
              .append(escape(prettyAllergens(allergens)))
              .append("</b></div>");
        }
    }

    private void nutrition(StringBuilder sb, Map<String, Object> nutritionalInfo) {
        sb.append("<div class='section-title'>Nutritional Information</div>");
        if (nutritionalInfo == null || nutritionalInfo.isEmpty()) {
            sb.append("<div class='warn'>Not declared — required by FSSAI 2.2.2.1 per 100 g / 100 ml.</div>");
            return;
        }
        sb.append("<table class='nutrition'>");
        sb.append("<tr><th>Nutrient</th><th>Value</th></tr>");
        for (Map.Entry<String, Object> entry : nutritionalInfo.entrySet()) {
            sb.append("<tr><td>")
              .append(escape(prettyNutrientKey(entry.getKey())))
              .append("</td><td>")
              .append(escape(String.valueOf(entry.getValue())))
              .append("</td></tr>");
        }
        sb.append("</table>");
    }

    private void manufacturingInfo(StringBuilder sb, Item item, StockBatch batch) {
        sb.append("<div class='section-title'>Manufacturing &amp; Date Marking</div>");
        sb.append("<table class='kv-table'>");

        if (batch != null) {
            sb.append(rowHtml("Batch / Lot No.", batch.getBatchNumber()));
            if (batch.getManufacturingDate() != null) {
                sb.append(rowHtml("MFG Date", DATE_FMT.format(batch.getManufacturingDate())));
            }
        }

        // Compute expiry: explicit batch expiry wins; otherwise
        // MFG + shelf_life when both are available; otherwise blank.
        LocalDate expiry = batch != null ? batch.getExpiryDate() : null;
        if (expiry == null && batch != null && batch.getManufacturingDate() != null
                && item.getShelfLifeDays() != null) {
            expiry = batch.getManufacturingDate().plusDays(item.getShelfLifeDays());
        }

        String marking = item.getDateMarkingType() != null
                ? item.getDateMarkingType().replace("_", " ")
                : "Best Before";
        if (expiry != null) {
            sb.append(rowHtml(marking, DATE_FMT.format(expiry)));
        } else if (item.getShelfLifeDays() != null) {
            sb.append(rowHtml(marking,
                    item.getShelfLifeDays() + " days from manufacture"));
        }

        if (item.getUnitOfMeasure() != null) {
            sb.append(rowHtml("Net Quantity", item.getUnitOfMeasure()));
        }
        sb.append("</table>");
    }

    private void compliance(StringBuilder sb, Item item, Organisation org) {
        sb.append("<div class='section-title'>Compliance &amp; Manufacturer</div>");
        sb.append("<table class='kv-table'>");
        String licence = item.getFssaiLicense() != null
                ? item.getFssaiLicense() : org.getFssaiLicense();
        if (licence != null && !licence.isBlank()) {
            sb.append(rowHtml("FSSAI License", licence));
        } else {
            sb.append("<tr><td><b>FSSAI License</b></td>")
              .append("<td class='warn'>Not declared — required by Regulation 2.2.2.7</td></tr>");
        }
        sb.append(rowHtml("Manufacturer", org.getName()));
        String addr = joinAddress(org);
        if (!addr.isBlank()) {
            sb.append(rowHtml("Address", addr));
        }
        if (org.getGstin() != null) {
            sb.append(rowHtml("GSTIN", org.getGstin()));
        }
        sb.append("</table>");
    }

    private void footer(StringBuilder sb) {
        sb.append("<div class='footer'>")
          .append("For consumer queries, contact the manufacturer at the address above.<br/>")
          .append("Generated by Katasticho ERP &mdash; FSSAI 2.4 label compliant.")
          .append("</div>");
    }

    // ── helpers ──────────────────────────────────────────────────────

    private String rowHtml(String k, Object v) {
        return "<tr><td><b>" + escape(k) + "</b></td><td>"
                + (v == null ? "&mdash;" : escape(String.valueOf(v))) + "</td></tr>";
    }

    private String prettyAllergens(List<String> allergens) {
        return allergens.stream()
                .map(this::prettyAllergen)
                .reduce((a, b) -> a + ", " + b)
                .orElse("");
    }

    private String prettyAllergen(String code) {
        return switch (code) {
            case "MILK" -> "Milk";
            case "EGGS" -> "Eggs";
            case "FISH" -> "Fish";
            case "CRUSTACEAN_SHELLFISH" -> "Crustacean Shellfish";
            case "TREE_NUTS" -> "Tree Nuts";
            case "PEANUTS" -> "Peanuts";
            case "WHEAT_GLUTEN" -> "Wheat / Gluten";
            case "SOYBEANS" -> "Soybeans";
            case "MUSTARD" -> "Mustard";
            case "SESAME" -> "Sesame";
            case "CELERY" -> "Celery";
            case "LUPIN" -> "Lupin";
            case "MOLLUSCS" -> "Molluscs";
            case "SULPHITES" -> "Sulphites";
            default -> code.replace("_", " ");
        };
    }

    private String prettyNutrientKey(String key) {
        // calories_kcal -> "Energy (kcal)"; protein_g -> "Protein (g)"
        if (key == null) return "—";
        String[] parts = key.split("_");
        if (parts.length == 1) return capitalise(parts[0]);
        String unit = parts[parts.length - 1];
        StringBuilder name = new StringBuilder();
        for (int i = 0; i < parts.length - 1; i++) {
            if (i > 0) name.append(' ');
            // FSSAI 2.2.2.1 calls calories "Energy" on the label.
            String word = parts[i];
            name.append("calories".equalsIgnoreCase(word)
                    ? "Energy" : capitalise(word));
        }
        return name.toString() + " (" + unit + ")";
    }

    private String capitalise(String s) {
        if (s == null || s.isEmpty()) return s;
        return Character.toUpperCase(s.charAt(0)) + s.substring(1);
    }

    private String joinAddress(Organisation org) {
        StringBuilder sb = new StringBuilder();
        if (org.getAddressLine1() != null) sb.append(org.getAddressLine1());
        if (org.getAddressLine2() != null) {
            if (!sb.isEmpty()) sb.append(", ");
            sb.append(org.getAddressLine2());
        }
        return sb.toString();
    }

    private String escape(String s) {
        if (s == null) return "—";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }

    private String css() {
        return """
            @page { size: A6; margin: 0.8cm; }
            body { font-family: 'Helvetica', sans-serif; font-size: 9pt; color: #222; }
            .label { border: 1pt solid #333; padding: 8pt; }
            .product-name { font-size: 13pt; font-weight: bold; text-align: center; }
            .composition { text-align: center; color: #666; font-size: 9pt; margin-top: 2pt; }
            .section-title { background: #f0f4f7; padding: 4pt; font-weight: bold;
                             margin-top: 6pt; font-size: 9.5pt; color: #1f4e79; }
            .veg-row { margin-top: 6pt; font-size: 10pt; }
            .veg-mark { display: inline-block; width: 12pt; height: 12pt; vertical-align: middle;
                        border: 1.5pt solid #000; margin-right: 4pt; }
            .veg-mark.veg { background: #1b8a3a; }
            .veg-mark.nonveg { background: #c0392b; }
            .veg-mark.vegan { background: #1b8a3a; border-style: dashed; }
            .veg-mark.egg { background: #f1c40f; }
            .veg-mark.unknown { background: #ddd; }
            .contains { margin-top: 4pt; padding: 4pt; background: #fdecea; border-left: 3pt solid #c0392b; }
            .ok { margin-top: 4pt; color: #1b8a3a; }
            .warn { margin-top: 4pt; color: #c0392b; font-style: italic; }
            table.nutrition, table.kv-table { width: 100%; border-collapse: collapse; margin-top: 4pt; font-size: 9pt; }
            table.nutrition th, table.nutrition td, table.kv-table td {
                border: 1px solid #ccc; padding: 3pt 5pt;
            }
            table.nutrition th { background: #f5f5f5; text-align: left; }
            .footer { margin-top: 10pt; padding-top: 4pt; border-top: 1px dashed #aaa;
                      font-size: 7.5pt; color: #888; text-align: center; }
        """;
    }
}
