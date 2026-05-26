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
