package com.katasticho.erp.transport.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.transport.dto.TransportDtos.*;
import com.katasticho.erp.transport.entity.FreightRateCard;
import com.katasticho.erp.transport.repository.FreightRateCardRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Freight rate cards — per-transporter lane + weight-slab rates. The headline
 * method is {@link #resolveRate}, which an LR uses to auto-fill freight: it picks
 * the active card matching the transporter, mode, lane (origin/destination,
 * case-insensitive) and weight slab, then computes the amount (per-kg × weight
 * with a min-charge floor, flat, or per-unit).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FreightRateCardService {

    private final FreightRateCardRepository repository;

    @Transactional
    public FreightRateCardResponse create(FreightRateCardRequest req) {
        UUID orgId = requireOrgId();
        validate(req);
        FreightRateCard card = FreightRateCard.builder()
                .transporterContactId(req.transporterContactId())
                .origin(req.origin())
                .destination(req.destination())
                .mode(orDefault(req.mode(), "ROAD").toUpperCase())
                .weightSlabMinKg(nz(req.weightSlabMinKg()))
                .weightSlabMaxKg(req.weightSlabMaxKg())
                .rateType(orDefault(req.rateType(), "PER_KG").toUpperCase())
                .rate(req.rate())
                .minCharge(nz(req.minCharge()))
                .effectiveFrom(req.effectiveFrom())
                .effectiveTo(req.effectiveTo())
                .notes(req.notes())
                .build();
        card.setOrgId(orgId);
        card = repository.save(card);
        return toResponse(card);
    }

    @Transactional
    public void delete(UUID id) {
        FreightRateCard card = require(id);
        card.setDeleted(true);
        repository.save(card);
    }

    @Transactional(readOnly = true)
    public List<FreightRateCardResponse> list(UUID transporterContactId) {
        UUID orgId = requireOrgId();
        List<FreightRateCard> rows = transporterContactId == null
                ? repository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId)
                : repository.findByOrgIdAndTransporterContactIdAndIsDeletedFalseOrderByCreatedAtDesc(
                        orgId, transporterContactId);
        return rows.stream().map(this::toResponse).toList();
    }

    /**
     * Best matching rate for a lane + weight, with the computed freight amount.
     * Tie-break: narrowest matching weight slab wins (a slab with a defined max
     * before an open-ended one), then most recent.
     */
    @Transactional(readOnly = true)
    public RateQuoteResponse resolveRate(UUID transporterContactId, String origin,
                                         String destination, String mode, BigDecimal weightKg) {
        UUID orgId = requireOrgId();
        String m = orDefault(mode, "ROAD").toUpperCase();
        BigDecimal weight = nz(weightKg);
        LocalDate today = LocalDate.now();

        Optional<FreightRateCard> match = repository
                .findByOrgIdAndTransporterContactIdAndModeAndActiveTrueAndIsDeletedFalse(
                        orgId, transporterContactId, m)
                .stream()
                .filter(c -> laneMatches(c, origin, destination))
                .filter(c -> slabMatches(c, weight))
                .filter(c -> effective(c, today))
                .min(Comparator
                        .comparing((FreightRateCard c) -> c.getWeightSlabMaxKg() == null) // defined slab first
                        .thenComparing(FreightRateCard::getCreatedAt, Comparator.reverseOrder()));

        if (match.isEmpty()) {
            return new RateQuoteResponse(false, null, BigDecimal.ZERO, null,
                    "No matching rate card — enter the freight manually.");
        }
        FreightRateCard c = match.get();
        BigDecimal amount = compute(c, weight);
        return new RateQuoteResponse(true, c.getId(), amount,
                describe(c, weight, amount),
                "Freight from rate card " + c.getOrigin() + "→" + c.getDestination());
    }

    // ── Matching + computation ───────────────────────────────────────────

    private boolean laneMatches(FreightRateCard c, String origin, String destination) {
        return eqIgnoreCaseOrBlank(c.getOrigin(), origin)
                && eqIgnoreCaseOrBlank(c.getDestination(), destination);
    }

    private boolean slabMatches(FreightRateCard c, BigDecimal weight) {
        boolean aboveMin = weight.compareTo(nz(c.getWeightSlabMinKg())) >= 0;
        boolean belowMax = c.getWeightSlabMaxKg() == null
                || weight.compareTo(c.getWeightSlabMaxKg()) <= 0;
        return aboveMin && belowMax;
    }

    private boolean effective(FreightRateCard c, LocalDate today) {
        boolean fromOk = c.getEffectiveFrom() == null || !today.isBefore(c.getEffectiveFrom());
        boolean toOk = c.getEffectiveTo() == null || !today.isAfter(c.getEffectiveTo());
        return fromOk && toOk;
    }

    private BigDecimal compute(FreightRateCard c, BigDecimal weight) {
        BigDecimal amount = switch (c.getRateType()) {
            case "FLAT" -> c.getRate();
            case "PER_UNIT" -> c.getRate(); // caller multiplies by units if needed; flat per LR here
            default -> c.getRate().multiply(weight); // PER_KG
        };
        if (!"FLAT".equals(c.getRateType()) && amount.compareTo(nz(c.getMinCharge())) < 0) {
            amount = c.getMinCharge();
        }
        return amount.max(BigDecimal.ZERO);
    }

    private String describe(FreightRateCard c, BigDecimal weight, BigDecimal amount) {
        return switch (c.getRateType()) {
            case "FLAT" -> "flat ₹" + plain(c.getRate());
            case "PER_UNIT" -> "₹" + plain(c.getRate()) + "/unit";
            default -> "₹" + plain(c.getRate()) + "/kg × " + plain(weight) + "kg = ₹" + plain(amount)
                    + (c.getMinCharge().signum() > 0 ? " (min ₹" + plain(c.getMinCharge()) + ")" : "");
        };
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private void validate(FreightRateCardRequest req) {
        if (req.rate() == null || req.rate().signum() < 0) {
            throw new BusinessException("Rate must be non-negative", "FREIGHT_BAD_RATE", HttpStatus.BAD_REQUEST);
        }
        if (req.weightSlabMaxKg() != null && req.weightSlabMinKg() != null
                && req.weightSlabMaxKg().compareTo(req.weightSlabMinKg()) < 0) {
            throw new BusinessException("Weight slab max < min", "FREIGHT_BAD_SLAB", HttpStatus.BAD_REQUEST);
        }
    }

    private FreightRateCard require(UUID id) {
        return repository.findByIdAndOrgIdAndIsDeletedFalse(id, requireOrgId())
                .orElseThrow(() -> new BusinessException(
                        "Rate card not found", "FREIGHT_RATE_NOT_FOUND", HttpStatus.NOT_FOUND));
    }

    private FreightRateCardResponse toResponse(FreightRateCard c) {
        return new FreightRateCardResponse(c.getId(), c.getTransporterContactId(), c.getOrigin(),
                c.getDestination(), c.getMode(), c.getWeightSlabMinKg(), c.getWeightSlabMaxKg(),
                c.getRateType(), c.getRate(), c.getMinCharge(), c.getEffectiveFrom(),
                c.getEffectiveTo(), c.isActive(), c.getNotes());
    }

    private static boolean eqIgnoreCaseOrBlank(String cardValue, String query) {
        if (cardValue == null || cardValue.isBlank()) return true; // a blank lane matches anything
        if (query == null || query.isBlank()) return false;
        return cardValue.trim().equalsIgnoreCase(query.trim());
    }

    private static String orDefault(String v, String def) {
        return v == null || v.isBlank() ? def : v;
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    private static String plain(BigDecimal v) {
        return (v == null ? BigDecimal.ZERO : v).stripTrailingZeros().toPlainString();
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
