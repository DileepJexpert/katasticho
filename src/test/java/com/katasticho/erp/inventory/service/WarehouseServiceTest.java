package com.katasticho.erp.inventory.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.CreateWarehouseRequest;
import com.katasticho.erp.inventory.dto.WarehouseResponse;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.organisation.BranchRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Warehouse update + delete (the previously missing CRUD half). Edit fields,
 * promote-to-default demotes the prior default, delete is soft and guarded by
 * default-status + on-hand stock.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class WarehouseServiceTest {

    @Mock private WarehouseRepository warehouseRepository;
    @Mock private BranchRepository branchRepository;
    @Mock private AuditService auditService;
    @Mock private StockBalanceRepository stockBalanceRepository;

    private WarehouseService service;
    private UUID orgId;

    @BeforeEach
    void setUp() {
        service = new WarehouseService(warehouseRepository, branchRepository,
                auditService, stockBalanceRepository);
        orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());

        lenient().when(warehouseRepository.save(any(Warehouse.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        lenient().when(stockBalanceRepository
                .existsByOrgIdAndWarehouseIdAndQuantityOnHandGreaterThan(eq(orgId), any(), any()))
                .thenReturn(false);
        lenient().when(warehouseRepository.existsByOrgIdAndCodeAndIsDeletedFalse(eq(orgId), anyString()))
                .thenReturn(false);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private Warehouse warehouse(String code, boolean isDefault) {
        Warehouse w = Warehouse.builder()
                .code(code).name("Old name").isDefault(isDefault).active(true).build();
        w.setId(UUID.randomUUID());
        lenient().when(warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(w.getId(), orgId))
                .thenReturn(Optional.of(w));
        return w;
    }

    private CreateWarehouseRequest req(String code, String name, Boolean isDefault) {
        return new CreateWarehouseRequest(code, name, "Line 1", null,
                "Mumbai", "Maharashtra", "27", "400001", "IN", isDefault, null);
    }

    @Test
    void update_changesFields() {
        Warehouse w = warehouse("WH1", false);

        WarehouseResponse resp = service.updateWarehouse(w.getId(), req("WH1", "New name", null));

        assertEquals("New name", resp.name());
        assertEquals("Mumbai", resp.city());
        assertEquals("WH1", resp.code());
    }

    @Test
    void update_codeChangedToExisting_throws() {
        Warehouse w = warehouse("WH1", false);
        when(warehouseRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, "WH2")).thenReturn(true);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.updateWarehouse(w.getId(), req("WH2", "Renamed", null)));
        assertEquals("INV_DUPLICATE_WAREHOUSE_CODE", ex.getErrorCode());
    }

    @Test
    void update_sameCodeDifferentCase_isNotADuplicate() {
        Warehouse w = warehouse("WH1", false);
        // a dup check on the same code must not trip when the code is unchanged
        lenient().when(warehouseRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, "wh1")).thenReturn(true);

        WarehouseResponse resp = service.updateWarehouse(w.getId(), req("wh1", "Same code", null));
        assertEquals("wh1", resp.code());
    }

    @Test
    void update_promoteToDefault_demotesPriorDefault() {
        Warehouse target = warehouse("WH2", false);
        Warehouse priorDefault = Warehouse.builder().code("WH1").name("Main").isDefault(true).active(true).build();
        priorDefault.setId(UUID.randomUUID());
        when(warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.of(priorDefault));

        WarehouseResponse resp = service.updateWarehouse(target.getId(), req("WH2", "Promote me", true));

        assertTrue(resp.isDefault());
        verify(warehouseRepository).clearDefaultExcept(orgId, target.getId());
    }

    @Test
    void delete_defaultWarehouse_throws() {
        Warehouse w = warehouse("WH1", true);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.deleteWarehouse(w.getId()));
        assertEquals("INV_WAREHOUSE_IS_DEFAULT", ex.getErrorCode());
        assertFalse(w.isDeleted());
    }

    @Test
    void delete_warehouseWithStock_throws() {
        Warehouse w = warehouse("WH2", false);
        when(stockBalanceRepository.existsByOrgIdAndWarehouseIdAndQuantityOnHandGreaterThan(
                orgId, w.getId(), BigDecimal.ZERO)).thenReturn(true);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.deleteWarehouse(w.getId()));
        assertEquals("INV_WAREHOUSE_HAS_STOCK", ex.getErrorCode());
        assertFalse(w.isDeleted());
    }

    @Test
    void delete_emptyNonDefault_softDeletes() {
        Warehouse w = warehouse("WH2", false);

        service.deleteWarehouse(w.getId());

        assertTrue(w.isDeleted());
        assertFalse(w.isActive());
        verify(warehouseRepository).save(w);
    }
}
