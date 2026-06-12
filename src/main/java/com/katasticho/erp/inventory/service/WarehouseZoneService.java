package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.WarehouseZone;
import com.katasticho.erp.inventory.repository.WarehouseZoneRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class WarehouseZoneService {

    private final WarehouseZoneRepository zoneRepo;

    @Transactional
    public WarehouseZone createZone(UUID warehouseId, String code, String name,
                                    String zoneType, BigDecimal capacity,
                                    boolean temperatureControlled, String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();

        if (zoneRepo.existsByOrgIdAndWarehouseIdAndCodeAndIsDeletedFalse(orgId, warehouseId, code)) {
            throw new BusinessException(
                    "Zone with code '" + code + "' already exists in this warehouse",
                    "ZONE_DUPLICATE_CODE", HttpStatus.CONFLICT);
        }

        WarehouseZone zone = WarehouseZone.builder()
                .warehouseId(warehouseId)
                .code(code)
                .name(name)
                .zoneType(zoneType != null ? zoneType : "STORAGE")
                .capacity(capacity)
                .temperatureControlled(temperatureControlled)
                .notes(notes)
                .build();
        zone = zoneRepo.save(zone);

        log.info("Created warehouse zone {} ({}) in warehouse {} for org {}", code, zoneType, warehouseId, orgId);
        return zone;
    }

    @Transactional(readOnly = true)
    public WarehouseZone getZone(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return zoneRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("WarehouseZone", id));
    }

    @Transactional(readOnly = true)
    public List<WarehouseZone> getZonesByWarehouse(UUID warehouseId) {
        return zoneRepo.findByOrgIdAndWarehouseIdAndIsDeletedFalseOrderByCodeAsc(
                TenantContext.getCurrentOrgId(), warehouseId);
    }

    @Transactional(readOnly = true)
    public List<WarehouseZone> getZonesByType(String zoneType) {
        return zoneRepo.findByOrgIdAndZoneTypeAndIsDeletedFalseOrderByCodeAsc(
                TenantContext.getCurrentOrgId(), zoneType);
    }

    @Transactional
    public WarehouseZone updateZone(UUID id, String name, String zoneType,
                                    BigDecimal capacity, boolean temperatureControlled,
                                    String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();
        WarehouseZone zone = zoneRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("WarehouseZone", id));

        if (name != null) zone.setName(name);
        if (zoneType != null) zone.setZoneType(zoneType);
        if (capacity != null) zone.setCapacity(capacity);
        zone.setTemperatureControlled(temperatureControlled);
        if (notes != null) zone.setNotes(notes);

        return zoneRepo.save(zone);
    }

    @Transactional
    public void deleteZone(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        WarehouseZone zone = zoneRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("WarehouseZone", id));
        zone.setDeleted(true);
        zoneRepo.save(zone);
    }
}
