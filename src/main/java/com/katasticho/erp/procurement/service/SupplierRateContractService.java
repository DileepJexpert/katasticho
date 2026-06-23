package com.katasticho.erp.procurement.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.procurement.dto.CreateSupplierRateContractRequest;
import com.katasticho.erp.procurement.dto.SupplierRateContractResponse;
import com.katasticho.erp.procurement.entity.Supplier;
import com.katasticho.erp.procurement.entity.SupplierRateContract;
import com.katasticho.erp.procurement.entity.SupplierRateContractLine;
import com.katasticho.erp.procurement.repository.SupplierRateContractLineRepository;
import com.katasticho.erp.procurement.repository.SupplierRateContractRepository;
import com.katasticho.erp.procurement.repository.SupplierRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.LocalDate;
import java.time.Year;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Supplier rate contracts — negotiated unit prices per (supplier, item) that
 * automatically default a PO line when the planner doesn't enter one
 * explicitly. Mirrors {@link com.katasticho.erp.pricing.service.PriceListService}
 * on the sell side.
 *
 * <p>Lifecycle DRAFT → ACTIVE → EXPIRED/CANCELLED. One ACTIVE contract per
 * (org, supplier, item) — activate() refuses to land a second.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class SupplierRateContractService {

    private static final List<String> TERMINAL = List.of("EXPIRED", "CANCELLED");

    private final SupplierRateContractRepository contractRepository;
    private final SupplierRateContractLineRepository lineRepository;
    private final ContactRepository contactRepository;
    private final SupplierRepository supplierRepository;
    private final ItemRepository itemRepository;
    private final OrganisationRepository organisationRepository;
    private final Clock clock;

    // ── Create ──

    @Transactional
    public SupplierRateContractResponse create(CreateSupplierRateContractRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Contact vendor = contactRepository
                .findByIdAndOrgIdAndIsDeletedFalse(request.supplierContactId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", request.supplierContactId()));
        if (vendor.getContactType() != ContactType.VENDOR
                && vendor.getContactType() != ContactType.BOTH) {
            throw new BusinessException(
                    "Contact '" + vendor.getDisplayName() + "' is not a vendor",
                    "SRC_NOT_VENDOR", HttpStatus.BAD_REQUEST);
        }

        if (request.lines() == null || request.lines().isEmpty()) {
            throw new BusinessException("Contract must have at least one line",
                    "SRC_EMPTY_LINES", HttpStatus.BAD_REQUEST);
        }

        // Validate every item exists in this org.
        for (var lr : request.lines()) {
            itemRepository.findByIdAndOrgIdAndIsDeletedFalse(lr.itemId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("Item", lr.itemId()));
            if (lr.unitPrice().signum() <= 0) {
                throw new BusinessException(
                        "Unit price must be > 0", "SRC_INVALID_PRICE",
                        HttpStatus.BAD_REQUEST);
            }
        }

        LocalDate validFrom = request.validFrom() != null
                ? request.validFrom() : LocalDate.now(clock);
        if (request.validUntil() != null && request.validUntil().isBefore(validFrom)) {
            throw new BusinessException("validUntil cannot precede validFrom",
                    "SRC_INVALID_RANGE", HttpStatus.BAD_REQUEST);
        }

        SupplierRateContract contract = SupplierRateContract.builder()
                .contractNumber(generateContractNumber(orgId))
                .supplierContactId(request.supplierContactId())
                .status("DRAFT")
                .validFrom(validFrom)
                .validUntil(request.validUntil())
                .currency("INR")
                .notes(request.notes())
                .build();
        contract.setOrgId(orgId);
        contract = contractRepository.save(contract);

        List<SupplierRateContractLine> lines = new ArrayList<>();
        for (var lr : request.lines()) {
            SupplierRateContractLine line = SupplierRateContractLine.builder()
                    .supplierRateContractId(contract.getId())
                    .itemId(lr.itemId())
                    .unitPrice(lr.unitPrice().setScale(2, RoundingMode.HALF_UP))
                    .minOrderQty(lr.minOrderQty() != null
                            ? lr.minOrderQty().setScale(4, RoundingMode.HALF_UP)
                            : BigDecimal.ZERO)
                    .notes(lr.notes())
                    .build();
            line.setOrgId(orgId);
            lines.add(line);
        }
        lineRepository.saveAll(lines);

        log.info("SupplierRateContract {} drafted ({} lines) for supplier {}",
                contract.getContractNumber(), lines.size(), request.supplierContactId());
        return toResponse(contract, lines);
    }

    // ── Activate ──

    @Transactional
    public SupplierRateContractResponse activate(UUID contractId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SupplierRateContract contract = getOrThrow(contractId, orgId);

        if (!"DRAFT".equals(contract.getStatus())) {
            throw new BusinessException(
                    "Only DRAFT contracts can be activated", "SRC_NOT_DRAFT",
                    HttpStatus.BAD_REQUEST);
        }

        List<SupplierRateContractLine> lines = lineRepository
                .findBySupplierRateContractIdAndIsDeletedFalseOrderByCreatedAtAsc(contractId);

        // Refuse to activate when any line collides with an existing ACTIVE
        // contract for the same (org, supplier, item) — one-active-at-a-time
        // is the rule.
        for (SupplierRateContractLine line : lines) {
            Optional<SupplierRateContractLine> existing = lineRepository
                    .findActiveLine(orgId, contract.getSupplierContactId(), line.getItemId());
            if (existing.isPresent()) {
                throw new BusinessException(
                        "Another ACTIVE rate contract already covers this supplier "
                                + "and item — expire or cancel it first",
                        "SRC_OVERLAPPING_ACTIVE", HttpStatus.CONFLICT);
            }
        }

        contract.setStatus("ACTIVE");
        if (contract.getValidFrom() == null
                || contract.getValidFrom().isAfter(LocalDate.now(clock))) {
            contract.setValidFrom(LocalDate.now(clock));
        }
        contract = contractRepository.save(contract);
        log.info("SupplierRateContract {} activated", contract.getContractNumber());

        return toResponse(contract, lines);
    }

    // ── Expire ──

    @Transactional
    public SupplierRateContractResponse expire(UUID contractId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SupplierRateContract contract = getOrThrow(contractId, orgId);

        if (!"ACTIVE".equals(contract.getStatus())) {
            throw new BusinessException(
                    "Only ACTIVE contracts can be expired", "SRC_NOT_ACTIVE",
                    HttpStatus.BAD_REQUEST);
        }
        contract.setStatus("EXPIRED");
        if (contract.getValidUntil() == null
                || contract.getValidUntil().isAfter(LocalDate.now(clock))) {
            contract.setValidUntil(LocalDate.now(clock));
        }
        contract = contractRepository.save(contract);
        log.info("SupplierRateContract {} expired", contract.getContractNumber());

        return toResponse(contract,
                lineRepository.findBySupplierRateContractIdAndIsDeletedFalseOrderByCreatedAtAsc(
                        contractId));
    }

    // ── Cancel ──

    @Transactional
    public SupplierRateContractResponse cancel(UUID contractId, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SupplierRateContract contract = getOrThrow(contractId, orgId);

        if (TERMINAL.contains(contract.getStatus())) {
            throw new BusinessException(
                    "Cannot cancel a " + contract.getStatus() + " contract",
                    "SRC_TERMINAL", HttpStatus.BAD_REQUEST);
        }
        contract.setStatus("CANCELLED");
        if (reason != null && !reason.isBlank()) {
            String existing = contract.getNotes() == null ? "" : contract.getNotes();
            contract.setNotes((existing + "\nCancelled: " + reason).trim());
        }
        contract = contractRepository.save(contract);
        log.info("SupplierRateContract {} cancelled", contract.getContractNumber());

        return toResponse(contract,
                lineRepository.findBySupplierRateContractIdAndIsDeletedFalseOrderByCreatedAtAsc(
                        contractId));
    }

    // ── Lookup for PO drafting ──

    /**
     * Find the active negotiated unit price for a given (supplier contact, item).
     * Returns empty when no ACTIVE contract covers the pair.
     */
    @Transactional(readOnly = true)
    public Optional<BigDecimal> findActiveRate(UUID supplierContactId, UUID itemId) {
        if (supplierContactId == null || itemId == null) return Optional.empty();
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) return Optional.empty();
        return lineRepository.findActiveLine(orgId, supplierContactId, itemId)
                .map(SupplierRateContractLine::getUnitPrice);
    }

    /**
     * Convenience overload — resolves a procurement Supplier id (used on PO
     * lines) to its Contact peer via display-name match, then looks up the
     * negotiated rate. Returns empty when there's no matching vendor contact
     * (the PO drafter just uses the planner-entered price).
     */
    @Transactional(readOnly = true)
    public Optional<BigDecimal> findActiveRateForSupplier(UUID supplierId, UUID itemId) {
        if (supplierId == null || itemId == null) return Optional.empty();
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) return Optional.empty();
        Supplier s = supplierRepository
                .findByIdAndOrgIdAndIsDeletedFalse(supplierId, orgId).orElse(null);
        if (s == null) return Optional.empty();
        Optional<Contact> contact = contactRepository
                .findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(orgId, s.getName());
        if (contact.isEmpty()) return Optional.empty();
        return findActiveRate(contact.get().getId(), itemId);
    }

    // ── Read ──

    @Transactional(readOnly = true)
    public SupplierRateContractResponse get(UUID contractId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SupplierRateContract contract = getOrThrow(contractId, orgId);
        return toResponse(contract,
                lineRepository.findBySupplierRateContractIdAndIsDeletedFalseOrderByCreatedAtAsc(
                        contractId));
    }

    @Transactional(readOnly = true)
    public Page<SupplierRateContractResponse> list(Pageable pageable, UUID supplierFilter) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Page<SupplierRateContract> page = supplierFilter != null
                ? contractRepository
                        .findByOrgIdAndSupplierContactIdAndIsDeletedFalseOrderByCreatedAtDesc(
                                orgId, supplierFilter, pageable)
                : contractRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(
                        orgId, pageable);
        return page.map(c -> toResponse(c,
                lineRepository.findBySupplierRateContractIdAndIsDeletedFalseOrderByCreatedAtAsc(
                        c.getId())));
    }

    @Transactional(readOnly = true)
    public List<SupplierRateContractResponse> listActive(UUID supplierContactId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return contractRepository
                .findByOrgIdAndStatusAndIsDeletedFalse(orgId, "ACTIVE").stream()
                .filter(c -> supplierContactId == null
                        || supplierContactId.equals(c.getSupplierContactId()))
                .map(c -> toResponse(c,
                        lineRepository
                                .findBySupplierRateContractIdAndIsDeletedFalseOrderByCreatedAtAsc(
                                        c.getId())))
                .toList();
    }

    // ── Daily expiry sweep (called by SupplierRateContractExpiryJob) ──

    @Transactional
    public int sweepExpiredForOrg(UUID orgId, LocalDate asOf) {
        List<SupplierRateContract> due = contractRepository.findExpiringActive(orgId, asOf);
        for (SupplierRateContract c : due) {
            c.setStatus("EXPIRED");
            contractRepository.save(c);
        }
        if (!due.isEmpty()) {
            log.info("Expired {} supplier rate contracts for org {}", due.size(), orgId);
        }
        return due.size();
    }

    // ── Helpers ──

    private SupplierRateContract getOrThrow(UUID id, UUID orgId) {
        return contractRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("SupplierRateContract", id));
    }

    private String generateContractNumber(UUID orgId) {
        long count = contractRepository.countByOrgIdAndIsDeletedFalse(orgId) + 1;
        return String.format("SRC-%d-%05d", Year.now(clock).getValue(), count);
    }

    private SupplierRateContractResponse toResponse(
            SupplierRateContract contract, List<SupplierRateContractLine> lines) {
        List<SupplierRateContractResponse.LineResponse> lineResponses = lines.stream()
                .map(l -> new SupplierRateContractResponse.LineResponse(
                        l.getId(), l.getItemId(), l.getUnitPrice(),
                        l.getMinOrderQty(), l.getNotes()))
                .toList();
        return new SupplierRateContractResponse(
                contract.getId(), contract.getOrgId(), contract.getContractNumber(),
                contract.getSupplierContactId(), contract.getStatus(),
                contract.getValidFrom(), contract.getValidUntil(),
                contract.getCurrency(), contract.getNotes(),
                lineResponses, contract.getCreatedAt());
    }
}
