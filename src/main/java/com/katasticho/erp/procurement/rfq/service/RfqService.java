package com.katasticho.erp.procurement.rfq.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.procurement.dto.PurchaseOrderRequest;
import com.katasticho.erp.procurement.dto.PurchaseOrderResponse;
import com.katasticho.erp.procurement.entity.Supplier;
import com.katasticho.erp.procurement.repository.SupplierRepository;
import com.katasticho.erp.procurement.rfq.dto.AwardResponse;
import com.katasticho.erp.procurement.rfq.dto.CompareQuotesResponse;
import com.katasticho.erp.procurement.rfq.dto.CreateRfqRequest;
import com.katasticho.erp.procurement.rfq.dto.QuoteResponse;
import com.katasticho.erp.procurement.rfq.dto.RecordQuoteRequest;
import com.katasticho.erp.procurement.rfq.dto.RfqResponse;
import com.katasticho.erp.procurement.rfq.entity.Rfq;
import com.katasticho.erp.procurement.rfq.entity.RfqLine;
import com.katasticho.erp.procurement.rfq.entity.RfqSupplier;
import com.katasticho.erp.procurement.rfq.entity.SupplierQuote;
import com.katasticho.erp.procurement.rfq.entity.SupplierQuoteLine;
import com.katasticho.erp.procurement.rfq.repository.RfqLineRepository;
import com.katasticho.erp.procurement.rfq.repository.RfqRepository;
import com.katasticho.erp.procurement.rfq.repository.RfqSupplierRepository;
import com.katasticho.erp.procurement.rfq.repository.SupplierQuoteLineRepository;
import com.katasticho.erp.procurement.rfq.repository.SupplierQuoteRepository;
import com.katasticho.erp.procurement.service.PurchaseOrderService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Lazy;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.Year;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

