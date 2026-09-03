package com.katasticho.erp.inventory.putaway;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.inventory.putaway.dto.PutawayLineConfirmRequest;
import com.katasticho.erp.inventory.putaway.dto.PutawayTaskRequest;
import com.katasticho.erp.inventory.putaway.dto.PutawayTaskResponse;
import com.katasticho.erp.inventory.putaway.entity.WarehousePutawayLine;
import com.katasticho.erp.inventory.putaway.entity.WarehousePutawayTask;
import com.katasticho.erp.inventory.putaway.repository.WarehousePutawayLineRepository;
import com.katasticho.erp.inventory.putaway.repository.WarehousePutawayTaskRepository;
import com.katasticho.erp.inventory.putaway.service.WarehousePutawayService;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.RackLocation;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.RackLocationRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class WarehousePutawayServiceTest {

    @Mock
    private WarehousePutawayTaskRepository taskRepository;

    @Mock
    private WarehousePutawayLineRepository lineRepository;

    @Mock
    private WarehouseRepository warehouseRepository;

    @Mock
    private ItemRepository itemRepository;

    @Mock
    private RackLocationRepository rackLocationRepository;

    @InjectMocks
    private WarehousePutawayService service;

    private UUID orgId;
    private UUID userId;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void createTask_success() {
        UUID warehouseId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();

        Warehouse warehouse = new Warehouse();
        warehouse.setId(warehouseId);
        when(warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(warehouseId, orgId)).thenReturn(Optional.of(warehouse));
        Item item = new Item();
        item.setId(itemId);
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId)).thenReturn(Optional.of(item));
        when(taskRepository.save(any(WarehousePutawayTask.class))).thenAnswer(inv -> {
            WarehousePutawayTask t = inv.getArgument(0);
            t.setId(UUID.randomUUID());
            return t;
        });

        PutawayTaskRequest request = PutawayTaskRequest.builder()
                .warehouseId(warehouseId)
                .sourceLocation("DOCK_A")
                .lines(List.of(
                        PutawayTaskRequest.PutawayLineRequest.builder()
                                .itemId(itemId)
                                .batchNumber("B101")
                                .quantity(new BigDecimal("50.00"))
                                .build()
                ))
                .build();

        PutawayTaskResponse response = service.createTask(request);

        assertThat(response).isNotNull();
        assertThat(response.taskNumber()).contains("PTW-");
        assertThat(response.status()).isEqualTo("PENDING");
        assertThat(response.lines()).hasSize(1);
        verify(taskRepository).save(any(WarehousePutawayTask.class));
    }

    @Test
    void confirmLine_completesTaskWhenAllConfirmed() {
        UUID taskId = UUID.randomUUID();
        UUID lineId = UUID.randomUUID();
        UUID rackId = UUID.randomUUID();

        WarehousePutawayLine line = WarehousePutawayLine.builder()
                .itemId(UUID.randomUUID())
                .quantity(new BigDecimal("10.00"))
                .status("PENDING")
                .build();
        line.setId(lineId);

        WarehousePutawayTask task = WarehousePutawayTask.builder()
                .taskNumber("PTW-2026-0001")
                .warehouseId(UUID.randomUUID())
                .status("PENDING")
                .lines(new ArrayList<>(List.of(line)))
                .build();
        task.setId(taskId);
        task.setOrgId(orgId);
        line.setTask(task);

        Warehouse warehouse = new Warehouse();
        warehouse.setId(task.getWarehouseId());
        RackLocation rack = new RackLocation();
        rack.setId(rackId);
        rack.setOrgId(orgId);
        rack.setWarehouseId(task.getWarehouseId());
        rack.setActive(true);
        Item item = new Item();
        item.setId(line.getItemId());
        when(warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(task.getWarehouseId(), orgId)).thenReturn(Optional.of(warehouse));
        when(rackLocationRepository.findByIdAndOrgIdAndIsDeletedFalse(rackId, orgId)).thenReturn(Optional.of(rack));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(line.getItemId(), orgId)).thenReturn(Optional.of(item));

        when(taskRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, taskId))
                .thenReturn(Optional.of(task));
        when(taskRepository.save(any(WarehousePutawayTask.class))).thenAnswer(inv -> inv.getArgument(0));

        PutawayLineConfirmRequest req = PutawayLineConfirmRequest.builder()
                .confirmedRackId(rackId)
                .build();

        PutawayTaskResponse response = service.confirmLine(taskId, lineId, req);

        assertThat(response).isNotNull();
        assertThat(response.status()).isEqualTo("COMPLETED");
        assertThat(response.lines().get(0).status()).isEqualTo("CONFIRMED");
        assertThat(response.lines().get(0).confirmedRackId()).isEqualTo(rackId);
        verify(lineRepository).save(any(WarehousePutawayLine.class));
        verify(taskRepository).save(task);
    }
}
