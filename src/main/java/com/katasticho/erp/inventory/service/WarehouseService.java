package com.katasticho.erp.inventory.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.CreateWarehouseRequest;
import com.katasticho.erp.inventory.dto.WarehouseResponse;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.organisation.Branch;
import com.katasticho.erp.organisation.BranchRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class WarehouseService {

    private final WarehouseRepository warehouseRepository;
    private final BranchRepository branchRepository;
    private final AuditService auditService;
    private final com.katasticho.erp.inventory.repository.StockBalanceRepository stockBalanceRepository;

    @Transactional
    public WarehouseResponse createWarehouse(CreateWarehouseRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        String code = request.code().trim();
        if (warehouseRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, code)) {
            throw new BusinessException("Warehouse with code " + code + " already exists",
                    "INV_DUPLICATE_WAREHOUSE_CODE", HttpStatus.CONFLICT);
        }

        boolean makeDefault = Boolean.TRUE.equals(request.isDefault());
        if (makeDefault) {
            // Demote any existing default — only one default per org.
            warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                    .ifPresent(existing -> {
                        existing.setDefault(false);
                        warehouseRepository.save(existing);
                    });
        } else {
            // First warehouse for this org becomes default automatically.
            if (warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId).isEmpty()) {
                makeDefault = true;
            }
        }

        // Stamp the org's default branch on new warehouses so branch
        // rollups stay accurate. Callers don't pick branch yet.
        UUID branchId = branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .map(Branch::getId).orElse(null);

        Warehouse warehouse = Warehouse.builder()
                .branchId(branchId)
                .code(code)
                .name(request.name().trim())
                .addressLine1(request.addressLine1())
                .addressLine2(request.addressLine2())
                .city(request.city())
                .state(request.state())
                .stateCode(request.stateCode())
                .postalCode(request.postalCode())
                .country(request.country() != null ? request.country() : "IN")
                .isDefault(makeDefault)
                .active(true)
                .build();

        warehouse = warehouseRepository.save(warehouse);
        auditService.log("WAREHOUSE", warehouse.getId(), "CREATE", null,
                "{\"code\":\"" + warehouse.getCode() + "\"}");
        return toResponse(warehouse);
    }

    @Transactional
    public WarehouseResponse updateWarehouse(UUID id, CreateWarehouseRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Warehouse w = warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Warehouse", id));

        String code = request.code().trim();
        if (!code.equalsIgnoreCase(w.getCode())
                && warehouseRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, code)) {
            throw new BusinessException("Warehouse with code " + code + " already exists",
                    "INV_DUPLICATE_WAREHOUSE_CODE", HttpStatus.CONFLICT);
        }

        w.setCode(code);
        w.setName(request.name().trim());
        w.setAddressLine1(request.addressLine1());
        w.setAddressLine2(request.addressLine2());
        w.setCity(request.city());
        w.setState(request.state());
        w.setStateCode(request.stateCode());
        w.setPostalCode(request.postalCode());
        if (request.country() != null) w.setCountry(request.country());

        // Promote to default → demote the prior default. We never self-clear the
        // default flag here (that would leave the org with no default); promote
        // another warehouse instead.
        if (Boolean.TRUE.equals(request.isDefault()) && !w.isDefault()) {
            UUID currentId = w.getId();
            warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                    .filter(existing -> !existing.getId().equals(currentId))
                    .ifPresent(existing -> {
                        existing.setDefault(false);
                        warehouseRepository.save(existing);
                    });
            w.setDefault(true);
        }

        w = warehouseRepository.save(w);
        auditService.log("WAREHOUSE", w.getId(), "UPDATE", null,
                "{\"code\":\"" + w.getCode() + "\"}");
        return toResponse(w);
    }

    @Transactional
    public void deleteWarehouse(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Warehouse w = warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Warehouse", id));

        if (w.isDefault()) {
            throw new BusinessException(
                    "Cannot delete the default warehouse — make another warehouse the default first",
                    "INV_WAREHOUSE_IS_DEFAULT", HttpStatus.BAD_REQUEST);
        }
        if (stockBalanceRepository.existsByOrgIdAndWarehouseIdAndQuantityOnHandGreaterThan(
                orgId, id, java.math.BigDecimal.ZERO)) {
            throw new BusinessException(
                    "Cannot delete a warehouse that still holds stock — transfer it out first",
                    "INV_WAREHOUSE_HAS_STOCK", HttpStatus.BAD_REQUEST);
        }

        w.setDeleted(true);
        w.setActive(false);
        warehouseRepository.save(w);
        auditService.log("WAREHOUSE", w.getId(), "DELETE",
                "{\"code\":\"" + w.getCode() + "\"}", null);
    }

    @Transactional(readOnly = true)
    public List<WarehouseResponse> listWarehouses() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return warehouseRepository.findByOrgIdAndIsDeletedFalseOrderByName(orgId)
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public WarehouseResponse getWarehouse(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Warehouse w = warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Warehouse", id));
        return toResponse(w);
    }

    public WarehouseResponse toResponse(Warehouse w) {
        return new WarehouseResponse(
                w.getId(), w.getCode(), w.getName(),
                w.getAddressLine1(), w.getAddressLine2(),
                w.getCity(), w.getState(), w.getStateCode(),
                w.getPostalCode(), w.getCountry(),
                w.isDefault(), w.isActive(), w.getCreatedAt());
    }
}
