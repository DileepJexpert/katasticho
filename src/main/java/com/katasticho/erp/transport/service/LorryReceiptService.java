package com.katasticho.erp.transport.service;

import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.ap.dto.CreatePurchaseBillRequest;
import com.katasticho.erp.ap.dto.CreatePurchaseBillRequest.BillLineRequest;
import com.katasticho.erp.ap.dto.PurchaseBillResponse;
import com.katasticho.erp.ap.service.PurchaseBillService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.transport.dto.TransportDtos.*;
import com.katasticho.erp.transport.entity.LorryReceipt;
import com.katasticho.erp.transport.repository.LorryReceiptRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Lorry Receipt lifecycle + freight billing.
 *
 * <p><b>Lifecycle:</b> {@code DRAFT → ISSUED → DELIVERED}, with {@code CANCELLED}
 * from DRAFT/ISSUED. On create, if no freight amount is given the matching
 * {@link FreightRateCardService} rate auto-fills it.
 *
 * <p><b>Freight billing</b> (the AP half the audit flagged): for freight we bear
 * ({@code PAID} or {@code TO_BE_BILLED}), {@link #billFreight} raises a <b>DRAFT</b>
 * purchase bill to the transporter via {@link PurchaseBillService} — a SERVICE
 * line on HSN 9965 (GTA) at the LR's GST rate, with {@code reverseCharge=true}
 * when the GTA freight is under RCM. The bill is DRAFT so the owner reviews and
 * posts it through the normal AP path (which already handles GST, RCM, and TDS
 * 194C on transport contractors). {@code TO_PAY} freight is the consignee's cost
 * and is never billed to us.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class LorryReceiptService {

    static final String FREIGHT_ACCOUNT_SETTING = "transport.freight_account_code";
    static final String DEFAULT_FREIGHT_ACCOUNT = "5240";   // Travel & Conveyance (seed CoA)
    private static final String GTA_HSN = "9965";
    private static final Set<String> CANCELLABLE = Set.of("DRAFT", "ISSUED");
    private static final Set<String> BILLABLE_BASIS = Set.of("PAID", "TO_BE_BILLED");

    private final LorryReceiptRepository repository;
    private final FreightRateCardService rateCardService;
    private final PurchaseBillService purchaseBillService;
    private final AccountRepository accountRepository;
    private final OrgSettingsService orgSettingsService;

    // ── Create / lifecycle ───────────────────────────────────────────────

    @Transactional
    public LorryReceiptResponse create(CreateLorryReceiptRequest req) {
        UUID orgId = requireOrgId();

        BigDecimal freight = req.freightAmount();
        // Auto-fill from a rate card when not supplied.
        if (freight == null || freight.signum() == 0) {
            RateQuoteResponse quote = rateCardService.resolveRate(
                    req.transporterContactId(), req.origin(), req.destination(),
                    req.mode(), req.weightKg());
            if (quote.found()) freight = quote.freightAmount();
        }

        LorryReceipt lr = LorryReceipt.builder()
                .lrNumber(nextLrNumber(orgId))
                .lrDate(req.lrDate())
                .transporterContactId(req.transporterContactId())
                .contactId(req.contactId())
                .deliveryChallanId(req.deliveryChallanId())
                .invoiceId(req.invoiceId())
                .ewayBillNo(req.ewayBillNo())
                .vehicleNumber(req.vehicleNumber())
                .driverName(req.driverName())
                .driverPhone(req.driverPhone())
                .origin(req.origin())
                .destination(req.destination())
                .distanceKm(req.distanceKm())
                .mode(orDefault(req.mode(), "ROAD").toUpperCase())
                .numPackages(req.numPackages())
                .weightKg(req.weightKg())
                .declaredValue(req.declaredValue())
                .freightAmount(nz(freight))
                .freightBasis(orDefault(req.freightBasis(), "TO_BE_BILLED").toUpperCase())
                .gstTreatment(orDefault(req.gstTreatment(), "RCM").toUpperCase())
                .freightGstRate(req.freightGstRate() == null ? new BigDecimal("5") : req.freightGstRate())
                .notes(req.notes())
                .build();
        lr.setOrgId(orgId);
        lr = repository.save(lr);
        log.info("Lorry receipt {} created (transporter {}, freight {}, basis {}) for org {}",
                lr.getLrNumber(), lr.getTransporterContactId(), lr.getFreightAmount(),
                lr.getFreightBasis(), orgId);
        return toResponse(lr);
    }

    @Transactional
    public LorryReceiptResponse issue(UUID id) {
        return transition(id, "DRAFT", "ISSUED");
    }

    @Transactional
    public LorryReceiptResponse markDelivered(UUID id) {
        return transition(id, "ISSUED", "DELIVERED");
    }

    @Transactional
    public LorryReceiptResponse cancel(UUID id, String reason) {
        LorryReceipt lr = require(id);
        if (!CANCELLABLE.contains(lr.getStatus())) {
            throw new BusinessException(
                    "Cannot cancel an LR in status " + lr.getStatus(),
                    "LR_NOT_CANCELLABLE", HttpStatus.CONFLICT);
        }
        if (lr.getFreightBillId() != null) {
            throw new BusinessException(
                    "Freight already billed — void the purchase bill first",
                    "LR_FREIGHT_BILLED", HttpStatus.CONFLICT);
        }
        lr.setStatus("CANCELLED");
        if (reason != null && !reason.isBlank()) {
            lr.setNotes((lr.getNotes() == null ? "" : lr.getNotes() + "\n") + "Cancelled: " + reason);
        }
        repository.save(lr);
        return toResponse(lr);
    }

    // ── Freight billing ──────────────────────────────────────────────────

    /** Raise a DRAFT purchase bill to the transporter for this LR's freight. */
    @Transactional
    public BillFreightResult billFreight(UUID id) {
        UUID orgId = requireOrgId();
        LorryReceipt lr = require(id);

        if (lr.getFreightBillId() != null) {
            throw new BusinessException(
                    "Freight already billed for this LR", "LR_ALREADY_BILLED", HttpStatus.CONFLICT);
        }
        if (!BILLABLE_BASIS.contains(lr.getFreightBasis())) {
            throw new BusinessException(
                    "Freight basis " + lr.getFreightBasis() + " is not billable to you "
                            + "(only PAID / TO_BE_BILLED)", "LR_NOT_BILLABLE", HttpStatus.BAD_REQUEST);
        }
        if (lr.getFreightAmount() == null || lr.getFreightAmount().signum() <= 0) {
            throw new BusinessException(
                    "Freight amount is zero — set it before billing", "LR_NO_FREIGHT", HttpStatus.BAD_REQUEST);
        }

        boolean rcm = "RCM".equals(lr.getGstTreatment());
        BigDecimal gstRate = "EXEMPT".equals(lr.getGstTreatment())
                ? BigDecimal.ZERO : nz(lr.getFreightGstRate());

        String freightAccount = resolveFreightAccountCode(orgId);
        BillLineRequest line = new BillLineRequest(
                "SERVICE",
                "Freight — LR " + lr.getLrNumber()
                        + (lr.getOrigin() != null ? " (" + lr.getOrigin() + "→" + lr.getDestination() + ")" : ""),
                GTA_HSN, null, null, freightAccount,
                BigDecimal.ONE, lr.getFreightAmount(), BigDecimal.ZERO, gstRate, null, null, null);

        CreatePurchaseBillRequest billReq = new CreatePurchaseBillRequest(
                lr.getTransporterContactId(),
                lr.getLrNumber(),
                lr.getLrDate(),
                null, null,
                rcm,                       // reverseCharge for GTA RCM
                "Freight for LR " + lr.getLrNumber(),
                null, null,
                List.of(line));

        PurchaseBillResponse bill = purchaseBillService.createBill(billReq);
        lr.setFreightBillId(bill.id());
        repository.save(lr);

        log.info("Freight DRAFT bill {} raised for LR {} (₹{}, RCM={}) org {}",
                bill.billNumber(), lr.getLrNumber(), lr.getFreightAmount(), rcm, orgId);
        return new BillFreightResult(lr.getId(), bill.id(), bill.billNumber(), lr.getFreightAmount(), rcm,
                "Draft bill " + bill.billNumber() + " raised to the transporter"
                        + (rcm ? " (GTA reverse charge — review & post)" : " — review & post"));
    }

    // ── Queries ──────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public LorryReceiptResponse get(UUID id) {
        return toResponse(require(id));
    }

    @Transactional(readOnly = true)
    public List<LorryReceiptResponse> list(String status) {
        UUID orgId = requireOrgId();
        List<LorryReceipt> rows = (status == null || status.isBlank())
                ? repository.findByOrgIdAndIsDeletedFalseOrderByLrDateDesc(orgId)
                : repository.findByOrgIdAndStatusAndIsDeletedFalseOrderByLrDateDesc(orgId, status.toUpperCase());
        return rows.stream().map(this::toResponse).toList();
    }

    // ── Internals ────────────────────────────────────────────────────────

    private LorryReceiptResponse transition(UUID id, String from, String to) {
        LorryReceipt lr = require(id);
        if (!from.equals(lr.getStatus())) {
            throw new BusinessException(
                    "LR must be " + from + " to become " + to + " (current: " + lr.getStatus() + ")",
                    "LR_BAD_STATE", HttpStatus.CONFLICT);
        }
        lr.setStatus(to);
        repository.save(lr);
        return toResponse(lr);
    }

    private String resolveFreightAccountCode(UUID orgId) {
        String code = orgSettingsService.getAll(orgId)
                .getOrDefault(FREIGHT_ACCOUNT_SETTING, DEFAULT_FREIGHT_ACCOUNT);
        // If the configured/default code doesn't exist, let the bill fall back to
        // the org's default PURCHASE account (resolveLineAccount handles null).
        return accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, code).isPresent() ? code : null;
    }

    private LorryReceipt require(UUID id) {
        return repository.findByIdAndOrgIdAndIsDeletedFalse(id, requireOrgId())
                .orElseThrow(() -> new BusinessException(
                        "Lorry receipt not found", "LR_NOT_FOUND", HttpStatus.NOT_FOUND));
    }

    private LorryReceiptResponse toResponse(LorryReceipt lr) {
        return new LorryReceiptResponse(lr.getId(), lr.getLrNumber(), lr.getLrDate(),
                lr.getTransporterContactId(), lr.getContactId(), lr.getDeliveryChallanId(),
                lr.getInvoiceId(), lr.getEwayBillNo(), lr.getVehicleNumber(), lr.getDriverName(),
                lr.getDriverPhone(), lr.getOrigin(), lr.getDestination(), lr.getDistanceKm(),
                lr.getMode(), lr.getNumPackages(), lr.getWeightKg(), lr.getDeclaredValue(),
                lr.getFreightAmount(), lr.getFreightBasis(), lr.getGstTreatment(),
                lr.getFreightGstRate(), lr.getFreightBillId(), lr.getStatus(), lr.getNotes());
    }

    private String nextLrNumber(UUID orgId) {
        long count = repository.countByOrgIdAndIsDeletedFalse(orgId);
        return String.format("LR-%05d", count + 1);
    }

    private static String orDefault(String v, String def) {
        return v == null || v.isBlank() ? def : v;
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
