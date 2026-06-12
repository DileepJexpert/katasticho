package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.*;
import com.katasticho.erp.inventory.entity.*;
import com.katasticho.erp.inventory.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PharmacyMasterService {

    private final ManufacturerMasterRepository manufacturerRepository;
    private final HsnGstMasterRepository hsnRepository;
    private final RackLocationRepository rackRepository;
    private final GenericSubstitutionRepository substitutionRepository;
    private final DrugInteractionRepository interactionRepository;
    private final DrugMasterRepository drugMasterRepository;
    private final SaltMasterRepository saltMasterRepository;
    private final WarehouseRepository warehouseRepository;

    public List<ManufacturerMasterResponse> searchManufacturers(String query, int limit) {
        return manufacturerRepository
                .findByNameContainingIgnoreCaseAndActiveTrueOrderByNameAsc(
                        query == null ? "" : query.trim(), PageRequest.of(0, Math.min(limit, 100)))
                .stream()
                .map(this::toManufacturer)
                .toList();
    }

    public List<HsnGstMasterResponse> searchHsn(String query, int limit) {
        String q = query == null ? "" : query.trim();
        return hsnRepository
                .search(q, PageRequest.of(0, Math.min(limit, 100)))
                .stream()
                .map(this::toHsn)
                .toList();
    }

    /**
     * Adds an HSN code to the platform master. hsn_gst_master is shared
     * across all orgs (rates are statutory facts, not org preferences):
     * any OWNER/ADMIN may ADD a missing code so they can self-serve, but
     * changing an EXISTING row is restricted to PLATFORM_ADMIN so one org
     * can't silently change rates for everyone.
     */
    @org.springframework.transaction.annotation.Transactional
    public HsnGstMasterResponse upsertHsn(String hsnCode, String description,
                                          String category, java.math.BigDecimal gstRate) {
        if (hsnCode == null || hsnCode.isBlank()) {
            throw new BusinessException("HSN code is required", "HSN_CODE_REQUIRED",
                    org.springframework.http.HttpStatus.BAD_REQUEST);
        }
        if (gstRate == null || gstRate.signum() < 0 || gstRate.compareTo(new java.math.BigDecimal("100")) > 0) {
            throw new BusinessException("GST rate must be between 0 and 100", "HSN_RATE_INVALID",
                    org.springframework.http.HttpStatus.BAD_REQUEST);
        }
        String code = hsnCode.trim();

        HsnGstMaster row = hsnRepository.findByHsnCodeAndActiveTrue(code).orElse(null);
        if (row != null) {
            String role = com.katasticho.erp.common.context.TenantContext.getCurrentRole();
            if (!"PLATFORM_ADMIN".equals(role)) {
                throw new BusinessException(
                        "HSN " + code + " already exists in the shared master; only a platform admin can change it",
                        "HSN_PLATFORM_ROW_READONLY", org.springframework.http.HttpStatus.FORBIDDEN);
            }
        } else {
            row = new HsnGstMaster();
            row.setHsnCode(code);
        }
        row.setDescription(description != null && !description.isBlank() ? description.trim() : code);
        row.setCategory(category);
        row.setGstRate(gstRate);
        row.setActive(true);
        return toHsn(hsnRepository.save(row));
    }

    public HsnGstMasterResponse getHsn(String code) {
        return hsnRepository.findByHsnCodeAndActiveTrue(code)
                .map(this::toHsn)
                .orElseThrow(() -> BusinessException.notFound("HSN", code));
    }

    public List<RackLocationResponse> rackLocations(UUID warehouseId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<RackLocation> racks = warehouseId == null
                ? rackRepository.findByOrgIdAndIsDeletedFalseOrderByCodeAsc(orgId)
                : rackRepository.findByOrgIdAndWarehouseIdAndIsDeletedFalseOrderByCodeAsc(orgId, warehouseId);
        return racks
                .stream()
                .map(this::toRack)
                .toList();
    }

    @Transactional
    public RackLocationResponse createRackLocation(RackLocationRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(request.warehouseId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Warehouse", request.warehouseId()));
        rackRepository.findByOrgIdAndWarehouseIdAndCodeIgnoreCaseAndIsDeletedFalse(
                orgId, request.warehouseId(), request.code().trim())
                .ifPresent(existing -> {
                    throw new BusinessException("Rack code already exists in this warehouse",
                            "RACK_CODE_EXISTS", HttpStatus.CONFLICT);
                });

        RackLocation rack = new RackLocation();
        rack.setWarehouseId(request.warehouseId());
        rack.setCode(request.code().trim().toUpperCase());
        rack.setName(blankToNull(request.name()));
        rack.setZone(blankToNull(request.zone()));
        rack.setAisle(blankToNull(request.aisle()));
        rack.setShelf(blankToNull(request.shelf()));
        rack.setBin(blankToNull(request.bin()));
        return toRack(rackRepository.save(rack));
    }

    @Transactional
    public List<RackLocationResponse> seedDemoRackLocations() {
        UUID orgId = TenantContext.getCurrentOrgId();
        Warehouse warehouse = warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .orElseThrow(() -> new BusinessException(
                        "No default warehouse configured for demo rack layout",
                        "RACK_DEMO_NO_DEFAULT_WAREHOUSE", HttpStatus.BAD_REQUEST));

        List<RackLocationRequest> demoRacks = List.of(
                new RackLocationRequest(warehouse.getId(), "A1-01", "Fast-moving tablets", "Tablets", "A1", "1", "1"),
                new RackLocationRequest(warehouse.getId(), "A1-02", "Secondary tablets", "Tablets", "A1", "2", "1"),
                new RackLocationRequest(warehouse.getId(), "B1-01", "Capsules", "Capsules", "B1", "1", "1"),
                new RackLocationRequest(warehouse.getId(), "B2-01", "Syrups and bottles", "Liquids", "B2", "1", "1"),
                new RackLocationRequest(warehouse.getId(), "C1-01", "Injections", "Injectables", "C1", "1", "1"),
                new RackLocationRequest(warehouse.getId(), "D1-01", "Surgical and devices", "Surgical", "D1", "1", "1"),
                new RackLocationRequest(warehouse.getId(), "FRZ-01", "Cold chain fridge", "ColdChain", "FRZ", "1", "1"),
                new RackLocationRequest(warehouse.getId(), "OTC-01", "Front counter OTC", "OTC", "OTC", "1", "1")
        );

        List<RackLocationResponse> createdOrExisting = new ArrayList<>();
        for (RackLocationRequest request : demoRacks) {
            RackLocation rack = rackRepository.findByOrgIdAndWarehouseIdAndCodeIgnoreCaseAndIsDeletedFalse(
                            orgId, request.warehouseId(), request.code().trim())
                    .orElseGet(() -> {
                        RackLocation newRack = new RackLocation();
                        newRack.setWarehouseId(request.warehouseId());
                        newRack.setCode(request.code().trim().toUpperCase());
                        newRack.setName(blankToNull(request.name()));
                        newRack.setZone(blankToNull(request.zone()));
                        newRack.setAisle(blankToNull(request.aisle()));
                        newRack.setShelf(blankToNull(request.shelf()));
                        newRack.setBin(blankToNull(request.bin()));
                        return rackRepository.save(newRack);
                    });
            createdOrExisting.add(toRack(rack));
        }

        return createdOrExisting.stream()
                .sorted(Comparator.comparing(RackLocationResponse::code))
                .toList();
    }

    public List<GenericSubstitutionResponse> substitutions(UUID drugMasterId) {
        List<GenericSubstitution> rows =
                substitutionRepository.findByDrugMasterIdAndActiveTrueOrderByEstimatedSavingsDesc(drugMasterId);
        Set<UUID> substituteIds = rows.stream()
                .map(GenericSubstitution::getSubstituteDrugMasterId)
                .collect(Collectors.toSet());
        Map<UUID, DrugMaster> drugMap = drugMasterRepository.findAllById(substituteIds)
                .stream()
                .collect(Collectors.toMap(DrugMaster::getId, Function.identity()));
        return rows.stream()
                .map(row -> toSubstitution(row, drugMap.get(row.getSubstituteDrugMasterId())))
                .toList();
    }

    public List<DrugInteractionResponse> checkInteractions(List<UUID> saltIds) {
        if (saltIds == null || saltIds.size() < 2) return List.of();
        return interactionRepository.findActiveWithinSaltSet(new HashSet<>(saltIds))
                .stream()
                .map(this::toInteraction)
                .toList();
    }

    public List<DrugInteractionResponse> checkInteractionsByCompositions(List<String> compositions) {
        if (compositions == null || compositions.size() < 2) return List.of();
        Set<String> saltNames = compositions.stream()
                .filter(c -> c != null && !c.isBlank())
                .flatMap(c -> Arrays.stream(c.split("[+,]")))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .collect(Collectors.toSet());
        if (saltNames.size() < 2) return List.of();
        List<SaltMaster> salts = saltMasterRepository.findByNameIgnoreCaseIn(saltNames);
        if (salts.size() < 2) return List.of();
        Set<UUID> saltIds = salts.stream().map(SaltMaster::getId).collect(Collectors.toSet());
        return checkInteractions(new ArrayList<>(saltIds));
    }

    private ManufacturerMasterResponse toManufacturer(ManufacturerMaster m) {
        return new ManufacturerMasterResponse(m.getId(), m.getName(), m.getCountry(), m.getWebsite());
    }

    private HsnGstMasterResponse toHsn(HsnGstMaster h) {
        return new HsnGstMasterResponse(h.getId(), h.getHsnCode(), h.getDescription(), h.getCategory(), h.getGstRate());
    }

    private RackLocationResponse toRack(RackLocation r) {
        return new RackLocationResponse(r.getId(), r.getWarehouseId(), r.getCode(), r.getName(),
                r.getZone(), r.getAisle(), r.getShelf(), r.getBin(), r.isActive());
    }

    private GenericSubstitutionResponse toSubstitution(GenericSubstitution s, DrugMaster substitute) {
        return new GenericSubstitutionResponse(
                s.getId(),
                s.getDrugMasterId(),
                s.getSubstituteDrugMasterId(),
                substitute != null ? substitute.getBrandName() : null,
                substitute != null ? substitute.getSaltComposition() : null,
                substitute != null ? substitute.getManufacturer() : null,
                substitute != null ? substitute.getMrp() : null,
                s.getEstimatedSavings(),
                s.getReason());
    }

    private DrugInteractionResponse toInteraction(DrugInteraction i) {
        return new DrugInteractionResponse(i.getId(), i.getPrimarySaltId(), i.getInteractingSaltId(),
                i.getSeverity(), i.getWarning(), i.getRecommendation());
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
