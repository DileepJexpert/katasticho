package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.fieldsales.entity.RcpaAudit;
import com.katasticho.erp.fieldsales.entity.RcpaLine;
import com.katasticho.erp.fieldsales.repository.RcpaAuditRepository;
import com.katasticho.erp.fieldsales.repository.RcpaLineRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.*;

/**
 * Retail Chemist Prescription Audit (RCPA). The MR records a chemist's actual
 * sales of own and competitor brands; the service rolls these up into
 * own-vs-competitor brand share and a competitor-brand league table.
 */
@Service
@RequiredArgsConstructor
public class RcpaService {

    private final RcpaAuditRepository auditRepository;
    private final RcpaLineRepository lineRepository;
    private final ContactRepository contactRepository;

    public record LineInput(String productName, String brandType, String competitorName,
                            UUID ourItemId, BigDecimal quantity, BigDecimal value) {}

    /** Record (or replace the lines of) an audit for a chemist, by the current MR. */
    @Transactional
    public Map<String, Object> record(UUID auditId, UUID chemistContactId, LocalDate auditDate,
                                      UUID fieldVisitId, String remarks, List<LineInput> lines) {
        UUID orgId = TenantContext.getCurrentOrgId();
        contactRepository.findByIdAndOrgIdAndIsDeletedFalse(chemistContactId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", chemistContactId));

        RcpaAudit audit = auditId != null
                ? load(auditId)
                : RcpaAudit.builder()
                        .orgId(orgId)
                        .salespersonId(TenantContext.getCurrentUserId())
                        .createdBy(TenantContext.getCurrentUserId())
                        .build();
        audit.setChemistContactId(chemistContactId);
        audit.setAuditDate(auditDate);
        audit.setFieldVisitId(fieldVisitId);
        audit.setRemarks(remarks);
        audit = auditRepository.save(audit);

        lineRepository.deleteByOrgIdAndAuditId(orgId, audit.getId());
        List<RcpaLine> saved = new ArrayList<>();
        for (LineInput in : lines != null ? lines : List.<LineInput>of()) {
            if (in.productName() == null || in.productName().isBlank()) {
                throw new BusinessException("Each line needs a product name",
                        "RCPA_LINE_NO_PRODUCT", HttpStatus.BAD_REQUEST);
            }
            String brand = "COMPETITOR".equalsIgnoreCase(in.brandType()) ? "COMPETITOR" : "OWN";
            saved.add(lineRepository.save(RcpaLine.builder()
                    .orgId(orgId).auditId(audit.getId())
                    .productName(in.productName().trim())
                    .brandType(brand)
                    .competitorName("COMPETITOR".equals(brand) ? in.competitorName() : null)
                    .ourItemId("OWN".equals(brand) ? in.ourItemId() : null)
                    .quantity(nz(in.quantity())).value(nz(in.value()))
                    .build()));
        }
        return view(audit, saved);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getAudit(UUID auditId) {
        RcpaAudit audit = load(auditId);
        return view(audit, lineRepository
                .findByOrgIdAndAuditIdAndIsDeletedFalseOrderByBrandTypeAscProductNameAsc(
                        audit.getOrgId(), audit.getId()));
    }

    @Transactional(readOnly = true)
    public List<RcpaAudit> listByChemist(UUID chemistContactId) {
        return auditRepository.findByOrgIdAndChemistContactIdAndIsDeletedFalseOrderByAuditDateDesc(
                TenantContext.getCurrentOrgId(), chemistContactId);
    }

    @Transactional(readOnly = true)
    public List<RcpaAudit> myAudits() {
        return auditRepository.findByOrgIdAndSalespersonIdAndIsDeletedFalseOrderByAuditDateDesc(
                TenantContext.getCurrentOrgId(), TenantContext.getCurrentUserId());
    }

    /** Own-vs-competitor brand share across audits in the date range. */
    @Transactional(readOnly = true)
    public Map<String, Object> shareReport(LocalDate from, LocalDate to) {
        BigDecimal ownQty = BigDecimal.ZERO, ownVal = BigDecimal.ZERO;
        BigDecimal compQty = BigDecimal.ZERO, compVal = BigDecimal.ZERO;
        for (RcpaLine l : linesInRange(from, to)) {
            if ("COMPETITOR".equals(l.getBrandType())) {
                compQty = compQty.add(nz(l.getQuantity()));
                compVal = compVal.add(nz(l.getValue()));
            } else {
                ownQty = ownQty.add(nz(l.getQuantity()));
                ownVal = ownVal.add(nz(l.getValue()));
            }
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("ownQty", ownQty);
        out.put("ownValue", ownVal);
        out.put("competitorQty", compQty);
        out.put("competitorValue", compVal);
        out.put("ownShareByQtyPct", sharePct(ownQty, ownQty.add(compQty)));
        out.put("ownShareByValuePct", sharePct(ownVal, ownVal.add(compVal)));
        return out;
    }

    /** Competitor brand league table (qty + value), value-desc. */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> competitorBrands(LocalDate from, LocalDate to) {
        record Key(String product, String competitor) {}
        Map<Key, BigDecimal[]> byBrand = new LinkedHashMap<>();
        for (RcpaLine l : linesInRange(from, to)) {
            if (!"COMPETITOR".equals(l.getBrandType())) continue;
            Key k = new Key(l.getProductName(), nvl(l.getCompetitorName()));
            BigDecimal[] acc = byBrand.computeIfAbsent(k, x -> new BigDecimal[]{BigDecimal.ZERO, BigDecimal.ZERO});
            acc[0] = acc[0].add(nz(l.getQuantity()));
            acc[1] = acc[1].add(nz(l.getValue()));
        }
        List<Map<String, Object>> rows = new ArrayList<>();
        for (Map.Entry<Key, BigDecimal[]> e : byBrand.entrySet()) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("productName", e.getKey().product());
            row.put("competitorName", e.getKey().competitor());
            row.put("quantity", e.getValue()[0]);
            row.put("value", e.getValue()[1]);
            rows.add(row);
        }
        rows.sort(Comparator.comparing(r -> ((BigDecimal) r.get("value")).negate()));
        return rows;
    }

    // ── helpers ──────────────────────────────────────────────────────────

    private List<RcpaLine> linesInRange(LocalDate from, LocalDate to) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<RcpaAudit> audits = auditRepository
                .findByOrgIdAndAuditDateBetweenAndIsDeletedFalse(orgId, from, to);
        if (audits.isEmpty()) return List.of();
        List<UUID> ids = audits.stream().map(RcpaAudit::getId).toList();
        return lineRepository.findByOrgIdAndAuditIdInAndIsDeletedFalse(orgId, ids);
    }

    private RcpaAudit load(UUID id) {
        return auditRepository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("RcpaAudit", id));
    }

    private Map<String, Object> view(RcpaAudit audit, List<RcpaLine> lines) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("audit", audit);
        out.put("lines", lines);
        return out;
    }

    private static BigDecimal sharePct(BigDecimal part, BigDecimal total) {
        if (total.signum() == 0) return BigDecimal.ZERO;
        return part.multiply(BigDecimal.valueOf(100)).divide(total, 1, RoundingMode.HALF_UP);
    }

    private static BigDecimal nz(BigDecimal v) {
        return v != null ? v : BigDecimal.ZERO;
    }

    private static String nvl(String s) {
        return s != null ? s : "";
    }
}
