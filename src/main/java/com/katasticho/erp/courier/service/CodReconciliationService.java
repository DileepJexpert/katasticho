package com.katasticho.erp.courier.service;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.ar.dto.RecordPaymentRequest;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.Payment;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.PaymentService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.courier.dto.CodRemittanceDtos.*;
import com.katasticho.erp.courier.entity.CodRemittance;
import com.katasticho.erp.courier.entity.CodRemittanceLine;
import com.katasticho.erp.courier.entity.CourierShipment;
import com.katasticho.erp.courier.repository.CodRemittanceRepository;
import com.katasticho.erp.courier.repository.CourierShipmentRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

/**
 * COD remittance reconciliation — the genuinely new accounting loop in the
 * courier module.
 *
 * <p>The courier collects cash from N customers, withholds a fee per parcel,
 * and remits the net to our bank in one bank transfer. This service ingests the
 * remittance file (or the manual entry), looks each AWB up, and on
 * {@link #reconcile} walks the lines:
 *
 * <ul>
 *   <li><b>MATCHED</b> (AWB resolves + COD = invoice balance) → posts a Payment
 *       via {@link PaymentService}, settling AR cleanly. The shipment is stamped
 *       with the remittance line.</li>
 *   <li><b>AMOUNT_MISMATCH</b> (AWB resolves but COD ≠ balance) → held for
 *       review.</li>
 *   <li><b>ORPHAN</b> (AWB not found) → surfaced as an AI Inbox suggestion so
 *       the missing shipment can be created, after which the line can be re-run.</li>
 * </ul>
 *
 * <p><b>What the agent never auto-posts:</b> the courier fees withheld are
 * captured on the remittance for visibility but <em>not</em> booked as expense
 * automatically — the owner records that against the courier's monthly invoice
 * via the regular expense flow. Same with the variance (net_remitted vs.
 * expected_net) — surfaced, not silently posted. This keeps the bookkeeping
 * conservative and matches the rule used everywhere else in this codebase.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CodReconciliationService {

    /** ₹1 tolerance — same rule as GSTR-2B value matching. */
    private static final BigDecimal AMOUNT_TOLERANCE = new BigDecimal("1.00");
    static final String SUGGESTION_TYPE = "COD_ORPHAN_AWB";

    private final CodRemittanceRepository remittanceRepository;
    private final CourierShipmentRepository shipmentRepository;
    private final InvoiceRepository invoiceRepository;
    private final PaymentService paymentService;
    private final AiSuggestionService aiSuggestionService;

    // ── Create (ingest) ──────────────────────────────────────────────────

    @Transactional
    public CodRemittanceResponse create(CreateCodRemittanceRequest req) {
        UUID orgId = requireOrgId();
        if (req.lines() == null || req.lines().isEmpty()) {
            throw new BusinessException(
                    "A remittance needs at least one COD line",
                    "COD_REMITTANCE_EMPTY", HttpStatus.BAD_REQUEST);
        }

        CodRemittance remittance = CodRemittance.builder()
                .remittanceNumber(nextRemittanceNumber(orgId))
                .courierPartner(req.courierPartner())
                .remittanceDate(req.remittanceDate())
                .bankAccount(req.bankAccount())
                .utr(req.utr())
                .netRemitted(nz(req.netRemitted()))
                .notes(req.notes())
                .build();
        remittance.setOrgId(orgId);

        BigDecimal gross = BigDecimal.ZERO, fees = BigDecimal.ZERO;
        for (CodLineInput in : req.lines()) {
            if (in.codAmount() == null || in.codAmount().signum() < 0) {
                throw new BusinessException(
                        "COD amount must be non-negative",
                        "COD_LINE_BAD_AMOUNT", HttpStatus.BAD_REQUEST);
            }
            BigDecimal fee = nz(in.codFee());
            BigDecimal net = in.codAmount().subtract(fee);
            CodRemittanceLine line = CodRemittanceLine.builder()
                    .orgId(orgId)
                    .remittance(remittance)
                    .awbNumber(in.awbNumber().trim())
                    .codAmount(in.codAmount())
                    .codFee(fee)
                    .netAmount(net)
                    .matchStatus("PENDING")
                    .build();
            // Pre-match: stamp shipment + invoice ids if the AWB resolves.
            findShipment(orgId, req.courierPartner(), in.awbNumber().trim()).ifPresent(s -> {
                line.setCourierShipmentId(s.getId());
                line.setInvoiceId(s.getInvoiceId());
            });
            remittance.getLines().add(line);
            gross = gross.add(in.codAmount());
            fees = fees.add(fee);
        }
        BigDecimal expectedNet = gross.subtract(fees);
        remittance.setGrossCollected(gross);
        remittance.setTotalFees(fees);
        remittance.setExpectedNet(expectedNet);
        remittance.setVariance(remittance.getNetRemitted().subtract(expectedNet));

        remittance = remittanceRepository.save(remittance);
        log.info("COD remittance {} ({}) ingested — {} line(s), gross {}, expected net {}, variance {}",
                remittance.getRemittanceNumber(), remittance.getCourierPartner(),
                remittance.getLines().size(), gross, expectedNet, remittance.getVariance());
        return toResponse(remittance);
    }

    // ── Reconcile (post payments) ────────────────────────────────────────

    /**
     * Walk the DRAFT remittance's lines and:
     * <ul>
     *   <li>Post a Payment for every line whose AWB+COD matches an invoice balance.</li>
     *   <li>Flag amount mismatches without posting.</li>
     *   <li>Raise an AI Inbox suggestion per orphan AWB.</li>
     * </ul>
     * Idempotent on MATCHED lines (already-settled lines are skipped on re-run).
     */
    @Transactional
    public ReconcileResult reconcile(UUID remittanceId) {
        UUID orgId = requireOrgId();
        CodRemittance remittance = remittanceRepository
                .findByIdAndOrgIdAndIsDeletedFalse(remittanceId, orgId)
                .orElseThrow(() -> new BusinessException(
                        "COD remittance not found", "COD_REMITTANCE_NOT_FOUND", HttpStatus.NOT_FOUND));

        int matched = 0, mismatch = 0, orphan = 0;
        BigDecimal settled = BigDecimal.ZERO;

        for (CodRemittanceLine line : remittance.getLines()) {
            if ("MATCHED".equals(line.getMatchStatus())) { matched++; settled = settled.add(line.getCodAmount()); continue; }

            // Re-resolve in case the shipment was created since ingest.
            CourierShipment shipment = line.getCourierShipmentId() != null
                    ? shipmentRepository.findByIdAndOrgIdAndIsDeletedFalse(line.getCourierShipmentId(), orgId).orElse(null)
                    : findShipment(orgId, remittance.getCourierPartner(), line.getAwbNumber()).orElse(null);

            if (shipment == null || shipment.getInvoiceId() == null) {
                line.setMatchStatus("ORPHAN");
                line.setNotes("AWB " + line.getAwbNumber() + " not linked to an invoice in books");
                raiseOrphanSuggestion(orgId, remittance, line);
                orphan++;
                continue;
            }

            Invoice invoice = invoiceRepository.findById(shipment.getInvoiceId()).orElse(null);
            if (invoice == null) {
                line.setMatchStatus("ORPHAN");
                line.setNotes("Linked invoice no longer exists");
                raiseOrphanSuggestion(orgId, remittance, line);
                orphan++;
                continue;
            }

            BigDecimal balance = nz(invoice.getBalanceDue());
            BigDecimal diff = line.getCodAmount().subtract(balance).abs();
            if (diff.compareTo(AMOUNT_TOLERANCE) > 0) {
                line.setMatchStatus("AMOUNT_MISMATCH");
                line.setNotes("COD " + line.getCodAmount() + " ≠ invoice balance " + balance
                        + " (diff " + diff + ") — review before settling");
                mismatch++;
                continue;
            }

            // MATCHED — settle via the standard AR path.
            Payment payment = paymentService.recordPayment(new RecordPaymentRequest(
                    invoice.getId(),
                    invoice.getContactId(),
                    remittance.getRemittanceDate(),
                    line.getCodAmount(),
                    "COD_COLLECTION",
                    remittance.getUtr(),
                    remittance.getBankAccount(),
                    "COD via " + remittance.getCourierPartner()
                            + " AWB " + line.getAwbNumber()
                            + " (remittance " + remittance.getRemittanceNumber() + ")"));
            line.setPaymentId(payment.getId());
            line.setCourierShipmentId(shipment.getId());
            line.setInvoiceId(shipment.getInvoiceId());
            line.setMatchStatus("MATCHED");
            shipment.setCodRemittanceLineId(line.getId());
            shipmentRepository.save(shipment);
            settled = settled.add(line.getCodAmount());
            matched++;
        }

        remittance.setStatus("RECONCILED");
        remittanceRepository.save(remittance);
        log.info("COD remittance {} reconciled: {} matched, {} mismatch, {} orphan, settled {}",
                remittance.getRemittanceNumber(), matched, mismatch, orphan, settled);
        return new ReconcileResult(remittance.getId(), matched, mismatch, orphan,
                settled, remittance.getTotalFees(), remittance.getVariance());
    }

    @Transactional(readOnly = true)
    public CodRemittanceResponse get(UUID id) {
        UUID orgId = requireOrgId();
        return remittanceRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .map(this::toResponse)
                .orElseThrow(() -> new BusinessException(
                        "COD remittance not found", "COD_REMITTANCE_NOT_FOUND", HttpStatus.NOT_FOUND));
    }

    @Transactional(readOnly = true)
    public List<CodRemittanceResponse> list() {
        UUID orgId = requireOrgId();
        return remittanceRepository.findByOrgIdAndIsDeletedFalseOrderByRemittanceDateDesc(orgId)
                .stream().map(this::toResponse).toList();
    }

    // ── Internals ────────────────────────────────────────────────────────

    private Optional<CourierShipment> findShipment(UUID orgId, String partner, String awb) {
        Optional<CourierShipment> hit = shipmentRepository
                .findFirstByOrgIdAndCourierPartnerAndAwbNumberAndIsDeletedFalse(orgId, partner, awb);
        if (hit.isPresent()) return hit;
        return shipmentRepository.findFirstByOrgIdAndAwbNumberAndIsDeletedFalse(orgId, awb);
    }

    private void raiseOrphanSuggestion(UUID orgId, CodRemittance r, CodRemittanceLine line) {
        Map<String, Object> value = new LinkedHashMap<>();
        value.put("remittanceNumber", r.getRemittanceNumber());
        value.put("courierPartner", r.getCourierPartner());
        value.put("awbNumber", line.getAwbNumber());
        value.put("codAmount", line.getCodAmount());
        try {
            aiSuggestionService.createSuggestion(AiSuggestion.builder()
                    .orgId(orgId)
                    .entityType("COD_REMITTANCE_LINE")
                    .entityId(line.getId())
                    .suggestionType(SUGGESTION_TYPE)
                    .suggestedAction("LINK_SHIPMENT_OR_REJECT")
                    .suggestedValue(value)
                    .reasoning("Courier " + r.getCourierPartner() + " remitted ₹"
                            + line.getCodAmount() + " for AWB " + line.getAwbNumber()
                            + " but no matching shipment exists in books. Create the courier shipment "
                            + "(linked to the right invoice) and re-run reconciliation.")
                    .confidence(new BigDecimal("0.900"))
                    .agentName("cod_reconciler")
                    .modelName("deterministic_rules")
                    .modelVersion("1")
                    .promptVersion("none")
                    .priority("HIGH")
                    .priorityScore(new BigDecimal("80"))
                    .status("PENDING")
                    .build());
        } catch (Exception e) {
            // Inbox failure must not break reconcile — the line is still flagged ORPHAN.
            log.warn("Could not raise orphan-AWB suggestion for {}: {}", line.getAwbNumber(), e.getMessage());
        }
    }

    private CodRemittanceResponse toResponse(CodRemittance r) {
        List<CodLineResponse> lines = r.getLines().stream()
                .map(l -> new CodLineResponse(l.getId(), l.getAwbNumber(), l.getCourierShipmentId(),
                        l.getInvoiceId(), l.getCodAmount(), l.getCodFee(), l.getNetAmount(),
                        l.getMatchStatus(), l.getPaymentId(), l.getNotes()))
                .toList();
        return new CodRemittanceResponse(r.getId(), r.getRemittanceNumber(), r.getCourierPartner(),
                r.getRemittanceDate(), r.getBankAccount(), r.getUtr(), r.getGrossCollected(),
                r.getTotalFees(), r.getNetRemitted(), r.getExpectedNet(), r.getVariance(),
                r.getStatus(), r.getNotes(), lines);
    }

    private String nextRemittanceNumber(UUID orgId) {
        long count = remittanceRepository.countByOrgIdAndIsDeletedFalse(orgId);
        return String.format("CODR-%05d", count + 1);
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
