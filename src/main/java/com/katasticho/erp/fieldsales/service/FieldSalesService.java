package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.fieldsales.entity.*;
import com.katasticho.erp.fieldsales.repository.*;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

/**
 * FMCG Field Sales service — manages beats, routes, vans, field visits,
 * van stock transfers, day-close reconciliation, and salesman targets.
 *
 * All org-scoped queries use {@link TenantContext#getCurrentOrgId()}.
 * Stock movements flow through {@link InventoryService#recordMovement} —
 * this service never writes to stock_movement or stock_balance directly.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FieldSalesService {

    private final BeatRepository beatRepository;
    private final BeatCustomerRepository beatCustomerRepository;
    private final RouteRepository routeRepository;
    private final RouteBeatRepository routeBeatRepository;
    private final VanRepository vanRepository;
    private final VanStockBalanceRepository vanStockBalanceRepository;
    private final FieldSalesAssignmentRepository assignmentRepository;
    private final VanStockTransferRepository vanStockTransferRepository;
    private final VanStockTransferLineRepository vanStockTransferLineRepository;
    private final RouteExecutionRepository routeExecutionRepository;
    private final FieldVisitRepository fieldVisitRepository;
    private final DayCloseRepository dayCloseRepository;
    private final SalesmanTargetRepository salesmanTargetRepository;
    private final InventoryService inventoryService;
    private final StockBalanceRepository stockBalanceRepository;

    // =====================================================================
    // Beat Management
    // =====================================================================

    /**
     * Creates a new beat. Validates code uniqueness within the org.
     */
    @Transactional
    public Beat createBeat(Beat input) {
        UUID orgId = TenantContext.getCurrentOrgId();

        if (beatRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, input.getCode())) {
            throw new BusinessException(
                    "Beat with code '" + input.getCode() + "' already exists",
                    "FS_BEAT_CODE_EXISTS", HttpStatus.CONFLICT);
        }

        Beat beat = Beat.builder()
                .code(input.getCode())
                .name(input.getName())
                .area(input.getArea())
                .city(input.getCity())
                .state(input.getState())
                .description(input.getDescription())
                .isActive(true)
                .build();

        beat = beatRepository.save(beat);
        log.info("Created beat {} (code={}) for org {}", beat.getId(), input.getCode(), orgId);
        return beat;
    }

    /**
     * Updates an existing beat. Finds by id or throws 404.
     */
    @Transactional
    public Beat updateBeat(UUID id, Beat input) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Beat beat = beatRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Beat", id));

        beat.setName(input.getName());
        beat.setArea(input.getArea());
        beat.setCity(input.getCity());
        beat.setState(input.getState());
        beat.setDescription(input.getDescription());

        beat = beatRepository.save(beat);
        log.info("Updated beat {} for org {}", id, orgId);
        return beat;
    }

    /**
     * Paginated list of beats for the current org.
     */
    @Transactional(readOnly = true)
    public Page<Beat> listBeats(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return beatRepository.findByOrgIdAndIsDeletedFalse(orgId, pageable);
    }

    /**
     * Gets a single beat by id. Throws 404 if not found.
     */
    @Transactional(readOnly = true)
    public Beat getBeat(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return beatRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Beat", id));
    }

    /**
     * Soft-deletes a beat.
     */
    @Transactional
    public void deleteBeat(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Beat beat = beatRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Beat", id));

        beat.setDeleted(true);
        beat.setActive(false);
        beatRepository.save(beat);
        log.info("Soft-deleted beat {} for org {}", id, orgId);
    }

    /**
     * Adds a customer (contact) to a beat. Validates beat exists and
     * checks no duplicate active assignment. Returns the newly created BeatCustomer.
     */
    @Transactional
    public BeatCustomer addCustomerToBeat(UUID beatId, UUID contactId,
                                           Integer visitSequence, String visitFrequency) {
        UUID orgId = TenantContext.getCurrentOrgId();

        // Validate beat exists
        beatRepository.findByIdAndOrgIdAndIsDeletedFalse(beatId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Beat", beatId));

        // Check for duplicate
        List<BeatCustomer> existing = beatCustomerRepository
                .findByOrgIdAndBeatIdAndIsActiveTrue(orgId, beatId);
        boolean alreadyAssigned = existing.stream()
                .anyMatch(bc -> bc.getContactId().equals(contactId));
        if (alreadyAssigned) {
            throw new BusinessException(
                    "Contact " + contactId + " is already assigned to beat " + beatId,
                    "FS_BEAT_CUSTOMER_DUPLICATE", HttpStatus.CONFLICT);
        }

        BeatCustomer beatCustomer = BeatCustomer.builder()
                .orgId(orgId)
                .beatId(beatId)
                .contactId(contactId)
                .visitSequence(visitSequence)
                .visitFrequency(visitFrequency != null ? visitFrequency : "WEEKLY")
                .isActive(true)
                .build();

        beatCustomer = beatCustomerRepository.save(beatCustomer);
        log.info("Added contact {} to beat {} for org {}", contactId, beatId, orgId);
        return beatCustomer;
    }

    /**
     * Removes a customer from a beat.
     */
    @Transactional
    public void removeCustomerFromBeat(UUID beatId, UUID contactId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        beatCustomerRepository.deleteByOrgIdAndBeatIdAndContactId(orgId, beatId, contactId);
        log.info("Removed contact {} from beat {} for org {}", contactId, beatId, orgId);
    }

    /**
     * Returns active customers for a beat.
     */
    @Transactional(readOnly = true)
    public List<BeatCustomer> getBeatCustomers(UUID beatId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return beatCustomerRepository.findByOrgIdAndBeatIdAndIsActiveTrue(orgId, beatId);
    }

    // =====================================================================
    // Route Management
    // =====================================================================

    /**
     * Creates a new route with associated beat sequence. Validates code uniqueness.
     */
    @Transactional
    public Route createRoute(Route input, List<UUID> beatIds) {
        UUID orgId = TenantContext.getCurrentOrgId();

        if (routeRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, input.getCode())) {
            throw new BusinessException(
                    "Route with code '" + input.getCode() + "' already exists",
                    "FS_ROUTE_CODE_EXISTS", HttpStatus.CONFLICT);
        }

        Route route = Route.builder()
                .code(input.getCode())
                .name(input.getName())
                .dayOfWeek(input.getDayOfWeek())
                .frequency(input.getFrequency() != null ? input.getFrequency() : "WEEKLY")
                .warehouseId(input.getWarehouseId())
                .isActive(true)
                .build();

        route = routeRepository.save(route);

        // Create RouteBeat entries with sequential ordering
        if (beatIds != null && !beatIds.isEmpty()) {
            createRouteBeats(orgId, route.getId(), beatIds);
        }

        log.info("Created route {} (code={}) with {} beats for org {}",
                route.getId(), input.getCode(), beatIds != null ? beatIds.size() : 0, orgId);
        return route;
    }

    /**
     * Updates an existing route. Rebuilds the beat list.
     * Note: beatIds are not passed from the controller's updateRoute call,
     * so the route beat list is left as-is unless the caller rebuilds it separately.
     */
    @Transactional
    public Route updateRoute(UUID id, Route input) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Route route = routeRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Route", id));

        route.setName(input.getName());
        route.setDayOfWeek(input.getDayOfWeek());
        route.setFrequency(input.getFrequency() != null ? input.getFrequency() : route.getFrequency());
        route.setWarehouseId(input.getWarehouseId());

        route = routeRepository.save(route);
        log.info("Updated route {} for org {}", id, orgId);
        return route;
    }

    /**
     * Paginated list of routes for the current org.
     */
    @Transactional(readOnly = true)
    public Page<Route> listRoutes(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return routeRepository.findByOrgIdAndIsDeletedFalse(orgId, pageable);
    }

    /**
     * Gets a single route by id. Throws 404 if not found.
     */
    @Transactional(readOnly = true)
    public Route getRoute(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return routeRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Route", id));
    }

    /**
     * Soft-deletes a route.
     */
    @Transactional
    public void deleteRoute(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Route route = routeRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Route", id));

        route.setDeleted(true);
        route.setActive(false);
        routeRepository.save(route);
        log.info("Soft-deleted route {} for org {}", id, orgId);
    }

    /**
     * Returns ordered beat entries for a route.
     */
    @Transactional(readOnly = true)
    public List<RouteBeat> getRouteBeats(UUID routeId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return routeBeatRepository.findByOrgIdAndRouteIdOrderBySequenceNumber(orgId, routeId);
    }

    private void createRouteBeats(UUID orgId, UUID routeId, List<UUID> beatIds) {
        for (int i = 0; i < beatIds.size(); i++) {
            RouteBeat rb = RouteBeat.builder()
                    .orgId(orgId)
                    .routeId(routeId)
                    .beatId(beatIds.get(i))
                    .sequenceNumber(i + 1)
                    .build();
            routeBeatRepository.save(rb);
        }
    }

    // =====================================================================
    // Van Management
    // =====================================================================

    /**
     * Creates a new van. Validates code uniqueness.
     */
    @Transactional
    public Van createVan(Van input) {
        UUID orgId = TenantContext.getCurrentOrgId();

        if (vanRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, input.getCode())) {
            throw new BusinessException(
                    "Van with code '" + input.getCode() + "' already exists",
                    "FS_VAN_CODE_EXISTS", HttpStatus.CONFLICT);
        }

        Van van = Van.builder()
                .code(input.getCode())
                .vehicleNumber(input.getVehicleNumber())
                .name(input.getName())
                .vehicleType(input.getVehicleType() != null ? input.getVehicleType() : "VAN")
                .sourceWarehouseId(input.getSourceWarehouseId())
                .capacityWeightKg(input.getCapacityWeightKg())
                .capacityVolumeLitre(input.getCapacityVolumeLitre())
                .isActive(true)
                .build();

        van = vanRepository.save(van);
        log.info("Created van {} (code={}, vehicle={}) for org {}",
                van.getId(), input.getCode(), input.getVehicleNumber(), orgId);
        return van;
    }

    /**
     * Updates an existing van. Finds by id or throws 404.
     */
    @Transactional
    public Van updateVan(UUID id, Van input) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Van van = vanRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Van", id));

        van.setName(input.getName());
        van.setVehicleType(input.getVehicleType() != null ? input.getVehicleType() : van.getVehicleType());
        van.setSourceWarehouseId(input.getSourceWarehouseId());
        van.setCapacityWeightKg(input.getCapacityWeightKg());
        van.setCapacityVolumeLitre(input.getCapacityVolumeLitre());

        van = vanRepository.save(van);
        log.info("Updated van {} for org {}", id, orgId);
        return van;
    }

    /**
     * Paginated list of vans for the current org.
     */
    @Transactional(readOnly = true)
    public Page<Van> listVans(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return vanRepository.findByOrgIdAndIsDeletedFalse(orgId, pageable);
    }

    /**
     * Gets a single van by id. Throws 404 if not found.
     */
    @Transactional(readOnly = true)
    public Van getVan(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return vanRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Van", id));
    }

    /**
     * Soft-deletes a van.
     */
    @Transactional
    public void deleteVan(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Van van = vanRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Van", id));

        van.setDeleted(true);
        van.setActive(false);
        vanRepository.save(van);
        log.info("Soft-deleted van {} for org {}", id, orgId);
    }

    /**
     * Returns current stock balances on a van.
     */
    @Transactional(readOnly = true)
    public List<VanStockBalance> getVanStock(UUID vanId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return vanStockBalanceRepository.findByOrgIdAndVanId(orgId, vanId);
    }

    // =====================================================================
    // Field Sales Assignment
    // =====================================================================

    /**
     * Creates a new field sales assignment.
     */
    @Transactional
    public FieldSalesAssignment createAssignment(FieldSalesAssignment input) {
        UUID orgId = TenantContext.getCurrentOrgId();

        FieldSalesAssignment assignment = FieldSalesAssignment.builder()
                .orgId(orgId)
                .salespersonId(input.getSalespersonId())
                .routeId(input.getRouteId())
                .vanId(input.getVanId())
                .territory(input.getTerritory())
                .effectiveFrom(input.getEffectiveFrom())
                .effectiveTo(input.getEffectiveTo())
                .isActive(true)
                .build();

        assignment = assignmentRepository.save(assignment);
        log.info("Created field sales assignment {} for salesperson {} on route {} for org {}",
                assignment.getId(), input.getSalespersonId(), input.getRouteId(), orgId);
        return assignment;
    }

    /**
     * Returns active assignments for a specific salesperson.
     */
    @Transactional(readOnly = true)
    public List<FieldSalesAssignment> getAssignmentsForSalesperson(UUID salespersonId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return assignmentRepository.findByOrgIdAndSalespersonIdAndIsActiveTrue(orgId, salespersonId);
    }

    /**
     * Returns all active assignments for the current org.
     */
    @Transactional(readOnly = true)
    public List<FieldSalesAssignment> getAllAssignments() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return assignmentRepository.findByOrgIdAndIsActiveTrue(orgId);
    }

    // =====================================================================
    // Van Stock Transfer (Load / Unload / Return)
    // =====================================================================

    /**
     * Creates a DRAFT van load transfer. Lines are provided as raw maps
     * from the controller's JSON deserialization.
     */
    @Transactional
    public VanStockTransfer createVanLoad(UUID vanId, UUID warehouseId,
                                           List<Map<String, Object>> lineMaps) {
        UUID orgId = TenantContext.getCurrentOrgId();

        // Validate van exists
        vanRepository.findByIdAndOrgIdAndIsDeletedFalse(vanId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Van", vanId));

        VanStockTransfer transfer = VanStockTransfer.builder()
                .vanId(vanId)
                .warehouseId(warehouseId)
                .transferType("LOAD")
                .transferDate(LocalDate.now())
                .status("DRAFT")
                .build();

        transfer = vanStockTransferRepository.save(transfer);

        saveTransferLinesFromMaps(orgId, transfer.getId(), lineMaps);

        log.info("Created van load transfer {} for van {} from warehouse {} with {} lines for org {}",
                transfer.getId(), vanId, warehouseId, lineMaps.size(), orgId);
        return transfer;
    }

    /**
     * Confirms a DRAFT van load: validates warehouse stock, deducts from
     * warehouse via InventoryService, and credits van_stock_balance.
     */
    @Transactional
    public VanStockTransfer confirmVanLoad(UUID transferId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        VanStockTransfer transfer = vanStockTransferRepository
                .findByIdAndOrgIdAndIsDeletedFalse(transferId, orgId)
                .orElseThrow(() -> BusinessException.notFound("VanStockTransfer", transferId));

        if (!"DRAFT".equals(transfer.getStatus())) {
            throw new BusinessException(
                    "Van load transfer must be in DRAFT status to confirm, current: " + transfer.getStatus(),
                    "FS_TRANSFER_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        if (!"LOAD".equals(transfer.getTransferType())) {
            throw new BusinessException(
                    "Transfer " + transferId + " is not a LOAD transfer",
                    "FS_TRANSFER_TYPE_MISMATCH", HttpStatus.BAD_REQUEST);
        }

        List<VanStockTransferLine> lines = vanStockTransferLineRepository
                .findByOrgIdAndVanStockTransferId(orgId, transferId);

        // Validate warehouse stock availability for each line
        for (VanStockTransferLine line : lines) {
            validateWarehouseStock(orgId, transfer.getWarehouseId(), line.getItemId(),
                    line.getBatchId(), line.getQuantity());
        }

        // Process each line: deduct from warehouse, add to van
        for (VanStockTransferLine line : lines) {
            // Deduct warehouse stock via InventoryService
            inventoryService.recordMovement(new StockMovementRequest(
                    line.getItemId(),
                    transfer.getWarehouseId(),
                    MovementType.TRANSFER_OUT,
                    line.getQuantity().negate(),  // negative = stock out
                    null,                         // unitCost
                    transfer.getTransferDate(),
                    ReferenceType.VAN_LOAD,
                    transfer.getId(),
                    "VAN-LOAD-" + transfer.getId().toString().substring(0, 8),
                    "Van load to van " + transfer.getVanId(),
                    line.getBatchId()
            ));

            // Add to van stock balance
            adjustVanStockBalance(orgId, transfer.getVanId(), line.getItemId(),
                    line.getBatchId(), line.getQuantity());
        }

        transfer.setStatus("CONFIRMED");
        transfer.setConfirmedBy(userId);
        transfer.setConfirmedAt(Instant.now());
        transfer = vanStockTransferRepository.save(transfer);

        log.info("Confirmed van load transfer {} ({} lines) for org {}",
                transferId, lines.size(), orgId);
        return transfer;
    }

    /**
     * Creates a DRAFT van return transfer. Lines are provided as raw maps.
     */
    @Transactional
    public VanStockTransfer createVanReturn(UUID vanId, UUID warehouseId,
                                             UUID routeExecutionId,
                                             List<Map<String, Object>> lineMaps) {
        UUID orgId = TenantContext.getCurrentOrgId();

        // Validate van exists
        vanRepository.findByIdAndOrgIdAndIsDeletedFalse(vanId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Van", vanId));

        VanStockTransfer transfer = VanStockTransfer.builder()
                .vanId(vanId)
                .warehouseId(warehouseId)
                .transferType("RETURN")
                .transferDate(LocalDate.now())
                .routeExecutionId(routeExecutionId)
                .status("DRAFT")
                .build();

        transfer = vanStockTransferRepository.save(transfer);

        saveTransferLinesFromMaps(orgId, transfer.getId(), lineMaps);

        log.info("Created van return transfer {} for van {} to warehouse {} with {} lines for org {}",
                transfer.getId(), vanId, warehouseId, lineMaps.size(), orgId);
        return transfer;
    }

    /**
     * Confirms a DRAFT van return: validates van stock, deducts from
     * van_stock_balance, and credits warehouse via InventoryService.
     */
    @Transactional
    public VanStockTransfer confirmVanReturn(UUID transferId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        VanStockTransfer transfer = vanStockTransferRepository
                .findByIdAndOrgIdAndIsDeletedFalse(transferId, orgId)
                .orElseThrow(() -> BusinessException.notFound("VanStockTransfer", transferId));

        if (!"DRAFT".equals(transfer.getStatus())) {
            throw new BusinessException(
                    "Van return transfer must be in DRAFT status to confirm, current: " + transfer.getStatus(),
                    "FS_TRANSFER_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        if (!"RETURN".equals(transfer.getTransferType())) {
            throw new BusinessException(
                    "Transfer " + transferId + " is not a RETURN transfer",
                    "FS_TRANSFER_TYPE_MISMATCH", HttpStatus.BAD_REQUEST);
        }

        List<VanStockTransferLine> lines = vanStockTransferLineRepository
                .findByOrgIdAndVanStockTransferId(orgId, transferId);

        // Validate van stock availability for each line
        for (VanStockTransferLine line : lines) {
            validateVanStock(orgId, transfer.getVanId(), line.getItemId(),
                    line.getBatchId(), line.getQuantity());
        }

        // Process each line: deduct from van, add to warehouse
        for (VanStockTransferLine line : lines) {
            // Deduct from van stock balance
            adjustVanStockBalance(orgId, transfer.getVanId(), line.getItemId(),
                    line.getBatchId(), line.getQuantity().negate());

            // Add warehouse stock via InventoryService
            inventoryService.recordMovement(new StockMovementRequest(
                    line.getItemId(),
                    transfer.getWarehouseId(),
                    MovementType.TRANSFER_IN,
                    line.getQuantity(),           // positive = stock in
                    null,                         // unitCost
                    transfer.getTransferDate(),
                    ReferenceType.VAN_RETURN,
                    transfer.getId(),
                    "VAN-RET-" + transfer.getId().toString().substring(0, 8),
                    "Van return from van " + transfer.getVanId(),
                    line.getBatchId()
            ));
        }

        transfer.setStatus("CONFIRMED");
        transfer.setConfirmedBy(userId);
        transfer.setConfirmedAt(Instant.now());
        transfer = vanStockTransferRepository.save(transfer);

        log.info("Confirmed van return transfer {} ({} lines) for org {}",
                transferId, lines.size(), orgId);
        return transfer;
    }

    /**
     * Paginated list of van stock transfers for a specific van.
     */
    @Transactional(readOnly = true)
    public Page<VanStockTransfer> listVanTransfers(UUID vanId, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return vanStockTransferRepository.findByOrgIdAndVanIdAndIsDeletedFalse(orgId, vanId, pageable);
    }

    /**
     * Returns lines for a specific transfer.
     */
    @Transactional(readOnly = true)
    public List<VanStockTransferLine> getTransferLines(UUID transferId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return vanStockTransferLineRepository.findByOrgIdAndVanStockTransferId(orgId, transferId);
    }

    // =====================================================================
    // Van Stock Helpers
    // =====================================================================

    /**
     * Parses transfer lines from raw JSON maps and persists them.
     * Expected keys: itemId (String UUID), batchId (optional String UUID),
     * quantity (Number), unit (optional String), notes (optional String).
     */
    private void saveTransferLinesFromMaps(UUID orgId, UUID transferId,
                                            List<Map<String, Object>> lineMaps) {
        for (Map<String, Object> map : lineMaps) {
            VanStockTransferLine line = VanStockTransferLine.builder()
                    .orgId(orgId)
                    .vanStockTransferId(transferId)
                    .itemId(UUID.fromString((String) map.get("itemId")))
                    .batchId(map.get("batchId") != null
                            ? UUID.fromString((String) map.get("batchId")) : null)
                    .quantity(new BigDecimal(map.get("quantity").toString()))
                    .unit(map.get("unit") != null ? (String) map.get("unit") : null)
                    .notes(map.get("notes") != null ? (String) map.get("notes") : null)
                    .build();
            vanStockTransferLineRepository.save(line);
        }
    }

    /**
     * Adjusts the van_stock_balance row for the given van/item/batch.
     * Creates the row if it does not exist. Delta can be positive (add)
     * or negative (deduct).
     */
    private void adjustVanStockBalance(UUID orgId, UUID vanId, UUID itemId,
                                        UUID batchId, BigDecimal delta) {
        Optional<VanStockBalance> existing;
        if (batchId != null) {
            existing = vanStockBalanceRepository
                    .findByOrgIdAndVanIdAndItemIdAndBatchId(orgId, vanId, itemId, batchId);
        } else {
            existing = vanStockBalanceRepository
                    .findByOrgIdAndVanIdAndItemId(orgId, vanId, itemId);
        }

        if (existing.isPresent()) {
            VanStockBalance balance = existing.get();
            balance.setQuantityOnHand(balance.getQuantityOnHand().add(delta));
            balance.setLastMovementAt(Instant.now());
            vanStockBalanceRepository.save(balance);
        } else {
            VanStockBalance balance = VanStockBalance.builder()
                    .orgId(orgId)
                    .vanId(vanId)
                    .itemId(itemId)
                    .batchId(batchId)
                    .quantityOnHand(delta)
                    .lastMovementAt(Instant.now())
                    .build();
            vanStockBalanceRepository.save(balance);
        }
    }

    /**
     * Validates that the warehouse has sufficient stock for the requested quantity.
     */
    private void validateWarehouseStock(UUID orgId, UUID warehouseId, UUID itemId,
                                         UUID batchId, BigDecimal requiredQty) {
        Optional<StockBalance> balance = stockBalanceRepository
                .findByOrgIdAndItemIdAndWarehouseId(orgId, itemId, warehouseId);

        BigDecimal available = balance.map(StockBalance::getQuantityOnHand)
                .orElse(BigDecimal.ZERO);

        if (available.compareTo(requiredQty) < 0) {
            throw new BusinessException(
                    "Insufficient warehouse stock for item " + itemId +
                            ": available=" + available.toPlainString() +
                            ", required=" + requiredQty.toPlainString(),
                    "FS_WAREHOUSE_INSUFFICIENT_STOCK", HttpStatus.BAD_REQUEST);
        }
    }

    /**
     * Validates that the van has sufficient stock for the requested quantity.
     */
    private void validateVanStock(UUID orgId, UUID vanId, UUID itemId,
                                   UUID batchId, BigDecimal requiredQty) {
        Optional<VanStockBalance> existing;
        if (batchId != null) {
            existing = vanStockBalanceRepository
                    .findByOrgIdAndVanIdAndItemIdAndBatchId(orgId, vanId, itemId, batchId);
        } else {
            existing = vanStockBalanceRepository
                    .findByOrgIdAndVanIdAndItemId(orgId, vanId, itemId);
        }

        BigDecimal available = existing.map(VanStockBalance::getQuantityOnHand)
                .orElse(BigDecimal.ZERO);

        if (available.compareTo(requiredQty) < 0) {
            throw new BusinessException(
                    "Insufficient van stock for item " + itemId +
                            ": available=" + available.toPlainString() +
                            ", required=" + requiredQty.toPlainString(),
                    "FS_VAN_INSUFFICIENT_STOCK", HttpStatus.BAD_REQUEST);
        }
    }

    // =====================================================================
    // Route Execution
    // =====================================================================

    /**
     * Creates a new route execution in PLANNED status. Auto-creates
     * FieldVisit entries from the route's beats' customers.
     */
    @Transactional
    public RouteExecution startExecution(UUID routeId, UUID salespersonId,
                                         UUID vanId, LocalDate executionDate) {
        UUID orgId = TenantContext.getCurrentOrgId();

        routeRepository.findByIdAndOrgIdAndIsDeletedFalse(routeId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Route", routeId));

        // Create route execution
        RouteExecution execution = RouteExecution.builder()
                .routeId(routeId)
                .salespersonId(salespersonId)
                .vanId(vanId)
                .executionDate(executionDate)
                .status("PLANNED")
                .plannedVisits(0)
                .completedVisits(0)
                .skippedVisits(0)
                .totalOrdersValue(BigDecimal.ZERO)
                .totalCollections(BigDecimal.ZERO)
                .build();

        execution = routeExecutionRepository.save(execution);

        // Auto-create FieldVisit entries from route's beats' customers
        List<RouteBeat> routeBeats = routeBeatRepository
                .findByOrgIdAndRouteIdOrderBySequenceNumber(orgId, routeId);

        int visitSequence = 0;
        for (RouteBeat rb : routeBeats) {
            List<BeatCustomer> customers = beatCustomerRepository
                    .findByOrgIdAndBeatIdAndIsActiveTrue(orgId, rb.getBeatId());

            for (BeatCustomer bc : customers) {
                visitSequence++;
                FieldVisit visit = FieldVisit.builder()
                        .orgId(orgId)
                        .routeExecutionId(execution.getId())
                        .contactId(bc.getContactId())
                        .beatId(rb.getBeatId())
                        .sequenceNumber(visitSequence)
                        .status("PLANNED")
                        .orderValue(BigDecimal.ZERO)
                        .collectionAmount(BigDecimal.ZERO)
                        .isDeleted(false)
                        .build();
                fieldVisitRepository.save(visit);
            }
        }

        execution.setPlannedVisits(visitSequence);
        execution = routeExecutionRepository.save(execution);

        log.info("Created route execution {} for route {} with {} planned visits for org {}",
                execution.getId(), routeId, visitSequence, orgId);
        return execution;
    }

    /**
     * Gets a single route execution by id. Throws 404 if not found.
     */
    @Transactional(readOnly = true)
    public RouteExecution getExecution(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return routeExecutionRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("RouteExecution", id));
    }

    /**
     * Paginated list of route executions for the current org.
     */
    @Transactional(readOnly = true)
    public Page<RouteExecution> listExecutions(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return routeExecutionRepository.findByOrgIdAndIsDeletedFalse(orgId, pageable);
    }

    /**
     * Returns all route executions for a specific date.
     */
    @Transactional(readOnly = true)
    public List<RouteExecution> getExecutionsByDate(LocalDate date) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return routeExecutionRepository.findByOrgIdAndExecutionDateAndIsDeletedFalse(orgId, date);
    }

    @Transactional(readOnly = true)
    public List<RouteExecution> getExecutionsForSalesperson(UUID salespersonId, LocalDate date) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return routeExecutionRepository.findAllByOrgIdAndSalespersonIdAndExecutionDateAndIsDeletedFalse(
                orgId, salespersonId, date);
    }

    /**
     * Transitions a PLANNED execution to IN_PROGRESS. Sets start time.
     */
    @Transactional
    public RouteExecution startRoute(UUID executionId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        RouteExecution execution = routeExecutionRepository
                .findByIdAndOrgIdAndIsDeletedFalse(executionId, orgId)
                .orElseThrow(() -> BusinessException.notFound("RouteExecution", executionId));

        if (!"PLANNED".equals(execution.getStatus())) {
            throw new BusinessException(
                    "Route execution must be in PLANNED status to start, current: " + execution.getStatus(),
                    "FS_EXECUTION_NOT_PLANNED", HttpStatus.BAD_REQUEST);
        }

        execution.setStatus("IN_PROGRESS");
        execution.setStartTime(Instant.now());
        execution = routeExecutionRepository.save(execution);

        log.info("Started route execution {} for org {}", executionId, orgId);
        return execution;
    }

    /**
     * Completes an IN_PROGRESS execution. Aggregates visit stats
     * (completed, skipped, orders, collections) and sets end time.
     */
    @Transactional
    public RouteExecution completeRoute(UUID executionId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        RouteExecution execution = routeExecutionRepository
                .findByIdAndOrgIdAndIsDeletedFalse(executionId, orgId)
                .orElseThrow(() -> BusinessException.notFound("RouteExecution", executionId));

        if (!"IN_PROGRESS".equals(execution.getStatus())) {
            throw new BusinessException(
                    "Route execution must be IN_PROGRESS to complete, current: " + execution.getStatus(),
                    "FS_EXECUTION_NOT_IN_PROGRESS", HttpStatus.BAD_REQUEST);
        }

        // Update summary counts from visits
        List<FieldVisit> visits = fieldVisitRepository
                .findByOrgIdAndRouteExecutionIdAndIsDeletedFalseOrderBySequenceNumber(orgId, executionId);

        int completedVisits = 0;
        int skippedVisits = 0;
        BigDecimal totalOrdersValue = BigDecimal.ZERO;
        BigDecimal totalCollections = BigDecimal.ZERO;

        for (FieldVisit visit : visits) {
            if ("COMPLETED".equals(visit.getStatus())) {
                completedVisits++;
            } else if ("SKIPPED".equals(visit.getStatus())) {
                skippedVisits++;
            }
            totalOrdersValue = totalOrdersValue.add(
                    visit.getOrderValue() != null ? visit.getOrderValue() : BigDecimal.ZERO);
            totalCollections = totalCollections.add(
                    visit.getCollectionAmount() != null ? visit.getCollectionAmount() : BigDecimal.ZERO);
        }

        execution.setStatus("COMPLETED");
        execution.setEndTime(Instant.now());
        execution.setCompletedVisits(completedVisits);
        execution.setSkippedVisits(skippedVisits);
        execution.setTotalOrdersValue(totalOrdersValue);
        execution.setTotalCollections(totalCollections);

        execution = routeExecutionRepository.save(execution);

        log.info("Completed route execution {}: {}/{} visits completed, orders={}, collections={} for org {}",
                executionId, completedVisits, execution.getPlannedVisits(),
                totalOrdersValue.toPlainString(), totalCollections.toPlainString(), orgId);
        return execution;
    }

    // =====================================================================
    // Field Visit
    // =====================================================================

    /**
     * Records check-in for a field visit: sets status to IN_PROGRESS,
     * captures time and geo coordinates.
     */
    @Transactional
    public FieldVisit checkIn(UUID visitId, BigDecimal latitude, BigDecimal longitude) {
        UUID orgId = TenantContext.getCurrentOrgId();

        FieldVisit visit = fieldVisitRepository.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId)
                .orElseThrow(() -> BusinessException.notFound("FieldVisit", visitId));
        ensureVisitOwnership(visit, orgId);

        if (!"PLANNED".equals(visit.getStatus())) {
            throw new BusinessException(
                    "Visit must be in PLANNED status to check in, current: " + visit.getStatus(),
                    "FS_VISIT_NOT_PLANNED", HttpStatus.BAD_REQUEST);
        }

        visit.setStatus("IN_PROGRESS");
        visit.setCheckInTime(Instant.now());
        visit.setCheckInLatitude(latitude);
        visit.setCheckInLongitude(longitude);

        visit = fieldVisitRepository.save(visit);
        log.info("Checked in to visit {} at ({}, {}) for org {}",
                visitId, latitude, longitude, orgId);
        return visit;
    }

    /**
     * Records check-out for a field visit: sets status to COMPLETED,
     * captures time, geo coordinates, and notes.
     */
    @Transactional
    public FieldVisit checkOut(UUID visitId, BigDecimal latitude,
                               BigDecimal longitude, String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();

        FieldVisit visit = fieldVisitRepository.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId)
                .orElseThrow(() -> BusinessException.notFound("FieldVisit", visitId));
        ensureVisitOwnership(visit, orgId);

        if (!"IN_PROGRESS".equals(visit.getStatus())) {
            throw new BusinessException(
                    "Visit must be IN_PROGRESS to check out, current: " + visit.getStatus(),
                    "FS_VISIT_NOT_IN_PROGRESS", HttpStatus.BAD_REQUEST);
        }

        visit.setStatus("COMPLETED");
        visit.setCheckOutTime(Instant.now());
        visit.setCheckOutLatitude(latitude);
        visit.setCheckOutLongitude(longitude);
        visit.setNotes(notes);

        visit = fieldVisitRepository.save(visit);
        log.info("Checked out of visit {} at ({}, {}) for org {}",
                visitId, latitude, longitude, orgId);
        return visit;
    }

    /**
     * Marks a visit as skipped with a reason.
     */
    @Transactional
    public FieldVisit skipVisit(UUID visitId, String skipReason) {
        UUID orgId = TenantContext.getCurrentOrgId();

        FieldVisit visit = fieldVisitRepository.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId)
                .orElseThrow(() -> BusinessException.notFound("FieldVisit", visitId));
        ensureVisitOwnership(visit, orgId);

        if ("COMPLETED".equals(visit.getStatus()) || "SKIPPED".equals(visit.getStatus())) {
            throw new BusinessException(
                    "Visit is already " + visit.getStatus() + " and cannot be skipped",
                    "FS_VISIT_ALREADY_FINALIZED", HttpStatus.BAD_REQUEST);
        }

        visit.setStatus("SKIPPED");
        visit.setSkipReason(skipReason);

        visit = fieldVisitRepository.save(visit);
        log.info("Skipped visit {} (reason: {}) for org {}", visitId, skipReason, orgId);
        return visit;
    }

    /**
     * Links a sales order to a visit and records the order value.
     */
    @Transactional
    public FieldVisit recordVisitOrder(UUID visitId, UUID salesOrderId, BigDecimal orderValue) {
        UUID orgId = TenantContext.getCurrentOrgId();

        FieldVisit visit = fieldVisitRepository.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId)
                .orElseThrow(() -> BusinessException.notFound("FieldVisit", visitId));
        ensureVisitOwnership(visit, orgId);

        visit.setSalesOrderId(salesOrderId);
        visit.setOrderValue(orderValue != null ? orderValue : BigDecimal.ZERO);

        visit = fieldVisitRepository.save(visit);
        log.info("Recorded order {} (value={}) on visit {} for org {}",
                salesOrderId, orderValue, visitId, orgId);
        return visit;
    }

    /**
     * Records the collection amount on a visit.
     */
    @Transactional
    public FieldVisit recordVisitCollection(UUID visitId, BigDecimal collectionAmount) {
        UUID orgId = TenantContext.getCurrentOrgId();

        FieldVisit visit = fieldVisitRepository.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId)
                .orElseThrow(() -> BusinessException.notFound("FieldVisit", visitId));
        ensureVisitOwnership(visit, orgId);

        visit.setCollectionAmount(collectionAmount != null ? collectionAmount : BigDecimal.ZERO);

        visit = fieldVisitRepository.save(visit);
        log.info("Recorded collection {} on visit {} for org {}",
                collectionAmount, visitId, orgId);
        return visit;
    }

    /**
     * Returns all visits for a route execution, ordered by sequence.
     */
    @Transactional(readOnly = true)
    public List<FieldVisit> getVisits(UUID routeExecutionId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return fieldVisitRepository
                .findByOrgIdAndRouteExecutionIdAndIsDeletedFalseOrderBySequenceNumber(orgId, routeExecutionId);
    }

    private void ensureVisitOwnership(FieldVisit visit, UUID orgId) {
        UUID currentUserId = TenantContext.getCurrentUserId();
        RouteExecution execution = routeExecutionRepository
                .findByIdAndOrgIdAndIsDeletedFalse(visit.getRouteExecutionId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("RouteExecution", visit.getRouteExecutionId()));
        if (!execution.getSalespersonId().equals(currentUserId)) {
            throw new BusinessException(
                    "Only the assigned salesperson can perform this visit action",
                    "FS_NOT_ASSIGNED_SALESPERSON", HttpStatus.FORBIDDEN);
        }
    }

    // =====================================================================
    // Day Close
    // =====================================================================

    /**
     * Initiates day close for a completed route execution. Auto-populates
     * summary fields from visits and van transfers.
     */
    @Transactional
    public DayClose initiateDayClose(UUID routeExecutionId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        RouteExecution execution = routeExecutionRepository
                .findByIdAndOrgIdAndIsDeletedFalse(routeExecutionId, orgId)
                .orElseThrow(() -> BusinessException.notFound("RouteExecution", routeExecutionId));

        if (!"COMPLETED".equals(execution.getStatus())) {
            throw new BusinessException(
                    "Route execution must be COMPLETED before initiating day close, current: " + execution.getStatus(),
                    "FS_EXECUTION_NOT_COMPLETED", HttpStatus.BAD_REQUEST);
        }

        // Check if day close already exists for this execution
        Optional<DayClose> existingDayClose = dayCloseRepository
                .findByOrgIdAndRouteExecutionIdAndIsDeletedFalse(orgId, routeExecutionId);
        if (existingDayClose.isPresent()) {
            throw new BusinessException(
                    "Day close already exists for route execution " + routeExecutionId,
                    "FS_DAY_CLOSE_ALREADY_EXISTS", HttpStatus.CONFLICT);
        }

        // Gather visit summary
        List<FieldVisit> visits = fieldVisitRepository
                .findByOrgIdAndRouteExecutionIdAndIsDeletedFalseOrderBySequenceNumber(orgId, routeExecutionId);

        int visitsPlanned = visits.size();
        int visitsCompleted = 0;
        int visitsProductive = 0;
        BigDecimal totalOrdersValue = BigDecimal.ZERO;
        BigDecimal totalCollections = BigDecimal.ZERO;

        for (FieldVisit visit : visits) {
            if ("COMPLETED".equals(visit.getStatus())) {
                visitsCompleted++;
                if (visit.getOrderValue() != null && visit.getOrderValue().compareTo(BigDecimal.ZERO) > 0) {
                    visitsProductive++;
                }
            }
            totalOrdersValue = totalOrdersValue.add(
                    visit.getOrderValue() != null ? visit.getOrderValue() : BigDecimal.ZERO);
            totalCollections = totalCollections.add(
                    visit.getCollectionAmount() != null ? visit.getCollectionAmount() : BigDecimal.ZERO);
        }

        DayClose dayClose = DayClose.builder()
                .routeExecutionId(routeExecutionId)
                .salespersonId(execution.getSalespersonId())
                .vanId(execution.getVanId())
                .closeDate(execution.getExecutionDate())
                .status("PENDING")
                .openingCash(BigDecimal.ZERO)
                .cashCollections(totalCollections)
                .cashExpenses(BigDecimal.ZERO)
                .closingCash(BigDecimal.ZERO)
                .cashDeposited(BigDecimal.ZERO)
                .cashVariance(BigDecimal.ZERO)
                .visitsPlanned(visitsPlanned)
                .visitsCompleted(visitsCompleted)
                .visitsProductive(visitsProductive)
                .totalOrdersValue(totalOrdersValue)
                .totalCollections(totalCollections)
                .totalReturnsValue(BigDecimal.ZERO)
                .build();

        dayClose = dayCloseRepository.save(dayClose);

        log.info("Initiated day close {} for route execution {} (visits={}/{}, orders={}, collections={}) for org {}",
                dayClose.getId(), routeExecutionId, visitsCompleted, visitsPlanned,
                totalOrdersValue.toPlainString(), totalCollections.toPlainString(), orgId);
        return dayClose;
    }

    /**
     * Gets a single day close by id. Throws 404 if not found.
     */
    @Transactional(readOnly = true)
    public DayClose getDayClose(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return dayCloseRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("DayClose", id));
    }

    /**
     * Submits a day close with cash reconciliation. Calculates cash variance:
     * closingCash + cashDeposited - openingCash - cashCollections + cashExpenses.
     */
    @Transactional
    public DayClose submitDayClose(UUID id, BigDecimal closingCash,
                                    BigDecimal cashDeposited, String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();

        DayClose dayClose = dayCloseRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("DayClose", id));

        if (!"PENDING".equals(dayClose.getStatus())) {
            throw new BusinessException(
                    "Day close must be in PENDING status to submit, current: " + dayClose.getStatus(),
                    "FS_DAY_CLOSE_NOT_PENDING", HttpStatus.BAD_REQUEST);
        }

        dayClose.setClosingCash(closingCash != null ? closingCash : BigDecimal.ZERO);
        dayClose.setCashDeposited(cashDeposited != null ? cashDeposited : BigDecimal.ZERO);
        dayClose.setNotes(notes);

        // Calculate variance: closingCash + cashDeposited - openingCash - cashCollections + cashExpenses
        BigDecimal opening = dayClose.getOpeningCash() != null ? dayClose.getOpeningCash() : BigDecimal.ZERO;
        BigDecimal collections = dayClose.getCashCollections() != null ? dayClose.getCashCollections() : BigDecimal.ZERO;
        BigDecimal expenses = dayClose.getCashExpenses() != null ? dayClose.getCashExpenses() : BigDecimal.ZERO;
        BigDecimal closing = dayClose.getClosingCash();
        BigDecimal deposited = dayClose.getCashDeposited();

        BigDecimal variance = closing.add(deposited)
                .subtract(opening)
                .subtract(collections)
                .add(expenses);

        dayClose.setCashVariance(variance);
        dayClose.setStatus("SUBMITTED");

        dayClose = dayCloseRepository.save(dayClose);

        log.info("Submitted day close {} with variance={} for org {}",
                id, variance.toPlainString(), orgId);
        return dayClose;
    }

    /**
     * Approves a submitted day close. Records approver and timestamp.
     */
    @Transactional
    public DayClose approveDayClose(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        DayClose dayClose = dayCloseRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("DayClose", id));

        if (!"SUBMITTED".equals(dayClose.getStatus())) {
            throw new BusinessException(
                    "Day close must be in SUBMITTED status to approve, current: " + dayClose.getStatus(),
                    "FS_DAY_CLOSE_NOT_SUBMITTED", HttpStatus.BAD_REQUEST);
        }

        dayClose.setStatus("APPROVED");
        dayClose.setApprovedBy(userId);
        dayClose.setApprovedAt(Instant.now());

        dayClose = dayCloseRepository.save(dayClose);

        log.info("Approved day close {} by user {} for org {}", id, userId, orgId);
        return dayClose;
    }

    /**
     * Rejects a submitted day close with a reason.
     */
    @Transactional
    public DayClose rejectDayClose(UUID id, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();

        DayClose dayClose = dayCloseRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("DayClose", id));

        if (!"SUBMITTED".equals(dayClose.getStatus())) {
            throw new BusinessException(
                    "Day close must be in SUBMITTED status to reject, current: " + dayClose.getStatus(),
                    "FS_DAY_CLOSE_NOT_SUBMITTED", HttpStatus.BAD_REQUEST);
        }

        dayClose.setStatus("REJECTED");
        dayClose.setRejectionReason(reason);

        dayClose = dayCloseRepository.save(dayClose);

        log.info("Rejected day close {} (reason: {}) for org {}", id, reason, orgId);
        return dayClose;
    }

    // =====================================================================
    // Salesman Targets
    // =====================================================================

    /**
     * Creates a new salesman target.
     */
    @Transactional
    public SalesmanTarget createTarget(SalesmanTarget input) {
        UUID orgId = TenantContext.getCurrentOrgId();

        SalesmanTarget target = SalesmanTarget.builder()
                .salespersonId(input.getSalespersonId())
                .periodType(input.getPeriodType() != null ? input.getPeriodType() : "MONTHLY")
                .periodStart(input.getPeriodStart())
                .periodEnd(input.getPeriodEnd())
                .targetType(input.getTargetType())
                .targetValue(input.getTargetValue())
                .achievedValue(BigDecimal.ZERO)
                .achievementPct(BigDecimal.ZERO)
                .incentiveRate(input.getIncentiveRate() != null ? input.getIncentiveRate() : BigDecimal.ZERO)
                .incentiveAmount(BigDecimal.ZERO)
                .build();

        target = salesmanTargetRepository.save(target);

        log.info("Created salesman target {} for salesperson {} (type={}, target={}) for org {}",
                target.getId(), input.getSalespersonId(), input.getTargetType(),
                input.getTargetValue().toPlainString(), orgId);
        return target;
    }

    /**
     * Returns all targets for a specific salesperson.
     */
    @Transactional(readOnly = true)
    public List<SalesmanTarget> getTargets(UUID salespersonId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return salesmanTargetRepository.findByOrgIdAndSalespersonIdAndIsDeletedFalse(orgId, salespersonId);
    }

    /**
     * Updates the achieved value on a target and recalculates achievement
     * percentage and incentive amount.
     */
    @Transactional
    public SalesmanTarget updateAchievement(UUID targetId, BigDecimal achievedValue) {
        UUID orgId = TenantContext.getCurrentOrgId();

        SalesmanTarget target = salesmanTargetRepository.findById(targetId)
                .filter(t -> t.getOrgId().equals(orgId) && !t.isDeleted())
                .orElseThrow(() -> BusinessException.notFound("SalesmanTarget", targetId));

        target.setAchievedValue(achievedValue);

        // Recalculate achievement percentage
        if (target.getTargetValue().compareTo(BigDecimal.ZERO) > 0) {
            BigDecimal pct = achievedValue
                    .multiply(new BigDecimal("100"))
                    .divide(target.getTargetValue(), 2, RoundingMode.HALF_UP);
            target.setAchievementPct(pct);
        } else {
            target.setAchievementPct(BigDecimal.ZERO);
        }

        // Recalculate incentive amount = achievedValue * incentiveRate / 100
        if (target.getIncentiveRate().compareTo(BigDecimal.ZERO) > 0) {
            BigDecimal incentive = achievedValue
                    .multiply(target.getIncentiveRate())
                    .divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
            target.setIncentiveAmount(incentive);
        } else {
            target.setIncentiveAmount(BigDecimal.ZERO);
        }

        target = salesmanTargetRepository.save(target);

        log.info("Updated target {} achievement to {} ({}%) for org {}",
                targetId, achievedValue.toPlainString(),
                target.getAchievementPct().toPlainString(), orgId);
        return target;
    }

    /**
     * Paginated list of all targets for the current org.
     */
    @Transactional(readOnly = true)
    public Page<SalesmanTarget> listAllTargets(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return salesmanTargetRepository.findByOrgIdAndIsDeletedFalse(orgId, pageable);
    }

    // =====================================================================
    // Secondary Sales Dashboard
    // =====================================================================

    /**
     * Returns a dashboard summary map with aggregate metrics for a date range:
     * totalSalespersons, totalRoutes, totalVisitsPlanned, totalVisitsCompleted,
     * totalOrdersValue, totalCollections, averageOrderValue, productiveVisitPct.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getSecondaryDashboard(LocalDate from, LocalDate to) {
        UUID orgId = TenantContext.getCurrentOrgId();

        // Active salespersons = distinct salesperson IDs with active assignments
        List<FieldSalesAssignment> activeAssignments = assignmentRepository
                .findByOrgIdAndIsActiveTrue(orgId);
        long totalSalespersons = activeAssignments.stream()
                .map(FieldSalesAssignment::getSalespersonId)
                .distinct()
                .count();

        // Active routes
        long totalRoutes = routeRepository
                .findByOrgIdAndIsActiveTrueAndIsDeletedFalse(orgId).size();

        // Aggregate from route executions in date range
        long totalVisitsPlanned = 0;
        long totalVisitsCompleted = 0;
        BigDecimal totalOrdersValue = BigDecimal.ZERO;
        BigDecimal totalCollections = BigDecimal.ZERO;

        // Iterate over each date in range to collect executions
        LocalDate current = from;
        List<RouteExecution> allExecutions = new ArrayList<>();
        while (!current.isAfter(to)) {
            List<RouteExecution> dayExecutions = routeExecutionRepository
                    .findByOrgIdAndExecutionDateAndIsDeletedFalse(orgId, current);
            allExecutions.addAll(dayExecutions);
            current = current.plusDays(1);
        }

        for (RouteExecution exec : allExecutions) {
            totalVisitsPlanned += exec.getPlannedVisits();
            totalVisitsCompleted += exec.getCompletedVisits();
            totalOrdersValue = totalOrdersValue.add(
                    exec.getTotalOrdersValue() != null ? exec.getTotalOrdersValue() : BigDecimal.ZERO);
            totalCollections = totalCollections.add(
                    exec.getTotalCollections() != null ? exec.getTotalCollections() : BigDecimal.ZERO);
        }

        // Derived metrics
        BigDecimal averageOrderValue = BigDecimal.ZERO;
        if (totalVisitsCompleted > 0 && totalOrdersValue.compareTo(BigDecimal.ZERO) > 0) {
            averageOrderValue = totalOrdersValue.divide(
                    BigDecimal.valueOf(totalVisitsCompleted), 2, RoundingMode.HALF_UP);
        }

        BigDecimal productiveVisitPct = BigDecimal.ZERO;
        if (totalVisitsPlanned > 0) {
            productiveVisitPct = BigDecimal.valueOf(totalVisitsCompleted)
                    .multiply(new BigDecimal("100"))
                    .divide(BigDecimal.valueOf(totalVisitsPlanned), 2, RoundingMode.HALF_UP);
        }

        Map<String, Object> dashboard = new LinkedHashMap<>();
        dashboard.put("totalSalespersons", totalSalespersons);
        dashboard.put("totalRoutes", totalRoutes);
        dashboard.put("totalVisitsPlanned", totalVisitsPlanned);
        dashboard.put("totalVisitsCompleted", totalVisitsCompleted);
        dashboard.put("totalOrdersValue", totalOrdersValue);
        dashboard.put("totalCollections", totalCollections);
        dashboard.put("averageOrderValue", averageOrderValue);
        dashboard.put("productiveVisitPct", productiveVisitPct);

        return dashboard;
    }
}
