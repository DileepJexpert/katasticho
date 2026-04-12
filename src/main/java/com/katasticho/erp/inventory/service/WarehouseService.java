package com.katasticho.erp.inventory.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.CreateWarehouseRequest;
import com.katasticho.erp.inventory.dto.WarehouseResponse;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
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
    private final AuditService auditService;

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

        Warehouse warehouse = Warehouse.builder()
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
