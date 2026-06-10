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
import com.katasticho.erp.gst.dto.EwayBillDtos.CreateEwayBillRequest;
import com.katasticho.erp.gst.dto.EwayBillDtos.EwayBillResponse;
import com.katasticho.erp.gst.dto.EwayBillDtos.RecordEwbRequest;
import com.katasticho.erp.gst.dto.EwayBillDtos.VehicleCheckRequest;
import com.katasticho.erp.gst.entity.EwayBill;
import com.katasticho.erp.gst.repository.EwayBillRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.sales.entity.DeliveryChallan;
import com.katasticho.erp.sales.repository.DeliveryChallanRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.*;

/**
 * e-Way bill compliance for goods movement.
 *
 * <p>Two statutory triggers are covered:
 * <ul>
 *   <li><b>Single document:</b> a posted invoice ≥ the threshold (org setting
 *       {@code gst.eway_bill_threshold}, default ₹50,000) requires an EWB
 *       before transit. Detected automatically via the INVOICE_POSTED domain
 *       event — a PENDING row + AI Inbox suggestion are created.</li>
 *   <li><b>Vehicle aggregate:</b> several sub-threshold documents moving in
 *       one vehicle whose combined value crosses the threshold ALL require
 *       EWBs. Checked via {@link #checkVehicle} and on EWB creation.</li>
 * </ul>
 *
 * We generate NIC bulk-upload JSON; the EWB number obtained on the portal is
 * recorded back here with its validity (1 day per 200 km).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class EwayBillService {

    public static final String THRESHOLD_SETTING = "gst.eway_bill_threshold";
    private static final String DEFAULT_THRESHOLD = "50000";
    private static final int KM_PER_VALIDITY_DAY = 200;
    private static final DateTimeFormatter NIC_DATE = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final EwayBillRepository ewayBillRepository;
    private final InvoiceRepository invoiceRepository;
    private final DeliveryChallanRepository deliveryChallanRepository;
    private final ContactRepository contactRepository;
    private final OrganisationRepository organisationRepository;
    private final OrgSettingsService orgSettingsService;
    private final AiSuggestionService aiSuggestionService;

    // ── Auto-detection (INVOICE_POSTED handler path — explicit orgId) ────

    /**
     * Called when an invoice posts. If it crosses the e-way threshold and has
     * no EWB row yet, create a PENDING row + an AI Inbox nudge. Never throws —
     * detection must not break invoice posting.
     */
    @Transactional
    public void detectForInvoice(UUID orgId, UUID invoiceId) {
        try {
            Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                    .orElse(null);
            if (invoice == null) return;

            BigDecimal threshold = threshold(orgId);
            if (nz(invoice.getTotalAmount()).compareTo(threshold) < 0) return;
            if (ewayBillRepository.existsByOrgIdAndDocumentTypeAndDocumentIdAndIsDeletedFalse(
                    orgId, "INVOICE", invoiceId)) return;

            Organisation org = organisationRepository.findById(orgId).orElse(null);
            Contact contact = contactRepository
                    .findByIdAndOrgIdAndIsDeletedFalse(invoice.getContactId(), orgId).orElse(null);

            EwayBill ewb = EwayBill.builder()
                    .documentType("INVOICE")
                    .documentId(invoiceId)
                    .documentNumber(invoice.getInvoiceNumber())
                    .documentDate(invoice.getInvoiceDate())
                    .contactId(invoice.getContactId())
                    .totalValue(nz(invoice.getTotalAmount()))
                    .status("PENDING")
                    .fromStateCode(org != null ? org.getStateCode() : null)
                    .toStateCode(resolveToState(invoice.getPlaceOfSupply(), contact))
                    .build();
            ewb.setOrgId(orgId);
            ewb = ewayBillRepository.save(ewb);

            createRequiredSuggestion(orgId, ewb, threshold);
            log.info("e-Way bill required for invoice {} ({}) — PENDING row created",
                    invoice.getInvoiceNumber(), nz(invoice.getTotalAmount()).toPlainString());
        } catch (Exception e) {
            log.warn("e-Way bill detection failed for invoice {}: {}", invoiceId, e.getMessage());
        }
    }

    // ── Manual lifecycle (controller path — TenantContext) ──────────────

    @Transactional
    public EwayBillResponse create(CreateEwayBillRequest req) {
        UUID orgId = requireOrgId();
        String docType = req.documentType().trim().toUpperCase();

        if (ewayBillRepository.existsByOrgIdAndDocumentTypeAndDocumentIdAndIsDeletedFalse(
                orgId, docType, req.documentId())) {
            throw new BusinessException("An e-way bill entry already exists for this document",
                    "EWB_DUPLICATE", HttpStatus.CONFLICT);
        }

        Organisation org = organisationRepository.findById(orgId).orElse(null);
        EwayBill ewb;
        if ("INVOICE".equals(docType)) {
            Invoice invoice = invoiceRepository
                    .findByIdAndOrgIdAndIsDeletedFalse(req.documentId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("Invoice", req.documentId()));
            Contact contact = contactRepository
                    .findByIdAndOrgIdAndIsDeletedFalse(invoice.getContactId(), orgId).orElse(null);
            ewb = EwayBill.builder()
                    .documentType("INVOICE")
                    .documentId(invoice.getId())
                    .documentNumber(invoice.getInvoiceNumber())
                    .documentDate(invoice.getInvoiceDate())
                    .contactId(invoice.getContactId())
                    .totalValue(nz(invoice.getTotalAmount()))
                    .fromStateCode(org != null ? org.getStateCode() : null)
                    .toStateCode(resolveToState(invoice.getPlaceOfSupply(), contact))
                    .build();
        } else if ("DELIVERY_CHALLAN".equals(docType)) {
            DeliveryChallan dc = deliveryChallanRepository
                    .findByIdAndOrgIdAndIsDeletedFalse(req.documentId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("DeliveryChallan", req.documentId()));
            Contact contact = contactRepository
                    .findByIdAndOrgIdAndIsDeletedFalse(dc.getContactId(), orgId).orElse(null);
            ewb = EwayBill.builder()
                    .documentType("DELIVERY_CHALLAN")
                    .documentId(dc.getId())
                    .documentNumber(dc.getChallanNumber())
                    .documentDate(dc.getDispatchDate() != null ? dc.getDispatchDate() : dc.getChallanDate())
                    .contactId(dc.getContactId())
                    .totalValue(BigDecimal.ZERO) // challans carry quantity, not value
                    .fromStateCode(org != null ? org.getStateCode() : null)
                    .toStateCode(contact != null ? contact.getBillingStateCode() : null)
                    .vehicleNumber(dc.getVehicleNumber())
                    .build();
        } else {
            throw new BusinessException("documentType must be INVOICE or DELIVERY_CHALLAN",
                    "EWB_BAD_DOCUMENT_TYPE", HttpStatus.BAD_REQUEST);
        }

        ewb.setStatus("PENDING");
        if (req.vehicleNumber() != null && !req.vehicleNumber().isBlank()) {
            ewb.setVehicleNumber(req.vehicleNumber().trim().toUpperCase());
        }
        if (req.transportMode() != null && !req.transportMode().isBlank()) {
            ewb.setTransportMode(req.transportMode().trim().toUpperCase());
        }
        ewb.setTransporterId(req.transporterId());
        ewb.setTransporterName(req.transporterName());
        ewb.setDistanceKm(req.distanceKm());
        ewb.setOrgId(orgId);
        return EwayBillResponse.from(ewayBillRepository.save(ewb));
    }

    @Transactional(readOnly = true)
    public List<EwayBillResponse> list(String status) {
        UUID orgId = requireOrgId();
        List<EwayBill> rows = (status == null || status.isBlank())
                ? ewayBillRepository.findByOrgIdAndIsDeletedFalseOrderByDocumentDateDescCreatedAtDesc(orgId)
                : ewayBillRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByDocumentDateDescCreatedAtDesc(
                        orgId, status.trim().toUpperCase());
        return rows.stream().map(EwayBillResponse::from).toList();
    }

    /** Record the EWB number obtained on the NIC portal. */
    @Transactional
    public EwayBillResponse recordGenerated(UUID id, RecordEwbRequest req) {
        UUID orgId = requireOrgId();
        EwayBill ewb = load(id, orgId);
        if ("CANCELLED".equals(ewb.getStatus())) {
            throw new BusinessException("This e-way bill entry is cancelled",
                    "EWB_CANCELLED", HttpStatus.BAD_REQUEST);
        }
        ewb.setEwbNumber(req.ewbNumber().trim());
        if (req.vehicleNumber() != null && !req.vehicleNumber().isBlank()) {
            ewb.setVehicleNumber(req.vehicleNumber().trim().toUpperCase());
        }
        Instant now = Instant.now();
        ewb.setStatus("GENERATED");
        ewb.setGeneratedAt(now);
        ewb.setValidUntil(req.validUntil() != null ? req.validUntil() : computeValidity(now, ewb.getDistanceKm()));
        return EwayBillResponse.from(ewayBillRepository.save(ewb));
    }

    @Transactional
    public EwayBillResponse cancel(UUID id, String reason) {
        UUID orgId = requireOrgId();
        EwayBill ewb = load(id, orgId);
        ewb.setStatus("CANCELLED");
        ewb.setCancelledAt(Instant.now());
        ewb.setCancelReason(reason);
        return EwayBillResponse.from(ewayBillRepository.save(ewb));
    }

    // ── Vehicle aggregate rule ───────────────────────────────────────────

    /**
     * The aggregate mandate: even if each document is below ₹50,000, when the
     * combined value moving in one vehicle crosses the threshold, every
     * document in that vehicle needs an e-way bill before transit.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> checkVehicle(VehicleCheckRequest req) {
        UUID orgId = requireOrgId();
        BigDecimal threshold = threshold(orgId);

        List<EwayBill> sameVehicle = ewayBillRepository
                .findByOrgIdAndVehicleNumberIgnoreCaseAndDocumentDateAndIsDeletedFalse(
                        orgId, req.vehicleNumber().trim(), req.date())
                .stream().filter(e -> !"CANCELLED".equals(e.getStatus())).toList();

        BigDecimal aggregate = sameVehicle.stream()
                .map(EwayBill::getTotalValue)
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .add(req.additionalValue() == null ? BigDecimal.ZERO : req.additionalValue());

        boolean required = aggregate.compareTo(threshold) >= 0;
        List<Map<String, Object>> docs = sameVehicle.stream().map(e -> {
            Map<String, Object> m = new LinkedHashMap<String, Object>();
            m.put("id", e.getId());
            m.put("documentNumber", e.getDocumentNumber());
            m.put("totalValue", e.getTotalValue());
            m.put("status", e.getStatus());
            m.put("ewbNumber", e.getEwbNumber());
            return m;
        }).toList();

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("vehicleNumber", req.vehicleNumber().trim().toUpperCase());
        result.put("date", req.date());
        result.put("aggregateValue", aggregate);
        result.put("threshold", threshold);
        result.put("ewayBillRequired", required);
        result.put("documents", docs);
        result.put("note", required
                ? "Combined value in this vehicle crosses the threshold — every document in it needs an e-way bill before transit, even those individually below the limit."
                : "Below the threshold. Re-check if more documents are loaded into this vehicle.");
        return result;
    }

    // ── NIC portal JSON ──────────────────────────────────────────────────

    /** NIC bulk-upload JSON for the document (invoices only — challans carry no value). */
    @Transactional(readOnly = true)
    public Map<String, Object> portalJson(UUID id) {
        UUID orgId = requireOrgId();
        EwayBill ewb = load(id, orgId);
        if (!"INVOICE".equals(ewb.getDocumentType())) {
            throw new BusinessException(
                    "Portal JSON is generated for invoices; create challan e-way bills on the portal directly",
                    "EWB_PORTAL_JSON_INVOICE_ONLY", HttpStatus.BAD_REQUEST);
        }
        Invoice invoice = invoiceRepository
                .findByIdAndOrgIdAndIsDeletedFalse(ewb.getDocumentId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", ewb.getDocumentId()));
        Organisation org = organisationRepository.findById(orgId).orElse(null);
        Contact contact = contactRepository
                .findByIdAndOrgIdAndIsDeletedFalse(invoice.getContactId(), orgId).orElse(null);

        boolean interState = ewb.getFromStateCode() != null && ewb.getToStateCode() != null
                && !ewb.getFromStateCode().equals(ewb.getToStateCode());

        BigDecimal taxable = BigDecimal.ZERO, cgst = BigDecimal.ZERO,
                sgst = BigDecimal.ZERO, igst = BigDecimal.ZERO;
        List<Map<String, Object>> itemList = new ArrayList<>();
        for (InvoiceLine line : invoice.getLines()) {
            BigDecimal rate = nz(line.getGstRate());
            BigDecimal lineTaxable = nz(line.getTaxableAmount());
            BigDecimal lineTax = nz(line.getTaxAmount());
            taxable = taxable.add(lineTaxable);
            if (interState) {
                igst = igst.add(lineTax);
            } else {
                cgst = cgst.add(lineTax.divide(BigDecimal.valueOf(2), 2, java.math.RoundingMode.HALF_UP));
                sgst = sgst.add(lineTax.subtract(
                        lineTax.divide(BigDecimal.valueOf(2), 2, java.math.RoundingMode.HALF_UP)));
            }
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("productName", line.getDescription());
            item.put("productDesc", line.getDescription());
            item.put("hsnCode", line.getHsnCode() == null ? "" : line.getHsnCode());
            item.put("quantity", nz(line.getQuantity()));
            item.put("qtyUnit", "NOS");
            item.put("taxableAmount", lineTaxable);
            item.put("cgstRate", interState ? BigDecimal.ZERO : half(rate));
            item.put("sgstRate", interState ? BigDecimal.ZERO : rate.subtract(half(rate)));
            item.put("igstRate", interState ? rate : BigDecimal.ZERO);
            item.put("cessRate", BigDecimal.ZERO);
            itemList.add(item);
        }

        Map<String, Object> json = new LinkedHashMap<>();
        json.put("version", "1.0.0421");
        Map<String, Object> billList = new LinkedHashMap<>();
        billList.put("supplyType", "O");
        billList.put("subSupplyType", "1");
        billList.put("docType", "INV");
        billList.put("docNo", invoice.getInvoiceNumber());
        billList.put("docDate", invoice.getInvoiceDate().format(NIC_DATE));
        billList.put("fromGstin", org != null && org.getGstin() != null ? org.getGstin() : "");
        billList.put("fromTrdName", org != null ? org.getName() : "");
        billList.put("fromStateCode", numeric(ewb.getFromStateCode()));
        billList.put("actFromStateCode", numeric(ewb.getFromStateCode()));
        billList.put("fromPincode", pincode(org != null ? org.getPostalCode() : null));
        billList.put("toGstin", contact != null && contact.getGstin() != null ? contact.getGstin() : "URP");
        billList.put("toTrdName", contact != null ? contact.getDisplayName() : "");
        billList.put("toStateCode", numeric(ewb.getToStateCode()));
        billList.put("actToStateCode", numeric(ewb.getToStateCode()));
        billList.put("toPincode", pincode(contact != null ? contact.getBillingPostalCode() : null));
        billList.put("totalValue", taxable);
        billList.put("cgstValue", cgst);
        billList.put("sgstValue", sgst);
        billList.put("igstValue", igst);
        billList.put("cessValue", BigDecimal.ZERO);
        billList.put("totInvValue", nz(invoice.getTotalAmount()));
        billList.put("transMode", transModeCode(ewb.getTransportMode()));
        billList.put("transDistance", ewb.getDistanceKm() == null ? "0" : ewb.getDistanceKm().toString());
        billList.put("transporterId", ewb.getTransporterId() == null ? "" : ewb.getTransporterId());
        billList.put("transporterName", ewb.getTransporterName() == null ? "" : ewb.getTransporterName());
        billList.put("vehicleNo", ewb.getVehicleNumber() == null ? "" : ewb.getVehicleNumber());
        billList.put("vehicleType", "R");
        billList.put("itemList", itemList);
        json.put("billLists", List.of(billList));
        return json;
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private void createRequiredSuggestion(UUID orgId, EwayBill ewb, BigDecimal threshold) {
        try {
            Map<String, Object> value = new LinkedHashMap<>();
            value.put("ewayBillId", ewb.getId().toString());
            value.put("documentNumber", ewb.getDocumentNumber());
            value.put("totalValue", ewb.getTotalValue().toPlainString());
            value.put("threshold", threshold.toPlainString());
            aiSuggestionService.createSuggestion(AiSuggestion.builder()
                    .orgId(orgId)
                    .entityType("EWAY_BILL")
                    .entityId(ewb.getId())
                    .suggestionType("EWAY_BILL_REQUIRED")
                    .suggestedAction("GENERATE_EWAY_BILL")
                    .suggestedValue(value)
                    .reasoning("Invoice " + ewb.getDocumentNumber() + " ("
                            + ewb.getTotalValue().toPlainString() + ") crosses the e-way bill threshold of "
                            + threshold.toPlainString()
                            + ". Generate the e-way bill on the NIC portal before goods move — "
                            + "download the prepared JSON from the GST screen, then record the EWB number.")
                    .confidence(new BigDecimal("0.950"))
                    .agentName("eway_bill_detector")
                    .modelName("deterministic_rules")
                    .modelVersion("1")
                    .promptVersion("none")
                    .priority("HIGH")
                    .priorityScore(new BigDecimal("85"))
                    .status("PENDING")
                    .build());
        } catch (Exception e) {
            log.warn("Could not create e-way bill suggestion for {}: {}", ewb.getId(), e.getMessage());
        }
    }

    private BigDecimal threshold(UUID orgId) {
        try {
            return new BigDecimal(orgSettingsService.get(orgId, THRESHOLD_SETTING, DEFAULT_THRESHOLD));
        } catch (NumberFormatException e) {
            return new BigDecimal(DEFAULT_THRESHOLD);
        }
    }

    /** EWB validity: one day per started 200 km, minimum one day. */
    Instant computeValidity(Instant from, Integer distanceKm) {
        int km = distanceKm == null || distanceKm <= 0 ? 1 : distanceKm;
        long days = (km + KM_PER_VALIDITY_DAY - 1L) / KM_PER_VALIDITY_DAY;
        return from.plus(Math.max(days, 1), ChronoUnit.DAYS);
    }

    private String resolveToState(String placeOfSupply, Contact contact) {
        if (placeOfSupply != null && !placeOfSupply.isBlank()) return placeOfSupply;
        return contact != null ? contact.getBillingStateCode() : null;
    }

    private EwayBill load(UUID id, UUID orgId) {
        return ewayBillRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("EwayBill", id));
    }

    private static BigDecimal half(BigDecimal rate) {
        return rate.divide(BigDecimal.valueOf(2), 2, java.math.RoundingMode.HALF_UP);
    }

    private static String transModeCode(String mode) {
        return switch (mode == null ? "ROAD" : mode) {
            case "RAIL" -> "2";
            case "AIR" -> "3";
            case "SHIP" -> "4";
            default -> "1";
        };
    }

    private static String numeric(String stateCode) {
        return stateCode == null ? "" : stateCode.trim();
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

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
