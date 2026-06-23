package com.katasticho.erp.pharma.register;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.pharma.entity.PrescriptionRecord;
import com.katasticho.erp.pharma.repository.PrescriptionRecordRepository;
import com.katasticho.erp.pos.entity.SalesReceipt;
import com.katasticho.erp.pos.entity.SalesReceiptLine;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayOutputStream;
import java.io.PrintWriter;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Statutory pharma register: H1 / Schedule X / Narcotics.
 *
 * <p>Auto-populated on POS sale of any item whose {@code drug_schedule} resolves
 * to a tracked register type. The register is mandated by:
 * <ul>
 *   <li><b>Rule 65(11)(h)</b> Drugs & Cosmetics Rules — Schedule H1: separate
 *       register with prescriber name + address, patient name, drug + qty,
 *       retained <b>3 years</b>.</li>
 *   <li><b>Form 20G / Schedule X</b> — Form 19C tracking, retained <b>2 years</b>,
 *       invoice copies forwarded to the Licensing Authority.</li>
 *   <li><b>NDPS Forms 3D / 3E / 3H</b> — Narcotics, retained <b>≥2 years</b>.</li>
 * </ul>
 *
 * <p>Per-org policy gate {@code pharma.h1_strict}:
 * <ul>
 *   <li>{@code false} (default) — record the entry even when no PrescriptionRecord
 *       is linked. Inspector sees the sale plus a flagged data-quality issue
 *       (null prescriber fields).</li>
 *   <li>{@code true} — throw {@code RX_PRESCRIPTION_REQUIRED} (BAD_REQUEST) so
 *       the upstream sale is blocked at the validation gate.</li>
 * </ul>
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class StatutoryRegisterService {

    private final StatutoryRegisterRepository registerRepository;
    private final ItemRepository itemRepository;
    private final StockBatchRepository stockBatchRepository;
    private final ContactRepository contactRepository;
    private final PrescriptionRecordRepository prescriptionRepository;
    private final OrgSettingsService orgSettingsService;

    /**
     * Strict-mode pre-check the POS layer can call BEFORE persisting the receipt,
     * so an H1 line without a prescription record fails fast rather than rolling
     * back the journal + stock movement after the fact. No-op in non-strict mode.
     */
    @Transactional(readOnly = true)
    public void preflightStrictMode(SalesReceipt receipt, Map<UUID, Item> itemMap) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (!strictMode(orgId)) return;

        boolean anyH1 = receipt.getLines().stream()
                .map(l -> l.getItemId() != null ? itemMap.get(l.getItemId()) : null)
                .anyMatch(i -> i != null && classify(i.getDrugSchedule()) == RegisterType.H1);
        if (!anyH1) return;

        boolean hasRx = receipt.getId() != null
                && prescriptionRepository.findByReceiptIdAndOrgIdAndIsDeletedFalse(receipt.getId(), orgId).isPresent();
        if (!hasRx) {
            throw new BusinessException(
                    "Schedule H1 sale requires a linked prescription record (pharma.h1_strict=true).",
                    "RX_PRESCRIPTION_REQUIRED",
                    HttpStatus.BAD_REQUEST);
        }
    }

    /**
     * Record one register entry per scheduled-drug line on the receipt.
     *
     * <p>Called from {@code SalesReceiptService.create} AFTER stock deduction.
     * Wrap the call site in try/catch; this method does NOT silently swallow
     * the {@code RX_PRESCRIPTION_REQUIRED} (strict-mode) bubble — the caller
     * should let that one bubble up so the sale rolls back cleanly.
     *
     * @return the entries persisted (empty list = no scheduled drugs sold).
     */
    @Transactional
    public List<StatutoryRegisterEntry> recordSaleEntries(SalesReceipt receipt, Map<UUID, Item> itemMap) {
        UUID orgId = receipt.getOrgId() != null ? receipt.getOrgId() : TenantContext.getCurrentOrgId();
        boolean strict = strictMode(orgId);

        // Resolve once per receipt
        PrescriptionRecord rx = receipt.getId() == null ? null
                : prescriptionRepository.findByReceiptIdAndOrgIdAndIsDeletedFalse(receipt.getId(), orgId)
                .orElse(null);
        Contact patient = receipt.getContactId() == null ? null
                : contactRepository
                        .findByIdAndOrgIdAndIsDeletedFalse(receipt.getContactId(), orgId)
                        .orElse(null);

        List<StatutoryRegisterEntry> created = new java.util.ArrayList<>();
        Map<UUID, String> batchNumberCache = new HashMap<>();

        for (SalesReceiptLine line : receipt.getLines()) {
            if (line.getItemId() == null) continue;
            Item item = itemMap != null ? itemMap.get(line.getItemId()) : null;
            if (item == null) {
                item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(line.getItemId(), orgId)
                        .orElse(null);
            }
            if (item == null) continue;

            RegisterType type = classify(item.getDrugSchedule());
            if (type == null) continue;

            if (strict && type == RegisterType.H1 && rx == null) {
                throw new BusinessException(
                        "Schedule H1 sale requires a linked prescription record (pharma.h1_strict=true).",
                        "RX_PRESCRIPTION_REQUIRED",
                        HttpStatus.BAD_REQUEST);
            }

            LocalDate saleDate = receipt.getReceiptDate() != null ? receipt.getReceiptDate() : LocalDate.now();
            LocalDate retentionUntil = saleDate.plusYears(type.retentionYears());

            String batchNumber = null;
            if (line.getBatchId() != null) {
                batchNumber = batchNumberCache.computeIfAbsent(line.getBatchId(), bid ->
                        stockBatchRepository.findByIdAndOrgIdAndIsDeletedFalse(bid, orgId)
                                .map(StockBatch::getBatchNumber)
                                .orElse(null));
            }

            StatutoryRegisterEntry entry = StatutoryRegisterEntry.builder()
                    .registerType(type)
                    .saleReceiptId(receipt.getId())
                    .invoiceId(null)
                    .itemId(item.getId())
                    .drugName(item.getName())
                    .batchId(line.getBatchId())
                    .batchNumber(batchNumber)
                    .quantity(line.getQuantity() != null ? line.getQuantity() : BigDecimal.ZERO)
                    .saleDate(saleDate)
                    .retentionUntil(retentionUntil)
                    .prescriberName(rx != null ? rx.getDoctorName() : null)
                    .prescriberRegNumber(rx != null ? rx.getDoctorRegNumber() : null)
                    .prescriberAddress(rx != null ? rx.getNotes() : null)
                    .patientName(patient != null ? patient.getDisplayName() : null)
                    .patientAddress(patient != null ? joinAddress(patient) : null)
                    .patientPhone(patient != null ? prefer(patient.getMobile(), patient.getPhone()) : null)
                    .build();
            entry.setOrgId(orgId);
            created.add(registerRepository.save(entry));
        }
        return created;
    }

    @Transactional(readOnly = true)
    public StatutoryRegisterEntry get(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return registerRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("StatutoryRegisterEntry", id));
    }

    @Transactional(readOnly = true)
    public Page<StatutoryRegisterEntry> list(RegisterType type, LocalDate from, LocalDate to, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (type == null) throw new BusinessException("register type is required", "SREG_TYPE_REQUIRED");
        LocalDate effFrom = from != null ? from : LocalDate.of(1970, 1, 1);
        LocalDate effTo = to != null ? to : LocalDate.of(9999, 12, 31);
        return registerRepository
                .findByOrgIdAndRegisterTypeAndSaleDateBetweenAndIsDeletedFalseOrderBySaleDateDescCreatedAtDesc(
                        orgId, type, effFrom, effTo, pageable);
    }

    @Transactional(readOnly = true)
    public byte[] exportCsv(RegisterType type, LocalDate from, LocalDate to) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (type == null) throw new BusinessException("register type is required", "SREG_TYPE_REQUIRED");
        LocalDate effFrom = from != null ? from : LocalDate.of(1970, 1, 1);
        LocalDate effTo = to != null ? to : LocalDate.of(9999, 12, 31);
        List<StatutoryRegisterEntry> rows = registerRepository
                .findByOrgIdAndRegisterTypeAndSaleDateBetweenAndIsDeletedFalseOrderBySaleDateAscCreatedAtAsc(
                        orgId, type, effFrom, effTo);

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (PrintWriter w = new PrintWriter(out, false, StandardCharsets.UTF_8)) {
            w.println(String.join(",",
                    "Sl No",
                    "Sale Date",
                    "Drug Name",
                    "Batch",
                    "Qty",
                    "Prescriber Name",
                    "Prescriber Reg No",
                    "Prescriber Address",
                    "Patient Name",
                    "Patient Address",
                    "Patient Phone",
                    "Receipt/Invoice ID",
                    "Retention Until"));
            int sl = 1;
            DateTimeFormatter df = DateTimeFormatter.ISO_LOCAL_DATE;
            for (StatutoryRegisterEntry r : rows) {
                String ref = r.getSaleReceiptId() != null
                        ? r.getSaleReceiptId().toString()
                        : (r.getInvoiceId() != null ? r.getInvoiceId().toString() : "");
                w.println(String.join(",",
                        String.valueOf(sl++),
                        r.getSaleDate() != null ? r.getSaleDate().format(df) : "",
                        csv(r.getDrugName()),
                        csv(r.getBatchNumber()),
                        r.getQuantity() != null ? r.getQuantity().toPlainString() : "",
                        csv(r.getPrescriberName()),
                        csv(r.getPrescriberRegNumber()),
                        csv(r.getPrescriberAddress()),
                        csv(r.getPatientName()),
                        csv(r.getPatientAddress()),
                        csv(r.getPatientPhone()),
                        csv(ref),
                        r.getRetentionUntil() != null ? r.getRetentionUntil().format(df) : ""));
            }
        }
        return out.toByteArray();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> dashboard(RegisterType type) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (type == null) throw new BusinessException("register type is required", "SREG_TYPE_REQUIRED");
        LocalDate now = LocalDate.now();
        LocalDate monthStart = now.withDayOfMonth(1);
        long total = registerRepository.countByOrgIdAndRegisterTypeAndIsDeletedFalse(orgId, type);
        long thisMonth = registerRepository
                .countByOrgIdAndRegisterTypeAndSaleDateBetweenAndIsDeletedFalse(orgId, type, monthStart, now);
        List<StatutoryRegisterEntry> retentionDueSoon = registerRepository
                .findTop10ByOrgIdAndRegisterTypeAndRetentionUntilBetweenAndIsDeletedFalseOrderByRetentionUntilAsc(
                        orgId, type, now, now.plusDays(90));

        Map<String, Object> out = new java.util.LinkedHashMap<>();
        out.put("registerType", type.name());
        out.put("totalEntries", total);
        out.put("entriesThisMonth", thisMonth);
        out.put("retentionYears", type.retentionYears());
        out.put("retentionDueWithin90Days", retentionDueSoon.size());
        out.put("retentionDueSamples", retentionDueSoon);
        return out;
    }

    // ── helpers ──────────────────────────────────────────────────

    /**
     * Map a free-text {@code drug_schedule} string to a tracked register type.
     * Tolerates Marg / Tally / paper-form variants (H1, H-1, H1A, Sch X, NARCO…).
     * Returns {@code null} for non-scheduled drugs so the caller can skip the line.
     */
    static RegisterType classify(String drugSchedule) {
        if (drugSchedule == null) return null;
        String s = drugSchedule.trim().toUpperCase().replaceAll("[\\s\\-_.]+", "");
        if (s.isEmpty()) return null;
        // H1 family: H1, H-1, H1A, SCHH1, SCHEDULEH1 etc.
        if (s.equals("H1") || s.startsWith("H1") || s.endsWith("H1")) return RegisterType.H1;
        // Schedule X: X, SCHX, SCHEDULEX
        if (s.equals("X") || s.equals("SCHX") || s.equals("SCHEDULEX") || s.endsWith("SCHX")
                || s.endsWith("SCHEDULEX")) return RegisterType.SCHEDULE_X;
        // Narcotics: NARC, NARCO, NDPS, NARCOTIC*
        if (s.startsWith("NARC") || s.equals("NDPS")) return RegisterType.NARCOTICS;
        return null;
    }

    private boolean strictMode(UUID orgId) {
        return Boolean.parseBoolean(orgSettingsService.get(orgId, "pharma.h1_strict", "false"));
    }

    private static String prefer(String a, String b) {
        return (a != null && !a.isBlank()) ? a : b;
    }

    private static String joinAddress(Contact c) {
        StringBuilder sb = new StringBuilder();
        appendPart(sb, c.getBillingAddressLine1());
        appendPart(sb, c.getBillingAddressLine2());
        appendPart(sb, c.getBillingCity());
        appendPart(sb, c.getBillingState());
        appendPart(sb, c.getBillingPostalCode());
        return sb.length() == 0 ? null : sb.toString();
    }

    private static void appendPart(StringBuilder sb, String s) {
        if (s == null || s.isBlank()) return;
        if (sb.length() > 0) sb.append(", ");
        sb.append(s);
    }

    /** CSV-escape: wraps in quotes if the value contains a comma/quote/newline. */
    private static String csv(String s) {
        if (s == null) return "";
        boolean needsQuote = s.indexOf(',') >= 0 || s.indexOf('"') >= 0 || s.indexOf('\n') >= 0 || s.indexOf('\r') >= 0;
        if (!needsQuote) return s;
        return "\"" + s.replace("\"", "\"\"") + "\"";
    }
}