/**
 * RFQ → supplier quotation compare → award → drafted PO.
 *
 * <p>The buyer drafts an RFQ with line items + a list of candidate suppliers
 * (Contact ids, VENDOR or BOTH). Each supplier returns a {@link SupplierQuote}
 * with prices + lead time. The buyer compares (lowest-per-line + lowest-total)
 * and awards a winner; the service then drafts a {@link com.katasticho.erp.procurement.entity.PurchaseOrder}
 * with the winning quote's prices.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class RfqService {

    private static final List<String> TERMINAL_STATUSES = List.of("AWARDED", "CANCELLED");

    private final RfqRepository rfqRepository;
    private final RfqLineRepository rfqLineRepository;
    private final RfqSupplierRepository rfqSupplierRepository;
    private final SupplierQuoteRepository supplierQuoteRepository;
    private final SupplierQuoteLineRepository supplierQuoteLineRepository;
    private final ContactRepository contactRepository;
    private final SupplierRepository supplierRepository;
    @Lazy private final PurchaseOrderService purchaseOrderService;

    // ── Create ──

    @Transactional
    public RfqResponse createRfq(CreateRfqRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        if (request.lines() == null || request.lines().isEmpty()) {
            throw new BusinessException("RFQ must have at least one line", "RFQ_EMPTY_LINES",
                    HttpStatus.BAD_REQUEST);
        }
        if (request.supplierContactIds() == null || request.supplierContactIds().isEmpty()) {
            throw new BusinessException("RFQ must target at least one supplier",
                    "RFQ_NO_SUPPLIERS", HttpStatus.BAD_REQUEST);
        }

        // Validate each supplier contact (VENDOR or BOTH).
        for (UUID contactId : request.supplierContactIds()) {
            Contact c = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId)
                    .orElseThrow(() -> BusinessException.notFound("Contact", contactId));
            if (c.getContactType() != ContactType.VENDOR && c.getContactType() != ContactType.BOTH) {
                throw new BusinessException(
                        "Contact '" + c.getDisplayName() + "' is not a vendor",
                        "RFQ_NOT_VENDOR", HttpStatus.BAD_REQUEST);
            }
        }

        String rfqNumber = generateRfqNumber(orgId);

        Rfq rfq = Rfq.builder()
                .rfqNumber(rfqNumber)
                .title(request.title())
                .status("DRAFT")
                .dueDate(request.dueDate())
                .notes(request.notes())
                .build();
        rfq.setOrgId(orgId);
        rfq = rfqRepository.save(rfq);

        List<RfqLine> lines = new ArrayList<>();
        for (CreateRfqRequest.LineRequest lr : request.lines()) {
            RfqLine line = RfqLine.builder()
                    .rfqId(rfq.getId())
                    .itemId(lr.itemId())
                    .description(lr.description())
                    .quantity(lr.quantity().setScale(4, RoundingMode.HALF_UP))
                    .hsnCode(lr.hsnCode())
                    .gstRate(lr.gstRate())
                    .build();
            line.setOrgId(orgId);
            lines.add(line);
        }
        rfqLineRepository.saveAll(lines);

        List<RfqSupplier> suppliers = new ArrayList<>();
        for (UUID contactId : request.supplierContactIds()) {
            RfqSupplier rs = RfqSupplier.builder()
                    .rfqId(rfq.getId())
                    .supplierContactId(contactId)
                    .build();
            rs.setOrgId(orgId);
            suppliers.add(rs);
        }
        rfqSupplierRepository.saveAll(suppliers);

        log.info("RFQ {} created with {} lines, {} suppliers",
                rfq.getRfqNumber(), lines.size(), suppliers.size());
        return toResponse(rfq, lines, suppliers);
    }

    // ── Send ──

    @Transactional
    public RfqResponse send(UUID rfqId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Rfq rfq = getOrThrow(rfqId, orgId);

        if (!"DRAFT".equals(rfq.getStatus())) {
            throw new BusinessException("Only DRAFT RFQs can be sent",
                    "RFQ_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }
        rfq.setStatus("SENT");
        rfq = rfqRepository.save(rfq);
        log.info("RFQ {} sent", rfq.getRfqNumber());

        return toResponse(rfq,
                rfqLineRepository.findByRfqIdAndIsDeletedFalseOrderByCreatedAtAsc(rfq.getId()),
                rfqSupplierRepository.findByRfqIdAndIsDeletedFalse(rfq.getId()));
    }

    // ── Cancel ──

    @Transactional
    public RfqResponse cancel(UUID rfqId, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Rfq rfq = getOrThrow(rfqId, orgId);

        if (TERMINAL_STATUSES.contains(rfq.getStatus())) {
            throw new BusinessException("Cannot cancel a " + rfq.getStatus() + " RFQ",
                    "RFQ_TERMINAL", HttpStatus.BAD_REQUEST);
        }
        rfq.setStatus("CANCELLED");
        if (reason != null && !reason.isBlank()) {
            String existing = rfq.getNotes() == null ? "" : rfq.getNotes();
            rfq.setNotes((existing + "\nCancelled: " + reason).trim());
        }
        rfq = rfqRepository.save(rfq);
        log.info("RFQ {} cancelled", rfq.getRfqNumber());

        return toResponse(rfq,
                rfqLineRepository.findByRfqIdAndIsDeletedFalseOrderByCreatedAtAsc(rfq.getId()),
                rfqSupplierRepository.findByRfqIdAndIsDeletedFalse(rfq.getId()));
    }

    // ── Record a quote ──

    @Transactional
    public QuoteResponse recordQuote(UUID rfqId, RecordQuoteRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Rfq rfq = getOrThrow(rfqId, orgId);

        if (TERMINAL_STATUSES.contains(rfq.getStatus())) {
            throw new BusinessException(
                    "Cannot record quote against a " + rfq.getStatus() + " RFQ",
                    "RFQ_TERMINAL", HttpStatus.BAD_REQUEST);
        }

        Contact supplier = contactRepository
                .findByIdAndOrgIdAndIsDeletedFalse(request.supplierContactId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", request.supplierContactId()));
        if (supplier.getContactType() != ContactType.VENDOR
                && supplier.getContactType() != ContactType.BOTH) {
            throw new BusinessException(
                    "Contact '" + supplier.getDisplayName() + "' is not a vendor",
                    "RFQ_NOT_VENDOR", HttpStatus.BAD_REQUEST);
        }

        String quoteNumber = (request.quoteNumber() != null && !request.quoteNumber().isBlank())
                ? request.quoteNumber()
                : generateQuoteNumber(orgId);

        BigDecimal total = BigDecimal.ZERO;
        for (RecordQuoteRequest.QuoteLineRequest lr : request.lines()) {
            BigDecimal qty = lr.quantity().setScale(4, RoundingMode.HALF_UP);
            BigDecimal price = lr.unitPrice().setScale(4, RoundingMode.HALF_UP);
            total = total.add(qty.multiply(price));
        }

        SupplierQuote quote = SupplierQuote.builder()
                .rfqId(rfqId)
                .supplierContactId(request.supplierContactId())
                .quoteNumber(quoteNumber)
                .validUntil(request.validUntil())
                .totalAmount(total.setScale(2, RoundingMode.HALF_UP))
                .currency("INR")
                .status("RECEIVED")
                .notes(request.notes())
                .build();
        quote.setOrgId(orgId);
        quote = supplierQuoteRepository.save(quote);

        List<SupplierQuoteLine> lines = new ArrayList<>();
        for (RecordQuoteRequest.QuoteLineRequest lr : request.lines()) {
            SupplierQuoteLine line = SupplierQuoteLine.builder()
                    .supplierQuoteId(quote.getId())
                    .itemId(lr.itemId())
                    .description(lr.description())
                    .quantity(lr.quantity().setScale(4, RoundingMode.HALF_UP))
                    .unitPrice(lr.unitPrice().setScale(4, RoundingMode.HALF_UP))
                    .leadTimeDays(lr.leadTimeDays())
                    .notes(lr.notes())
                    .build();
            line.setOrgId(orgId);
            lines.add(line);
        }
        supplierQuoteLineRepository.saveAll(lines);

        log.info("Quote {} recorded for RFQ {} from supplier contact {} (total {})",
                quote.getQuoteNumber(), rfq.getRfqNumber(),
                request.supplierContactId(), quote.getTotalAmount());

        return toQuoteResponse(quote, lines);
    }

    // ── Compare ──

    @Transactional(readOnly = true)
    public CompareQuotesResponse compareQuotes(UUID rfqId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        getOrThrow(rfqId, orgId);

        List<SupplierQuote> quotes = supplierQuoteRepository
                .findByRfqIdAndIsDeletedFalseOrderByTotalAmountAsc(rfqId);
        if (quotes.isEmpty()) {
            return new CompareQuotesResponse(rfqId, null, List.of(), List.of());
        }

        List<UUID> quoteIds = quotes.stream().map(SupplierQuote::getId).toList();
        List<SupplierQuoteLine> allLines =
                supplierQuoteLineRepository.findBySupplierQuoteIdInAndIsDeletedFalse(quoteIds);

        // Per-supplier summary (avg lead time across lines).
        Map<UUID, List<SupplierQuoteLine>> linesByQuote = new HashMap<>();
        for (SupplierQuoteLine l : allLines) {
            linesByQuote.computeIfAbsent(l.getSupplierQuoteId(), k -> new ArrayList<>()).add(l);
        }
        List<CompareQuotesResponse.SupplierSummary> summaries = new ArrayList<>();
        for (SupplierQuote q : quotes) {
            List<SupplierQuoteLine> lines = linesByQuote.getOrDefault(q.getId(), List.of());
            var leadAvg = lines.stream()
                    .map(SupplierQuoteLine::getLeadTimeDays)
                    .filter(Objects::nonNull)
                    .mapToInt(Integer::intValue)
                    .average();
            Integer avgLead = leadAvg.isPresent() ? (int) Math.round(leadAvg.getAsDouble()) : null;
            summaries.add(new CompareQuotesResponse.SupplierSummary(
                    q.getId(), q.getSupplierContactId(), q.getQuoteNumber(),
                    q.getTotalAmount(), avgLead, q.getStatus()));
        }

        // Per-line comparison — group by (itemId if not null) else description.
        // Each group lists every quote that has a line matching the key with
        // a per-supplier price, and reports the lowest-priced quote id.
        Map<String, List<SupplierQuoteLine>> linesByKey = new HashMap<>();
        for (SupplierQuoteLine l : allLines) {
            String key = lineKey(l.getItemId(), l.getDescription());
            linesByKey.computeIfAbsent(key, k -> new ArrayList<>()).add(l);
        }
        List<CompareQuotesResponse.LineComparison> comparisons = new ArrayList<>();
        for (var entry : linesByKey.entrySet()) {
            List<SupplierQuoteLine> linesForKey = entry.getValue();
            SupplierQuoteLine first = linesForKey.get(0);
            SupplierQuoteLine lowest = linesForKey.stream()
                    .min((a, b) -> a.getUnitPrice().compareTo(b.getUnitPrice()))
                    .orElse(first);
            List<CompareQuotesResponse.LineComparison.PerSupplierPrice> perSupplier =
                    linesForKey.stream()
                            .map(l -> new CompareQuotesResponse.LineComparison.PerSupplierPrice(
                                    l.getSupplierQuoteId(),
                                    quotes.stream()
                                            .filter(q -> q.getId().equals(l.getSupplierQuoteId()))
                                            .findFirst().map(SupplierQuote::getSupplierContactId)
                                            .orElse(null),
                                    l.getUnitPrice(),
                                    l.getLeadTimeDays()))
                            .toList();
            comparisons.add(new CompareQuotesResponse.LineComparison(
                    first.getItemId(),
                    first.getDescription(),
                    first.getQuantity(),
                    lowest.getSupplierQuoteId(),
                    lowest.getUnitPrice(),
                    perSupplier));
        }

        return new CompareQuotesResponse(
                rfqId,
                quotes.get(0).getId(),   // ordered asc by totalAmount
                summaries,
                comparisons);
    }

    // ── Award ──

    @Transactional
    public AwardResponse award(UUID rfqId, UUID winningQuoteId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Rfq rfq = getOrThrow(rfqId, orgId);

        if (!"DRAFT".equals(rfq.getStatus()) && !"SENT".equals(rfq.getStatus())) {
            throw new BusinessException("Only DRAFT or SENT RFQs can be awarded",
                    "RFQ_NOT_AWARDABLE", HttpStatus.BAD_REQUEST);
        }

        SupplierQuote winner = supplierQuoteRepository
                .findByIdAndOrgIdAndIsDeletedFalse(winningQuoteId, orgId)
                .orElseThrow(() -> BusinessException.notFound("SupplierQuote", winningQuoteId));
        if (!winner.getRfqId().equals(rfqId)) {
            throw new BusinessException("Quote does not belong to this RFQ",
                    "RFQ_QUOTE_MISMATCH", HttpStatus.BAD_REQUEST);
        }

        // Resolve / auto-create a procurement Supplier from the supplier contact.
        Contact vendorContact = contactRepository
                .findByIdAndOrgIdAndIsDeletedFalse(winner.getSupplierContactId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", winner.getSupplierContactId()));
        Supplier supplier = resolveOrCreateSupplier(orgId, vendorContact);

        // Build PO line requests from the winning quote's lines (item required by PO line DTO).
        List<SupplierQuoteLine> winningLines =
                supplierQuoteLineRepository.findBySupplierQuoteIdAndIsDeletedFalseOrderByCreatedAtAsc(
                        winner.getId());
        List<PurchaseOrderRequest.LineRequest> poLines = new ArrayList<>();
        for (SupplierQuoteLine wl : winningLines) {
            if (wl.getItemId() == null) {
                // Skip free-text lines — can't create a PO line without an item id.
                log.warn("Skipping quote line without item_id (description='{}') in award→PO",
                        wl.getDescription());
                continue;
            }
            poLines.add(new PurchaseOrderRequest.LineRequest(
                    wl.getItemId(),
                    wl.getDescription(),
                    wl.getQuantity(),
                    wl.getUnitPrice(),
                    null));
        }
        if (poLines.isEmpty()) {
            throw new BusinessException(
                    "Winning quote has no item-linked lines — cannot draft a PO",
                    "RFQ_AWARD_NO_PO_LINES", HttpStatus.BAD_REQUEST);
        }

        PurchaseOrderRequest poRequest = new PurchaseOrderRequest(
                supplier.getId(),
                LocalDate.now(),
                null,
                "Auto-drafted from RFQ " + rfq.getRfqNumber() + " (award)",
                null,
                poLines);
        PurchaseOrderResponse po = purchaseOrderService.create(poRequest);

        // Stamp lifecycle status changes.
        winner.setStatus("AWARDED");
        supplierQuoteRepository.save(winner);

        for (SupplierQuote sibling : supplierQuoteRepository
                .findByRfqIdAndIsDeletedFalseOrderByTotalAmountAsc(rfqId)) {
            if (!sibling.getId().equals(winner.getId()) && "RECEIVED".equals(sibling.getStatus())) {
                sibling.setStatus("REJECTED");
                supplierQuoteRepository.save(sibling);
            }
        }

        rfq.setStatus("AWARDED");
        rfqRepository.save(rfq);

        log.info("RFQ {} awarded to quote {} (PO {} drafted)",
                rfq.getRfqNumber(), winner.getQuoteNumber(), po.poNumber());

        return new AwardResponse(rfqId, winner.getId(), po);
    }

    // ── Read ──

    @Transactional(readOnly = true)
    public RfqResponse get(UUID rfqId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Rfq rfq = getOrThrow(rfqId, orgId);
        return toResponse(rfq,
                rfqLineRepository.findByRfqIdAndIsDeletedFalseOrderByCreatedAtAsc(rfq.getId()),
                rfqSupplierRepository.findByRfqIdAndIsDeletedFalse(rfq.getId()));
    }

    @Transactional(readOnly = true)
    public Page<RfqResponse> list(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return rfqRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pageable)
                .map(rfq -> toResponse(rfq,
                        rfqLineRepository.findByRfqIdAndIsDeletedFalseOrderByCreatedAtAsc(rfq.getId()),
                        rfqSupplierRepository.findByRfqIdAndIsDeletedFalse(rfq.getId())));
    }

    @Transactional(readOnly = true)
    public List<QuoteResponse> listQuotes(UUID rfqId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        getOrThrow(rfqId, orgId);
        List<SupplierQuote> quotes =
                supplierQuoteRepository.findByRfqIdAndIsDeletedFalseOrderByTotalAmountAsc(rfqId);
        return quotes.stream().map(q -> toQuoteResponse(q,
                supplierQuoteLineRepository
                        .findBySupplierQuoteIdAndIsDeletedFalseOrderByCreatedAtAsc(q.getId())))
                .toList();
    }

    // ── Helpers ──

    private Rfq getOrThrow(UUID rfqId, UUID orgId) {
        return rfqRepository.findByIdAndOrgIdAndIsDeletedFalse(rfqId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Rfq", rfqId));
    }

    private String generateRfqNumber(UUID orgId) {
        long count = rfqRepository.countByOrgIdAndIsDeletedFalse(orgId) + 1;
        return String.format("RFQ-%d-%05d", Year.now().getValue(), count);
    }

    private String generateQuoteNumber(UUID orgId) {
        long count = supplierQuoteRepository.countByOrgIdAndIsDeletedFalse(orgId) + 1;
        return String.format("SQ-%d-%05d", Year.now().getValue(), count);
    }

    private Supplier resolveOrCreateSupplier(UUID orgId, Contact contact) {
        Optional<Supplier> existing = supplierRepository
                .findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, contact.getDisplayName());
        if (existing.isPresent()) return existing.get();
        Supplier s = Supplier.builder()
                .name(contact.getDisplayName())
                .gstin(contact.getGstin())
                .build();
        s.setOrgId(orgId);
        return supplierRepository.save(s);
    }

    private String lineKey(UUID itemId, String description) {
        if (itemId != null) return "item:" + itemId;
        return "desc:" + (description == null ? "" : description.toLowerCase());
    }

    private RfqResponse toResponse(Rfq rfq, List<RfqLine> lines, List<RfqSupplier> suppliers) {
        List<RfqResponse.LineResponse> lineResponses = lines.stream()
                .map(l -> new RfqResponse.LineResponse(
                        l.getId(), l.getItemId(), l.getDescription(),
                        l.getQuantity(), l.getHsnCode(), l.getGstRate()))
                .toList();
        List<UUID> supplierIds = suppliers.stream()
                .map(RfqSupplier::getSupplierContactId).toList();
        return new RfqResponse(
                rfq.getId(), rfq.getOrgId(), rfq.getRfqNumber(), rfq.getTitle(),
                rfq.getStatus(), rfq.getDueDate(), rfq.getNotes(),
                lineResponses, supplierIds, rfq.getCreatedAt());
    }

    private QuoteResponse toQuoteResponse(SupplierQuote q, List<SupplierQuoteLine> lines) {
        List<QuoteResponse.LineResponse> lineResponses = lines.stream()
                .map(l -> new QuoteResponse.LineResponse(
                        l.getId(), l.getItemId(), l.getDescription(),
                        l.getQuantity(), l.getUnitPrice(), l.getLeadTimeDays(), l.getNotes()))
                .toList();
        return new QuoteResponse(
                q.getId(), q.getRfqId(), q.getSupplierContactId(), q.getQuoteNumber(),
                q.getValidUntil(), q.getTotalAmount(), q.getCurrency(), q.getStatus(),
                q.getNotes(), lineResponses, q.getCreatedAt());
    }
}
