package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.CreateUomRequest;
import com.katasticho.erp.inventory.dto.UomResponse;
import com.katasticho.erp.inventory.entity.Uom;
import com.katasticho.erp.inventory.entity.UomCategory;
import com.katasticho.erp.inventory.entity.UomConversion;
import com.katasticho.erp.inventory.repository.UomConversionRepository;
import com.katasticho.erp.inventory.repository.UomRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import com.katasticho.erp.common.service.SeedResult;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.MathContext;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Unit of Measure master data + the quantity conversion engine.
 *
 * <p>Every v2 feature (composite items, batch selling, stock counting,
 * price lists) depends on this service to translate quantities between
 * UoMs without each feature re-implementing the lookup logic. Keep the
 * public API of {@link #convert(BigDecimal, UUID, UUID, UUID)} stable.
 *
 * <p><b>Conversion resolution order</b> (the only contract that matters):
 * <ol>
 *   <li>If {@code fromUomId == toUomId} → factor = 1 (identity).</li>
 *   <li>If a per-item override exists for {@code (orgId, itemId, from, to)}
 *       → use its factor.</li>
 *   <li>Otherwise if an org-wide rule exists for {@code (orgId, from, to)}
 *       → use its factor.</li>
 *   <li>Otherwise throw a {@link BusinessException} with code
 *       {@code UOM_NO_CONVERSION}.</li>
 * </ol>
 *
 * <p>This service deliberately does not rewrite existing
 * {@code stock_movement} quantities — those stay in each item's base UoM
 * as they always have. Conversion is a read-time boundary operation
 * performed by callers at I/O points (invoice line entry, GRN, reports).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class UomService {

    /**
     * Precision for intermediate conversion math. 34 is
     * {@link MathContext#DECIMAL128} which is more than enough for any
     * realistic pack-size chain (e.g. CARTON → BOX → STRIP → PCS).
     */
    private static final MathContext CTX = MathContext.DECIMAL128;

    private final UomRepository uomRepository;
    private final UomConversionRepository uomConversionRepository;

    // ── CRUD ──────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<UomResponse> listForCurrentOrg() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return uomRepository
                .findByOrgIdAndIsDeletedFalseOrderByCategoryAscAbbreviationAsc(orgId)
                .stream()
                .map(UomResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<UomResponse> listByCategory(UomCategory category) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return uomRepository
                .findByOrgIdAndCategoryAndIsDeletedFalseOrderByAbbreviationAsc(orgId, category)
                .stream()
                .map(UomResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public UomResponse get(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return UomResponse.from(findForOrg(id, orgId));
    }

    @Transactional
    public UomResponse create(CreateUomRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String abbr = request.abbreviation().trim();
        if (uomRepository.existsByOrgIdAndAbbreviationIgnoreCaseAndIsDeletedFalse(orgId, abbr)) {
            throw BusinessException.conflict(
                    "UoM abbreviation already exists: " + abbr,
                    "UOM_ABBR_DUPLICATE");
        }
        Uom u = Uom.builder()
                .name(request.name().trim())
                .abbreviation(abbr)
                .category(request.category())
                .base(Boolean.TRUE.equals(request.base()))
                .active(request.active() == null || request.active())
                .build();
        return UomResponse.from(uomRepository.save(u));
    }

    @Transactional
    public UomResponse update(UUID id, CreateUomRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Uom u = findForOrg(id, orgId);
        String abbr = request.abbreviation().trim();

        // Only re-check uniqueness if the abbreviation actually changed
        if (!u.getAbbreviation().equalsIgnoreCase(abbr)
                && uomRepository.existsByOrgIdAndAbbreviationIgnoreCaseAndIsDeletedFalse(orgId, abbr)) {
            throw BusinessException.conflict(
                    "UoM abbreviation already exists: " + abbr,
                    "UOM_ABBR_DUPLICATE");
        }
        u.setName(request.name().trim());
        u.setAbbreviation(abbr);
        u.setCategory(request.category());
        if (request.base() != null) u.setBase(request.base());
        if (request.active() != null) u.setActive(request.active());
        return UomResponse.from(uomRepository.save(u));
    }

    @Transactional
    public void softDelete(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Uom u = findForOrg(id, orgId);
        u.setDeleted(true);
        uomRepository.save(u);
    }

    // ── Conversion engine ─────────────────────────────────────────

    /**
     * Convert a quantity from one UoM to another, optionally scoped to a
     * specific item (for pack-size overrides).
     *
     * @param quantity   the quantity expressed in {@code fromUomId}
     * @param fromUomId  the source UoM
     * @param toUomId    the target UoM
     * @param itemId     optional item whose per-item conversion should be
     *                   checked before falling back to the org-wide rule
     *                   (may be {@code null} for item-agnostic conversions)
     * @return the equivalent quantity in {@code toUomId}, rounded to the
     *         caller's own scale if needed
     * @throws BusinessException if no conversion rule exists at any level
     */
    @Transactional(readOnly = true)
    public BigDecimal convert(BigDecimal quantity, UUID fromUomId, UUID toUomId, UUID itemId) {
        if (quantity == null) {
            throw new BusinessException("Quantity is required for conversion",
                    "UOM_QTY_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        if (fromUomId == null || toUomId == null) {
            throw new BusinessException("UoM ids are required for conversion",
                    "UOM_REQUIRED", HttpStatus.BAD_REQUEST);
        }

        // 1. Identity — same UoM.
        if (fromUomId.equals(toUomId)) {
            return quantity;
        }

        UUID orgId = TenantContext.getCurrentOrgId();
        BigDecimal factor = resolveFactor(orgId, itemId, fromUomId, toUomId);
        return quantity.multiply(factor, CTX);
    }

    /**
     * Look up the raw conversion factor without applying it to a quantity.
     * Useful for UI previews and cost-per-unit calculations.
     */
    @Transactional(readOnly = true)
    public BigDecimal factor(UUID fromUomId, UUID toUomId, UUID itemId) {
        if (fromUomId.equals(toUomId)) return BigDecimal.ONE;
        UUID orgId = TenantContext.getCurrentOrgId();
        return resolveFactor(orgId, itemId, fromUomId, toUomId);
    }

    private BigDecimal resolveFactor(UUID orgId, UUID itemId, UUID fromUomId, UUID toUomId) {
        // 2. Per-item override takes precedence.
        if (itemId != null) {
            Optional<UomConversion> perItem =
                    uomConversionRepository.findPerItem(orgId, itemId, fromUomId, toUomId);
            if (perItem.isPresent()) {
                return perItem.get().getFactor();
            }
        }

        // 3. Org-wide rule.
        Optional<UomConversion> orgWide =
                uomConversionRepository.findOrgWide(orgId, fromUomId, toUomId);
        if (orgWide.isPresent()) {
            return orgWide.get().getFactor();
        }

        // 4. No rule. Fail loudly — silent fallbacks here would corrupt
        // the ledger downstream (someone would sell 1 KG thinking it was
        // 1 GM).
        throw new BusinessException(
                "No UoM conversion defined from " + fromUomId + " to " + toUomId
                        + (itemId != null ? " for item " + itemId : ""),
                "UOM_NO_CONVERSION",
                HttpStatus.BAD_REQUEST);
    }

    // ── Lookup helpers used by other services (ItemService, importers) ──

    /**
     * Resolve a UoM by abbreviation within the current tenant. Used by
     * importers and item create/update to turn the legacy
     * {@code unit_of_measure} string column into a {@code base_uom_id}
     * FK without the caller having to know about the repository layer.
     *
     * @return the matching UoM, or empty if no such abbreviation exists
     */
    @Transactional(readOnly = true)
    public Optional<Uom> findByAbbreviation(String abbreviation) {
        if (abbreviation == null || abbreviation.isBlank()) return Optional.empty();
        UUID orgId = TenantContext.getCurrentOrgId();
        return uomRepository.findByOrgIdAndAbbreviationIgnoreCaseAndIsDeletedFalse(
                orgId, abbreviation.trim());
    }

    /**
     * Resolve a UoM id by abbreviation, falling back to PCS when the
     * abbreviation is unknown. Used as the single source of truth when
     * populating {@code item.base_uom_id} on create/update so we never
     * silently lose a UoM reference.
     */
    @Transactional
    public UUID resolveBaseUomIdOrPcs(String abbreviation) {
        UUID orgId = TenantContext.getCurrentOrgId();

        if (abbreviation != null && !abbreviation.isBlank()) {
            Optional<Uom> exact = uomRepository
                    .findByOrgIdAndAbbreviationIgnoreCaseAndIsDeletedFalse(orgId, abbreviation.trim());
            if (exact.isPresent()) return exact.get().getId();
        }

        Optional<Uom> pcs = uomRepository
                .findByOrgIdAndAbbreviationIgnoreCaseAndIsDeletedFalse(orgId, "PCS");
        if (pcs.isPresent()) return pcs.get().getId();

        // Self-heal: seed defaults if bootstrap missed this org
        log.warn("PCS UoM missing for org {} — seeding defaults now", orgId);
        seedDefaultsForOrg(orgId, (String) null);

        return uomRepository
                .findByOrgIdAndAbbreviationIgnoreCaseAndIsDeletedFalse(orgId, "PCS")
                .map(Uom::getId)
                .orElseThrow(() -> new BusinessException(
                        "UoM seed failed for org — PCS still missing after auto-seed",
                        "UOM_PCS_MISSING",
                        HttpStatus.INTERNAL_SERVER_ERROR));
    }

    // ── Private helpers ──────────────────────────────────────────

    /**
     * Seed standard UoMs for a newly created organisation.
     * Called from signup flow so items can be created immediately.
     */
    @Transactional
    public SeedResult seedDefaultsForOrg(UUID orgId, String industryCode) {
        if (uomRepository.existsByOrgIdAndAbbreviationIgnoreCaseAndIsDeletedFalse(orgId, "PCS")) {
            return SeedResult.ALREADY_EXISTS;
        }
        seedCommonUoms(orgId);
        seedIndustryUoms(orgId, industryCode);
        log.info("Seeded UoMs for org {} (industry={})", orgId, industryCode);
        return SeedResult.CREATED_NEW;
    }

    @Transactional
    public SeedResult seedDefaultsForOrg(UUID orgId, List<String> subCategories) {
        if (uomRepository.existsByOrgIdAndAbbreviationIgnoreCaseAndIsDeletedFalse(orgId, "PCS")) {
            return SeedResult.ALREADY_EXISTS;
        }
        seedCommonUoms(orgId);
        if (subCategories == null || subCategories.isEmpty()) {
            seedIndustryUoms(orgId, null);
        } else {
            for (String code : subCategories) {
                seedIndustryUoms(orgId, code);
            }
        }
        log.info("Seeded UoMs for org {} (subCategories={})", orgId, subCategories);
        return SeedResult.CREATED_NEW;
    }

    private void seedCommonUoms(UUID orgId) {
        seedUom(orgId, "Pieces",      "PCS",    UomCategory.COUNT,     true);
        seedUom(orgId, "Dozen",       "DOZEN",  UomCategory.COUNT,     false);
        seedUom(orgId, "Box",         "BOX",    UomCategory.PACKAGING, true);
        seedUom(orgId, "Kilogram",    "KG",     UomCategory.WEIGHT,    true);
        seedUom(orgId, "Gram",        "GM",     UomCategory.WEIGHT,    false);
        seedUom(orgId, "Litre",       "LTR",    UomCategory.VOLUME,    true);
        seedUom(orgId, "Millilitre",  "ML",     UomCategory.VOLUME,    false);
        seedUom(orgId, "Set",         "SET",    UomCategory.COUNT,     false);
    }

    private void seedIndustryUoms(UUID orgId, String industryCode) {
        if (industryCode == null) {
            seedUom(orgId, "Pack",     "PACK",   UomCategory.PACKAGING, false);
            seedUom(orgId, "Metre",    "MTR",    UomCategory.LENGTH,    true);
            return;
        }
        switch (industryCode) {
            case "PHARMACY", "AYURVEDIC", "PHARMA_MANUFACTURER" -> {
                seedUom(orgId, "Strip",       "STRIP",  UomCategory.PACKAGING, false);
                seedUom(orgId, "Bottle",      "BOTTLE", UomCategory.PACKAGING, false);
                seedUom(orgId, "Tube",        "TUBE",   UomCategory.PACKAGING, false);
                seedUom(orgId, "Vial",        "VIAL",   UomCategory.PACKAGING, false);
                seedUom(orgId, "Sachet",      "SACHET", UomCategory.PACKAGING, false);
                seedUom(orgId, "Tablet",      "TAB",    UomCategory.COUNT,     false);
                seedUom(orgId, "Milligram",   "MG",     UomCategory.WEIGHT,    false);
            }
            case "GROCERY", "SUPERMARKET", "FRUITS_VEG", "ORGANIC", "KIRANA" -> {
                seedUom(orgId, "Pack",        "PACK",   UomCategory.PACKAGING, false);
                seedUom(orgId, "Packet",      "PKT",    UomCategory.PACKAGING, false);
                seedUom(orgId, "Bag",         "BAG",    UomCategory.PACKAGING, false);
                seedUom(orgId, "Bora",        "BORA",   UomCategory.PACKAGING, false);
                seedUom(orgId, "Katta",       "KATTA",  UomCategory.PACKAGING, false);
                seedUom(orgId, "Carton",      "CTN",    UomCategory.PACKAGING, false);
                seedUom(orgId, "Tin",         "TIN",    UomCategory.PACKAGING, false);
                seedUom(orgId, "Tray",        "TRAY",   UomCategory.PACKAGING, false);
                seedUom(orgId, "Peti",        "PETI",   UomCategory.PACKAGING, false);
                seedUom(orgId, "Bundle",      "BUNDLE", UomCategory.PACKAGING, false);
                seedUom(orgId, "Bottle",      "BOTTLE", UomCategory.PACKAGING, false);
                seedUom(orgId, "Pair",        "PAIR",   UomCategory.COUNT,     false);
            }
            case "ELECTRONICS", "MOBILE", "APPLIANCES", "LED", "CCTV", "ELECTRONICS_MANUFACTURER" -> {
                seedUom(orgId, "Pair",        "PAIR",   UomCategory.COUNT,     false);
            }
            case "HARDWARE", "PLUMBING", "ELECTRICAL", "PAINT", "BUILDING" -> {
                seedUom(orgId, "Metre",       "MTR",    UomCategory.LENGTH,    true);
                seedUom(orgId, "Feet",        "FT",     UomCategory.LENGTH,    false);
                seedUom(orgId, "Square Feet", "SQFT",   UomCategory.LENGTH,    false);
                seedUom(orgId, "Cubic Feet",  "CUFT",   UomCategory.LENGTH,    false);
                seedUom(orgId, "Bag",         "BAG",    UomCategory.PACKAGING, false);
            }
            case "GARMENTS", "FABRIC", "FOOTWEAR", "JEWELRY", "COSMETICS", "GARMENT_MANUFACTURER" -> {
                seedUom(orgId, "Pair",        "PAIR",   UomCategory.COUNT,     false);
                seedUom(orgId, "Metre",       "MTR",    UomCategory.LENGTH,    true);
            }
            case "FOOD", "BAKERY", "CATERING", "CLOUD_KITCHEN", "JUICE", "FOOD_MANUFACTURER" -> {
                seedUom(orgId, "Plate",       "PLATE",  UomCategory.COUNT,     false);
                seedUom(orgId, "Glass",       "GLASS",  UomCategory.COUNT,     false);
            }
            default -> {
                seedUom(orgId, "Pack",        "PACK",   UomCategory.PACKAGING, false);
                seedUom(orgId, "Metre",       "MTR",    UomCategory.LENGTH,    true);
            }
        }
    }

    private void seedUom(UUID orgId, String name, String abbr, UomCategory cat, boolean isBase) {
        Uom uom = Uom.builder()
                .name(name)
                .abbreviation(abbr)
                .category(cat)
                .base(isBase)
                .build();
        uom.setOrgId(orgId);
        uomRepository.save(uom);
    }

    private Uom findForOrg(UUID id, UUID orgId) {
        return uomRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Uom", id));
    }
}
