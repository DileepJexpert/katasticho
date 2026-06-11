package com.katasticho.erp.gst.service;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.InvoiceLine;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.gst.entity.EInvoice;
import com.katasticho.erp.gst.repository.EInvoiceRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * e-Invoice (IRN) compliance for B2B sales invoices.
 *
 * <p>When the org has e-invoicing enabled (org setting
 * {@code gst.einvoice_enabled} — applicable above the turnover notification
 * threshold), every posted invoice to a registered (GSTIN) buyer needs an IRN
 * from the Invoice Registration Portal before the invoice is valid. We detect
 * those invoices via INVOICE_POSTED, generate the IRP INV-01 schema JSON for
 * upload (offline tool / GSP), and record the IRN + Ack + signed QR back.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class EInvoiceService {

    public static final String ENABLED_SETTING = "gst.einvoice_enabled";
    private static final DateTimeFormatter IRP_DATE = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final EInvoiceRepository eInvoiceRepository;
    private final InvoiceRepository invoiceRepository;
    private final ContactRepository contactRepository;
    private final OrganisationRepository organisationRepository;
    private final OrgSettingsService orgSettingsService;
    private final AiSuggestionService aiSuggestionService;
    private final GspClient gspClient;

    // ── Auto-detection (INVOICE_POSTED handler path — explicit orgId) ────

    /**
     * Flag a freshly posted B2B invoice as needing an IRN. No-op unless the
     * org has e-invoicing enabled and the buyer is registered. Never throws.
     */
    @Transactional
    public void detectForInvoice(UUID orgId, UUID invoiceId) {
        try {
            if (!isEnabled(orgId)) return;
            Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                    .orElse(null);
            if (invoice == null) return;
            Contact buyer = contactRepository
                    .findByIdAndOrgIdAndIsDeletedFalse(invoice.getContactId(), orgId).orElse(null);
            if (buyer == null || isBlank(buyer.getGstin())) return; // B2C — no IRN
            if (eInvoiceRepository.existsByOrgIdAndInvoiceIdAndIsDeletedFalse(orgId, invoiceId)) return;

            EInvoice row = buildRow(invoice);
            row.setOrgId(orgId);
            row = eInvoiceRepository.save(row);
            createRequiredSuggestion(orgId, row, buyer);
            log.info("e-Invoice required for {} (buyer {}) — PENDING row created",
                    invoice.getInvoiceNumber(), buyer.getDisplayName());
        } catch (Exception e) {
            log.warn("e-Invoice detection failed for invoice {}: {}", invoiceId, e.getMessage());
        }
    }

    // ── Manual lifecycle (controller path — TenantContext) ──────────────

    @Transactional
    public EInvoice create(UUID invoiceId) {
        UUID orgId = requireOrgId();
        if (eInvoiceRepository.existsByOrgIdAndInvoiceIdAndIsDeletedFalse(orgId, invoiceId)) {
            throw new BusinessException("An e-invoice entry already exists for this invoice",
                    "EINVOICE_DUPLICATE", HttpStatus.CONFLICT);
        }
        Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));
        EInvoice row = buildRow(invoice);
        row.setOrgId(orgId);
        return eInvoiceRepository.save(row);
    }

    @Transactional(readOnly = true)
    public List<EInvoice> list(String status) {
        UUID orgId = requireOrgId();
        return (status == null || status.isBlank())
                ? eInvoiceRepository.findByOrgIdAndIsDeletedFalseOrderByDocumentDateDescCreatedAtDesc(orgId)
                : eInvoiceRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByDocumentDateDescCreatedAtDesc(
                        orgId, status.trim().toUpperCase());
    }

    /** Record the IRN + Ack + signed QR obtained from the IRP / GSP. */
    @Transactional
    public EInvoice recordGenerated(UUID id, String irn, String ackNumber, String ackDate, String signedQr) {
        UUID orgId = requireOrgId();
        EInvoice row = load(id, orgId);
        if ("CANCELLED".equals(row.getStatus())) {
            throw new BusinessException("This e-invoice entry is cancelled",
                    "EINVOICE_CANCELLED", HttpStatus.BAD_REQUEST);
        }
        if (irn == null || irn.isBlank()) {
            throw new BusinessException("IRN is required", "EINVOICE_IRN_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        row.setIrn(irn.trim());
        row.setAckNumber(trimToNull(ackNumber));
        row.setAckDate(trimToNull(ackDate));
        row.setSignedQr(trimToNull(signedQr));
        row.setStatus("GENERATED");
        row.setGeneratedAt(Instant.now());
        return eInvoiceRepository.save(row);
    }

    /**
     * One-click IRN: when the org has a GSP configured, POST the INV-01 payload
     * directly to the aggregator and record the IRN it returns. Falls back to a
     * clear error (not silent) when no GSP is configured so the manual
     * download-JSON flow stays the explicit alternative.
     */
    @Transactional
    public EInvoice generateViaGsp(UUID id) {
        UUID orgId = requireOrgId();
        if (!gspClient.isConfigured(orgId)) {
            throw new BusinessException(
                    "No GSP configured. Set up gst.gsp_* settings, or use Download JSON to file manually.",
                    "GSP_NOT_CONFIGURED", HttpStatus.BAD_REQUEST);
        }
        Map<String, Object> payload = portalJson(id);
        Map<String, Object> resp = gspClient.generateEInvoice(orgId, payload);

        String irn = firstNonBlank(resp, "Irn", "irn", "IRN");
        if (isBlank(irn)) {
            throw new BusinessException(
                    "GSP did not return an IRN: " + firstNonBlank(resp, "ErrorMessage", "error", "message", "status"),
                    "GSP_NO_IRN", HttpStatus.BAD_GATEWAY);
        }
        return recordGenerated(id, irn,
                firstNonBlank(resp, "AckNo", "ackNo", "AckNumber"),
                firstNonBlank(resp, "AckDt", "ackDt", "AckDate"),
                firstNonBlank(resp, "SignedQRCode", "signedQRCode", "signedQr", "SignedQr"));
    }

    /** Record cancellation (IRN cancel on the portal is allowed within 24h). */
    @Transactional
    public EInvoice cancel(UUID id, String reason) {
        UUID orgId = requireOrgId();
        EInvoice row = load(id, orgId);
        row.setStatus("CANCELLED");
        row.setCancelledAt(Instant.now());
        row.setCancelReason(reason);
        return eInvoiceRepository.save(row);
    }

    // ── IRP INV-01 JSON ──────────────────────────────────────────────────

    /** IRP e-invoice schema (INV-01 v1.1) payload for offline-tool / GSP upload. */
    @Transactional(readOnly = true)
    public Map<String, Object> portalJson(UUID id) {
        UUID orgId = requireOrgId();
        EInvoice row = load(id, orgId);
        Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(row.getInvoiceId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", row.getInvoiceId()));
        Organisation org = organisationRepository.findById(orgId).orElse(null);
        Contact buyer = contactRepository
                .findByIdAndOrgIdAndIsDeletedFalse(invoice.getContactId(), orgId).orElse(null);
        if (buyer == null || isBlank(buyer.getGstin())) {
            throw new BusinessException("e-Invoice needs a buyer with GSTIN (B2B only)",
                    "EINVOICE_BUYER_GSTIN_REQUIRED", HttpStatus.BAD_REQUEST);
        }

        String sellerState = org != null ? nvl(org.getStateCode()) : "";
        String pos = !isBlank(invoice.getPlaceOfSupply())
                ? invoice.getPlaceOfSupply() : nvl(buyer.getBillingStateCode());
        boolean interState = !sellerState.isEmpty() && !pos.isEmpty() && !sellerState.equals(pos);

        BigDecimal assVal = BigDecimal.ZERO, cgst = BigDecimal.ZERO,
                sgst = BigDecimal.ZERO, igst = BigDecimal.ZERO;
        List<Map<String, Object>> itemList = new ArrayList<>();
        int slNo = 1;
        for (InvoiceLine line : invoice.getLines()) {
            BigDecimal taxable = nz(line.getTaxableAmount());
            BigDecimal tax = nz(line.getTaxAmount());
            BigDecimal rate = nz(line.getGstRate());
            assVal = assVal.add(taxable);
            BigDecimal lineCgst = BigDecimal.ZERO, lineSgst = BigDecimal.ZERO, lineIgst = BigDecimal.ZERO;
            if (interState) {
                lineIgst = tax;
                igst = igst.add(tax);
            } else {
                lineCgst = tax.divide(BigDecimal.valueOf(2), 2, RoundingMode.HALF_UP);
                lineSgst = tax.subtract(lineCgst);
                cgst = cgst.add(lineCgst);
                sgst = sgst.add(lineSgst);
            }
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("SlNo", String.valueOf(slNo++));
            item.put("PrdDesc", line.getDescription());
            item.put("IsServc", line.getItemId() == null ? "Y" : "N");
            item.put("HsnCd", nvl(line.getHsnCode()));
            item.put("Qty", nz(line.getQuantity()));
            item.put("Unit", "NOS");
            item.put("UnitPrice", nz(line.getUnitPrice()));
            item.put("TotAmt", taxable);
            item.put("AssAmt", taxable);
            item.put("GstRt", rate);
            item.put("IgstAmt", lineIgst);
            item.put("CgstAmt", lineCgst);
            item.put("SgstAmt", lineSgst);
            item.put("TotItemVal", nz(line.getLineTotal()));
            itemList.add(item);
        }

        Map<String, Object> json = new LinkedHashMap<>();
        json.put("Version", "1.1");
        json.put("TranDtls", Map.of("TaxSch", "GST", "SupTyp", "B2B",
                "RegRev", invoice.isReverseCharge() ? "Y" : "N"));
        json.put("DocDtls", Map.of(
                "Typ", "INV",
                "No", invoice.getInvoiceNumber(),
                "Dt", invoice.getInvoiceDate().format(IRP_DATE)));
        json.put("SellerDtls", sellerDtls(org, sellerState));
        json.put("BuyerDtls", buyerDtls(buyer, pos));
        json.put("ItemList", itemList);
        Map<String, Object> valDtls = new LinkedHashMap<>();
        valDtls.put("AssVal", assVal);
        valDtls.put("CgstVal", cgst);
        valDtls.put("SgstVal", sgst);
        valDtls.put("IgstVal", igst);
        valDtls.put("TotInvVal", nz(invoice.getTotalAmount()));
        json.put("ValDtls", valDtls);
        return json;
    }

    // ── Settings ─────────────────────────────────────────────────────────

    public boolean isEnabled(UUID orgId) {
        return "true".equalsIgnoreCase(orgSettingsService.get(orgId, ENABLED_SETTING, "false"));
    }

    public void setEnabled(boolean enabled) {
        orgSettingsService.set(requireOrgId(), ENABLED_SETTING, String.valueOf(enabled));
    }

    public Map<String, Object> settings() {
        return Map.of("enabled", isEnabled(requireOrgId()));
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private EInvoice buildRow(Invoice invoice) {
        return EInvoice.builder()
                .invoiceId(invoice.getId())
                .documentNumber(invoice.getInvoiceNumber())
                .documentDate(invoice.getInvoiceDate())
                .contactId(invoice.getContactId())
                .totalValue(nz(invoice.getTotalAmount()))
                .status("PENDING")
                .build();
    }

    private Map<String, Object> sellerDtls(Organisation org, String stateCode) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("Gstin", org != null ? nvl(org.getGstin()) : "");
        m.put("LglNm", org != null ? nvl(org.getName()) : "");
        m.put("Addr1", org != null ? nvl(org.getAddressLine1()) : "");
        m.put("Loc", org != null ? nvl(org.getCity()) : "");
        m.put("Pin", pincode(org != null ? org.getPostalCode() : null));
        m.put("Stcd", stateCode);
        return m;
    }

    private Map<String, Object> buyerDtls(Contact buyer, String pos) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("Gstin", nvl(buyer.getGstin()));
        m.put("LglNm", nvl(buyer.getDisplayName()));
        m.put("Pos", pos);
        m.put("Addr1", nvl(buyer.getBillingAddressLine1()));
        m.put("Loc", nvl(buyer.getBillingCity()));
        m.put("Pin", pincode(buyer.getBillingPostalCode()));
        m.put("Stcd", nvl(buyer.getBillingStateCode()));
        return m;
    }

    private void createRequiredSuggestion(UUID orgId, EInvoice row, Contact buyer) {
        try {
            Map<String, Object> value = new LinkedHashMap<>();
            value.put("eInvoiceId", row.getId().toString());
            value.put("documentNumber", row.getDocumentNumber());
            value.put("buyer", buyer.getDisplayName());
            value.put("totalValue", row.getTotalValue().toPlainString());
            aiSuggestionService.createSuggestion(AiSuggestion.builder()
                    .orgId(orgId)
                    .entityType("EINVOICE")
                    .entityId(row.getId())
                    .suggestionType("EINVOICE_REQUIRED")
                    .suggestedAction("GENERATE_IRN")
                    .suggestedValue(value)
                    .reasoning("B2B invoice " + row.getDocumentNumber() + " to " + buyer.getDisplayName()
                            + " needs an IRN — without it the invoice is not valid for the buyer's ITC. "
                            + "Download the IRP JSON from the GST screen, get the IRN, and record it back.")
                    .confidence(new BigDecimal("0.950"))
                    .agentName("einvoice_detector")
                    .modelName("deterministic_rules")
                    .modelVersion("1")
                    .promptVersion("none")
                    .priority("HIGH")
                    .priorityScore(new BigDecimal("85"))
                    .status("PENDING")
                    .build());
        } catch (Exception e) {
            log.warn("Could not create e-invoice suggestion for {}: {}", row.getId(), e.getMessage());
        }
    }

    private EInvoice load(UUID id, UUID orgId) {
        return eInvoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("EInvoice", id));
    }

    private static int pincode(String postal) {
        if (postal == null) return 0;
        try {
            return Integer.parseInt(postal.trim());
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    private static String nvl(String s) {
        return s == null ? "" : s;
    }

    private static String trimToNull(String s) {
        if (s == null) return null;
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }

    /**
     * First non-blank value among the given keys, looked up on the response map
     * and one level inside common wrapper objects (data / result / response) —
     * GSP aggregators differ on casing and nesting.
     */
    @SuppressWarnings("unchecked")
    static String firstNonBlank(Map<String, Object> resp, String... keys) {
        if (resp == null) return null;
        List<Map<String, Object>> scopes = new ArrayList<>();
        scopes.add(resp);
        for (String wrap : new String[]{"data", "result", "response", "Data", "Result"}) {
            Object inner = resp.get(wrap);
            if (inner instanceof Map<?, ?> m) scopes.add((Map<String, Object>) m);
        }
        for (Map<String, Object> scope : scopes) {
            for (String k : keys) {
                Object v = scope.get(k);
                if (v != null && !String.valueOf(v).isBlank()) return String.valueOf(v);
            }
        }
        return null;
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
