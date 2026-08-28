package com.katasticho.erp.pricing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.pricing.dto.SchemeCalculationResult;
import com.katasticho.erp.pricing.dto.SchemeEvaluationRequest;
import com.katasticho.erp.pricing.dto.SchemeRequest;
import com.katasticho.erp.pricing.dto.SchemeResponse;
import com.katasticho.erp.pricing.entity.Scheme;
import com.katasticho.erp.pricing.repository.SchemeRepository;
import com.katasticho.erp.procurement.entity.Supplier;
import com.katasticho.erp.procurement.repository.SupplierRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class SchemeService {

    private final SchemeRepository schemeRepository;
    private final ItemRepository itemRepository;
    private final SupplierRepository supplierRepository;

    @Transactional
    public SchemeResponse create(SchemeRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Scheme scheme = Scheme.builder()
                .orgId(orgId)
                .name(request.name())
                .schemeType(request.schemeType())
                .itemId(request.itemId())
                .buyQuantity(request.buyQuantity())
                .freeQuantity(request.freeQuantity())
                .discountPercent(request.discountPercent())
                .minOrderQuantity(request.minOrderQuantity() != null
                        ? request.minOrderQuantity() : BigDecimal.ZERO)
                .validFrom(request.validFrom())
                .validTo(request.validTo())
                .supplierId(request.supplierId())
                .active(request.active())
                .allowHalfScheme(request.allowHalfScheme() != null ? request.allowHalfScheme() : true)
                .halfSchemeMinQty(request.halfSchemeMinQty())
                .companySubsidyPercent(request.companySubsidyPercent() != null
                        ? request.companySubsidyPercent() : new BigDecimal("100.00"))
                .specialNetRate(request.specialNetRate())
                .maxFreeQuantityCap(request.maxFreeQuantityCap())
                .build();
        return toResponse(schemeRepository.save(scheme));
    }

    @Transactional
    public SchemeResponse update(UUID id, SchemeRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Scheme scheme = schemeRepository.findByIdAndOrgIdAndDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Scheme", id));
        scheme.setName(request.name());
        scheme.setSchemeType(request.schemeType());
        scheme.setItemId(request.itemId());
        scheme.setBuyQuantity(request.buyQuantity());
        scheme.setFreeQuantity(request.freeQuantity());
        scheme.setDiscountPercent(request.discountPercent());
        scheme.setMinOrderQuantity(request.minOrderQuantity() != null
                ? request.minOrderQuantity() : BigDecimal.ZERO);
        scheme.setValidFrom(request.validFrom());
        scheme.setValidTo(request.validTo());
        scheme.setSupplierId(request.supplierId());
        scheme.setActive(request.active());
        if (request.allowHalfScheme() != null) {
            scheme.setAllowHalfScheme(request.allowHalfScheme());
        }
        scheme.setHalfSchemeMinQty(request.halfSchemeMinQty());
        if (request.companySubsidyPercent() != null) {
            scheme.setCompanySubsidyPercent(request.companySubsidyPercent());
        }
        scheme.setSpecialNetRate(request.specialNetRate());
        scheme.setMaxFreeQuantityCap(request.maxFreeQuantityCap());
        return toResponse(schemeRepository.save(scheme));
    }

    @Transactional
    public void delete(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Scheme scheme = schemeRepository.findByIdAndOrgIdAndDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Scheme", id));
        scheme.setDeleted(true);
        schemeRepository.save(scheme);
    }

    @Transactional(readOnly = true)
    public List<SchemeResponse> list() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return schemeRepository.findByOrgIdAndDeletedFalseOrderByCreatedAtDesc(orgId)
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<SchemeResponse> getApplicable(UUID itemId, BigDecimal quantity) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return schemeRepository.findApplicable(orgId, itemId, LocalDate.now())
                .stream()
                .filter(s -> s.getMinOrderQuantity() == null
                        || quantity == null
                        || quantity.compareTo(s.getMinOrderQuantity()) >= 0)
                .sorted(Comparator
                        .comparing((Scheme s) -> s.getMinOrderQuantity() == null
                                ? BigDecimal.ZERO : s.getMinOrderQuantity())
                        .reversed()
                        .thenComparing(Scheme::getCreatedAt, Comparator.reverseOrder()))
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public SchemeCalculationResult evaluateScheme(SchemeEvaluationRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        BigDecimal qty = req.quantity() != null ? req.quantity() : BigDecimal.ZERO;
        BigDecimal basePrice = req.unitPrice() != null ? req.unitPrice() : BigDecimal.ZERO;
        BigDecimal baseTotal = qty.multiply(basePrice);

        Scheme scheme = null;
        if (req.schemeId() != null) {
            scheme = schemeRepository.findByIdAndOrgIdAndDeletedFalse(req.schemeId(), orgId)
                    .filter(Scheme::isActive)
                    .orElse(null);
        } else if (req.itemId() != null) {
            List<Scheme> applicable = schemeRepository.findApplicable(orgId, req.itemId(), LocalDate.now());
            scheme = applicable.stream()
                    .filter(s -> s.getMinOrderQuantity() == null || qty.compareTo(s.getMinOrderQuantity()) >= 0)
                    .findFirst()
                    .orElse(null);
        }

        if (scheme == null || qty.compareTo(BigDecimal.ZERO) <= 0) {
            return new SchemeCalculationResult(
                    null, null, "NONE", qty,
                    BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO,
                    basePrice, basePrice, baseTotal,
                    BigDecimal.ZERO, BigDecimal.ZERO, false,
                    "No trade scheme applicable"
            );
        }

        String type = scheme.getSchemeType() != null ? scheme.getSchemeType().toUpperCase() : "PERCENT_DISCOUNT";
        BigDecimal subsidyPct = scheme.getCompanySubsidyPercent() != null
                ? scheme.getCompanySubsidyPercent() : new BigDecimal("100.00");

        // 1. SPECIAL_NET_RATE Scheme
        if ("SPECIAL_NET_RATE".equals(type) && scheme.getSpecialNetRate() != null) {
            BigDecimal netRate = scheme.getSpecialNetRate();
            BigDecimal netTotal = qty.multiply(netRate);
            BigDecimal discountAmt = baseTotal.subtract(netTotal).max(BigDecimal.ZERO);
            BigDecimal discountPct = baseTotal.compareTo(BigDecimal.ZERO) > 0
                    ? discountAmt.divide(baseTotal, 4, RoundingMode.HALF_UP).multiply(new BigDecimal("100"))
                    : BigDecimal.ZERO;
            BigDecimal companyShare = discountAmt.multiply(subsidyPct).divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
            BigDecimal distShare = discountAmt.subtract(companyShare);

            return new SchemeCalculationResult(
                    scheme.getId(), scheme.getName(), type, qty,
                    BigDecimal.ZERO, discountPct.setScale(2, RoundingMode.HALF_UP),
                    discountAmt.setScale(2, RoundingMode.HALF_UP),
                    basePrice, netRate, netTotal.setScale(2, RoundingMode.HALF_UP),
                    companyShare, distShare, false,
                    "Special Company Net Rate @ ₹" + netRate + "/unit"
            );
        }

        // 2. PERCENT_DISCOUNT Scheme
        if ("PERCENT_DISCOUNT".equals(type)) {
            BigDecimal discPct = scheme.getDiscountPercent() != null ? scheme.getDiscountPercent() : BigDecimal.ZERO;
            BigDecimal discAmt = baseTotal.multiply(discPct).divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
            BigDecimal lineTotal = baseTotal.subtract(discAmt);
            BigDecimal effPrice = qty.compareTo(BigDecimal.ZERO) > 0
                    ? lineTotal.divide(qty, 4, RoundingMode.HALF_UP) : basePrice;
            BigDecimal companyShare = discAmt.multiply(subsidyPct).divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
            BigDecimal distShare = discAmt.subtract(companyShare);

            return new SchemeCalculationResult(
                    scheme.getId(), scheme.getName(), type, qty,
                    BigDecimal.ZERO, discPct, discAmt,
                    basePrice, effPrice.setScale(2, RoundingMode.HALF_UP), lineTotal,
                    companyShare, distShare, false,
                    discPct + "% Trade Discount applied"
            );
        }

        // 3. BUY_X_GET_Y and HALF_FULL_SCHEME
        BigDecimal buyQty = scheme.getBuyQuantity() != null && scheme.getBuyQuantity().compareTo(BigDecimal.ZERO) > 0
                ? scheme.getBuyQuantity() : BigDecimal.TEN;
        BigDecimal freeQtyPerTier = scheme.getFreeQuantity() != null ? scheme.getFreeQuantity() : BigDecimal.ONE;

        // Check if quantity qualifies for full multiplier tier
        if (qty.compareTo(buyQty) >= 0) {
            BigDecimal[] divRem = qty.divideAndRemainder(buyQty);
            BigDecimal fullMultipliers = divRem[0];
            BigDecimal totalFree = fullMultipliers.multiply(freeQtyPerTier);

            if (scheme.getMaxFreeQuantityCap() != null && totalFree.compareTo(scheme.getMaxFreeQuantityCap()) > 0) {
                totalFree = scheme.getMaxFreeQuantityCap();
            }

            BigDecimal freeValue = totalFree.multiply(basePrice);
            BigDecimal totalUnits = qty.add(totalFree);
            BigDecimal effectivePrice = totalUnits.compareTo(BigDecimal.ZERO) > 0
                    ? baseTotal.divide(totalUnits, 4, RoundingMode.HALF_UP) : basePrice;

            BigDecimal companyShare = freeValue.multiply(subsidyPct).divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
            BigDecimal distShare = freeValue.subtract(companyShare);

            return new SchemeCalculationResult(
                    scheme.getId(), scheme.getName(), type, qty,
                    totalFree, BigDecimal.ZERO, BigDecimal.ZERO,
                    basePrice, effectivePrice.setScale(2, RoundingMode.HALF_UP), baseTotal,
                    companyShare, distShare, false,
                    "Full Scheme: " + fullMultipliers.intValue() + "x (" + buyQty.intValue() + "+" + freeQtyPerTier.intValue() + ") = " + totalFree.intValue() + " Free units"
            );
        }

        // Half Scheme evaluation when qty < buyQuantity
        BigDecimal minHalf = scheme.getHalfSchemeMinQty() != null
                ? scheme.getHalfSchemeMinQty()
                : buyQty.divide(BigDecimal.valueOf(2), 2, RoundingMode.HALF_UP);

        if (scheme.isAllowHalfScheme() && qty.compareTo(minHalf) >= 0) {
            // Calculate equivalent cash discount for half scheme: freeQty / (buyQty + freeQty) * 100
            BigDecimal totalSchemeUnits = buyQty.add(freeQtyPerTier);
            BigDecimal halfDiscPct = freeQtyPerTier.divide(totalSchemeUnits, 4, RoundingMode.HALF_UP)
                    .multiply(new BigDecimal("100"));
            BigDecimal discAmt = baseTotal.multiply(halfDiscPct).divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
            BigDecimal lineTotal = baseTotal.subtract(discAmt);
            BigDecimal effPrice = qty.compareTo(BigDecimal.ZERO) > 0
                    ? lineTotal.divide(qty, 4, RoundingMode.HALF_UP) : basePrice;

            BigDecimal companyShare = discAmt.multiply(subsidyPct).divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
            BigDecimal distShare = discAmt.subtract(companyShare);

            return new SchemeCalculationResult(
                    scheme.getId(), scheme.getName(), "HALF_SCHEME", qty,
                    BigDecimal.ZERO, halfDiscPct.setScale(2, RoundingMode.HALF_UP), discAmt,
                    basePrice, effPrice.setScale(2, RoundingMode.HALF_UP), lineTotal,
                    companyShare, distShare, true,
                    "Half Scheme applied @ " + halfDiscPct.setScale(2, RoundingMode.HALF_UP) + "% Cash Discount on " + qty + " units (Min " + minHalf + ")"
            );
        }

        // Below minimum threshold
        return new SchemeCalculationResult(
                scheme.getId(), scheme.getName(), type, qty,
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO,
                basePrice, basePrice, baseTotal,
                BigDecimal.ZERO, BigDecimal.ZERO, false,
                "Quantity " + qty + " below scheme slab requirement (" + buyQty + " full / " + minHalf + " half)"
        );
    }

    private SchemeResponse toResponse(Scheme s) {
        String itemName = s.getItemId() != null
                ? itemRepository.findById(s.getItemId()).map(Item::getName).orElse(null)
                : null;
        String supplierName = s.getSupplierId() != null
                ? supplierRepository.findById(s.getSupplierId()).map(Supplier::getName).orElse(null)
                : null;
        return new SchemeResponse(
                s.getId(), s.getName(), s.getSchemeType(),
                s.getItemId(), itemName,
                s.getBuyQuantity(), s.getFreeQuantity(), s.getDiscountPercent(),
                s.getMinOrderQuantity(), s.getValidFrom(), s.getValidTo(),
                s.getSupplierId(), supplierName, s.isActive(), s.getCreatedAt(),
                s.isAllowHalfScheme(), s.getHalfSchemeMinQty(), s.getCompanySubsidyPercent(),
                s.getSpecialNetRate(), s.getMaxFreeQuantityCap()
        );
    }
}
