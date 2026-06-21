package com.katasticho.erp.notification.whatsapp;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Parses an unstructured WhatsApp order message ("200 amul 1L bhej do",
 * "send 5 dolo 500", "10 kg sugar") into structured order lines a sales
 * order can be drafted from. Per the strategic doc this fuses the
 * nFuse/HublerX ordering layer with the accounting layer no one else
 * connects.
 *
 * <p>Parser strategy (deterministic, no LLM required for the common path):
 * <ol>
 *   <li>Split the message by line breaks / commas / "and".</li>
 *   <li>For each segment, find a leading or trailing quantity (with optional
 *       unit) using regex. Bullets / dashes are stripped.</li>
 *   <li>Strip Hindi/regional command words ("bhej", "do", "send", "please")
 *       to leave the product name.</li>
 *   <li>Match the cleaned product name against the org's items via the
 *       existing {@code ItemRepository.search}; return the top candidate
 *       (with all candidates so the UI can show alternates).</li>
 * </ol>
 *
 * <p>Returns a {@link ParsedOrder} record listing each line with a
 * {@code matched} flag and a confidence score so the controller surface can
 * highlight unresolved lines for the cashier.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class WhatsAppOrderService {

    // Real units only — "dolo" or "amul" must NOT match this; they should
    // fall through to the (.+) name group.
    private static final String UNIT = "(kg|kgs|g|gm|gms|gram|grams|l|ltr|litre|liter|ml|"
            + "pcs|pc|piece|pieces|nos|no|pkt|pkts|packet|packets|dz|dozen|box|boxes|"
            + "btl|bottle|bottles|strip|strips|tab|tabs)";
    private static final Pattern QTY_LEAD = Pattern.compile(
            "^\\s*(\\d+(?:[.,]\\d+)?)\\s*" + UNIT + "?\\s+(.+)$",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern QTY_TRAIL = Pattern.compile(
            "^(.+?)\\s+(\\d+(?:[.,]\\d+)?)\\s*" + UNIT + "?\\s*$",
            Pattern.CASE_INSENSITIVE);

    /** Strip these tokens — they're verbs/courtesy, not part of the product name. */
    private static final java.util.Set<String> NOISE = java.util.Set.of(
            "bhej", "bhejo", "bhejna", "bhej-do", "do", "dijiye", "dena", "deijiye",
            "send", "ship", "deliver", "please", "pls", "kripya", "kindly",
            "chahiye", "want", "need", "order", "tikis", "pieces", "pcs", "pkts");

    private final ItemRepository itemRepository;

    /** One parsed order line + its item match. */
    public record ParsedLine(
            String raw,                 // original text segment
            String productNameGuess,    // cleaned name we matched against
            BigDecimal quantity,
            String unitHint,             // unit found inline ("kg", "L", null)
            boolean matched,
            UUID itemId,                 // top item candidate's id, null if unmatched
            String itemName,
            BigDecimal salePrice,
            double confidence,           // 0.0-1.0
            List<Candidate> alternates   // other candidates for the UI to offer
    ) {}

    public record Candidate(UUID itemId, String name, BigDecimal salePrice) {}

    public record ParsedOrder(
            String rawMessage,
            int lineCount,
            int matchedCount,
            BigDecimal estimatedTotal,
            List<ParsedLine> lines,
            List<String> warnings
    ) {}

    @Transactional(readOnly = true)
    public ParsedOrder parse(String message) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (message == null || message.isBlank()) {
            return new ParsedOrder("", 0, 0, BigDecimal.ZERO, List.of(),
                    List.of("Message was empty."));
        }

        List<String> segments = splitSegments(message);
        List<ParsedLine> lines = new ArrayList<>();
        List<String> warnings = new ArrayList<>();
        BigDecimal total = BigDecimal.ZERO;
        int matchedCount = 0;

        for (String segment : segments) {
            ParsedLine line = parseSegment(orgId, segment);
            if (line == null) continue;
            lines.add(line);
            if (line.matched()) {
                matchedCount++;
                BigDecimal price = line.salePrice() == null ? BigDecimal.ZERO : line.salePrice();
                total = total.add(price.multiply(line.quantity()));
            } else {
                warnings.add("Couldn't match: \"" + line.raw() + "\" — needs manual pick.");
            }
        }

        return new ParsedOrder(message, lines.size(), matchedCount, total, lines, warnings);
    }

    /** Per-customer SKU alias hook for future extension — for now passthrough. */
    @Transactional(readOnly = true)
    public ParsedOrder parseForContact(String message, UUID contactId) {
        // Future: load contact-specific SKU aliases (e.g. customer calls Crocin "fever tablet")
        // and merge into the search query before falling through to org-wide search.
        return parse(message);
    }

    // ── internals ────────────────────────────────────────────────

    List<String> splitSegments(String message) {
        // Newlines, commas, and " and " all split lines.
        String normalised = message.replaceAll("\r", "")
                .replaceAll(" and ", "\n")
                .replaceAll(",", "\n");
        List<String> out = new ArrayList<>();
        for (String s : normalised.split("\\n")) {
            String trim = s.trim()
                    .replaceAll("^[-*•·]+\\s*", "");
            if (!trim.isEmpty()) out.add(trim);
        }
        return out;
    }

    ParsedLine parseSegment(UUID orgId, String segment) {
        // Try leading qty first (most common: "200 amul 1L"), then trailing.
        Matcher lead = QTY_LEAD.matcher(segment);
        Matcher trail = QTY_TRAIL.matcher(segment);

        BigDecimal qty;
        String unit;
        String name;

        if (lead.find()) {
            qty = new BigDecimal(lead.group(1).replace(",", "."));
            unit = lead.group(2);
            name = lead.group(3);
        } else if (trail.find()) {
            qty = new BigDecimal(trail.group(2).replace(",", "."));
            unit = trail.group(3);
            name = trail.group(1);
        } else {
            // No quantity — default 1, treat the whole thing as the product
            qty = BigDecimal.ONE;
            unit = null;
            name = segment;
        }

        String cleaned = stripNoise(name);
        if (cleaned.isBlank()) return null;

        var page = itemRepository.search(orgId, cleaned, PageRequest.of(0, 5));
        List<Candidate> candidates = page.getContent().stream()
                .map(i -> new Candidate(i.getId(), i.getName(), i.getSalePrice()))
                .toList();

        Item top = page.getContent().isEmpty() ? null : page.getContent().get(0);
        boolean matched = top != null;
        double confidence = top == null ? 0.0
                : confidenceScore(cleaned, top.getName(), page.getContent().size());

        return new ParsedLine(
                segment.trim(),
                cleaned,
                qty,
                unit,
                matched,
                matched ? top.getId() : null,
                matched ? top.getName() : null,
                matched ? top.getSalePrice() : null,
                confidence,
                candidates.size() > 1 ? candidates.subList(1, candidates.size()) : List.of());
    }

    static String stripNoise(String name) {
        if (name == null) return "";
        String lower = name.toLowerCase();
        StringBuilder out = new StringBuilder();
        for (String tok : lower.split("\\s+")) {
            String t = tok.replaceAll("[^a-z0-9.]", "");
            if (t.isEmpty() || NOISE.contains(t)) continue;
            out.append(t).append(' ');
        }
        return out.toString().trim();
    }

    /** Cheap confidence: ratio of cleaned-query tokens that appear in top-match name. */
    static double confidenceScore(String query, String itemName, int totalCandidates) {
        if (query == null || itemName == null) return 0.0;
        String[] queryTokens = query.toLowerCase().split("\\s+");
        String haystack = itemName.toLowerCase();
        int matchedTokens = 0;
        for (String t : queryTokens) {
            if (t.length() < 2) continue;
            if (haystack.contains(t)) matchedTokens++;
        }
        double base = queryTokens.length == 0 ? 0.0
                : (double) matchedTokens / queryTokens.length;
        // Penalise when there are many close candidates — top might not be right.
        if (totalCandidates > 3) base *= 0.85;
        return Math.min(1.0, Math.max(0.0, base));
    }

    /** Render the parsed order as a flat Map for JSON responses without breaking generics. */
    public Map<String, Object> toResponse(ParsedOrder order) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("rawMessage", order.rawMessage());
        out.put("lineCount", order.lineCount());
        out.put("matchedCount", order.matchedCount());
        out.put("estimatedTotal", order.estimatedTotal());
        out.put("lines", order.lines());
        out.put("warnings", order.warnings());
        return out;
    }
}
