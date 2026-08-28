package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.ar.dto.CustomerReceiptRequest;
import com.katasticho.erp.ar.dto.CustomerReceiptResponse;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.CustomerReceiptService;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.expense.repository.ExpenseRepository;
import com.katasticho.erp.fieldsales.dto.BeatCustomerAssignmentRequest;
import com.katasticho.erp.fieldsales.dto.BeatCustomerResponse;
import com.katasticho.erp.fieldsales.dto.RouteBeatCountProjection;
import com.katasticho.erp.fieldsales.dto.RouteBeatResponse;
import com.katasticho.erp.fieldsales.dto.RouteSummaryResponse;
import com.katasticho.erp.fieldsales.entity.*;
import com.katasticho.erp.fieldsales.repository.*;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.entity.StockMovement;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
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
    private final ContactRepository contactRepository;
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
    private final SalesOrderRepository salesOrderRepository;
    private final InvoiceRepository invoiceRepository;
    private final CustomerReceiptService customerReceiptService;
    private final ExpenseRepository expenseRepository;
    private final OrgSettingsService orgSettingsService;
    private final AppUserRepository appUserRepository;
    private final com.katasticho.erp.fieldsales.repository.FieldSalesExecutionAuditRepository executionAuditRepository;

    // =====================================================================
    // Beat Management
    // =====================================================================

    /**
     * Creates a new beat. Validates code uniqueness within the org.
     */
    @Transactional
    public Beat createBeat(Beat input) {
        return createBeat(input, List.of());
    }

    /**
     * Creates a beat and its customer plan atomically. A failed customer
     * validation rolls back the beat as well, so no empty territory is left
     * behind by a partially completed setup.
     */
    @Transactional
    public Beat createBeat(Beat input, List<BeatCustomerAssignmentRequest> customerAssignments) {
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
        replaceBeatCustomers(orgId, beat.getId(), customerAssignments);
        log.info("Created beat {} (code={}) for org {}", beat.getId(), input.getCode(), orgId);
        return beat;
    }

    /**
     * Updates an existing beat. Finds by id or throws 404.
     */
    @Transactional
    public Beat updateBeat(UUID id, Beat input) {
        return updateBeat(id, input, null);
    }

    /**
     * Updates beat details and, when supplied, replaces the active customer
     * plan in the same transaction. A null plan intentionally means "leave
     * assignments unchanged" for backwards-compatible API callers.
     */
    @Transactional
    public Beat updateBeat(UUID id, Beat input,
                           List<BeatCustomerAssignmentRequest> customerAssignments) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Beat beat = beatRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Beat", id));

        beat.setName(input.getName());
        beat.setArea(input.getArea());
        beat.setCity(input.getCity());
        beat.setState(input.getState());
        beat.setDescription(input.getDescription());

        beat = beatRepository.save(beat);
        if (customerAssignments != null) {
            replaceBeatCustomers(orgId, beat.getId(), customerAssignments);
        }
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

        validateCustomerAssignments(orgId, List.of(
                new BeatCustomerAssignmentRequest(contactId, visitSequence, visitFrequency)));

        Optional<BeatCustomer> existing = beatCustomerRepository
                .findFirstByOrgIdAndBeatIdAndContactId(orgId, beatId, contactId);
        if (existing.isPresent() && existing.get().isActive()) {
            throw new BusinessException(
                    "Contact " + contactId + " is already assigned to beat " + beatId,
                    "FS_BEAT_CUSTOMER_DUPLICATE", HttpStatus.CONFLICT);
        }

        BeatCustomer beatCustomer = existing.orElseGet(() -> BeatCustomer.builder()
                .orgId(orgId)
                .beatId(beatId)
                .contactId(contactId)
                .build());
        beatCustomer.setVisitSequence(visitSequence);
        beatCustomer.setVisitFrequency(normalizeVisitFrequency(visitFrequency));
        beatCustomer.setActive(true);

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
        beatCustomerRepository.findFirstByOrgIdAndBeatIdAndContactId(orgId, beatId, contactId)
                .ifPresent(assignment -> {
                    assignment.setActive(false);
                    beatCustomerRepository.save(assignment);
                });
        log.info("Removed contact {} from beat {} for org {}", contactId, beatId, orgId);
    }

    /**
     * Returns active customers for a beat.
     */
    @Transactional(readOnly = true)
    public List<BeatCustomerResponse> getBeatCustomers(UUID beatId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<BeatCustomer> assignments = beatCustomerRepository
                .findByOrgIdAndBeatIdAndIsActiveTrue(orgId, beatId);
        if (assignments.isEmpty()) {
            return List.of();
        }

        Map<UUID, Contact> contactsById = contactRepository
                .findByOrgIdAndIsDeletedFalseAndIdIn(orgId, assignments.stream()
                        .map(BeatCustomer::getContactId)
                        .collect(java.util.stream.Collectors.toSet()))
                .stream()
                .collect(java.util.stream.Collectors.toMap(Contact::getId, contact -> contact));

        return assignments.stream()
                .sorted(Comparator.comparing(BeatCustomer::getVisitSequence,
                        Comparator.nullsLast(Comparator.naturalOrder())))
                .map(assignment -> {
                    Contact contact = contactsById.get(assignment.getContactId());
                    return new BeatCustomerResponse(
                            assignment.getId(),
                            assignment.getBeatId(),
                            assignment.getContactId(),
                            contact != null ? contact.getDisplayName() : "Unknown customer",
                            contact != null ? contact.getCompanyName() : null,
                            contact != null ? contact.getPhone() : null,
                            assignment.getVisitSequence(),
                            assignment.getVisitFrequency(),
                            assignment.isActive());
                })
                .toList();
    }

    /**
     * Reconciles a beat's active customer assignments without deleting history.
     * Existing selections are reactivated and updated; removed selections become
     * inactive so past route execution records stay attributable.
     */
    private void replaceBeatCustomers(UUID orgId, UUID beatId,
                                      List<BeatCustomerAssignmentRequest> requestedAssignments) {
        List<BeatCustomerAssignmentRequest> assignments = requestedAssignments == null
                ? List.of() : requestedAssignments;
        validateCustomerAssignments(orgId, assignments);

        Map<UUID, BeatCustomer> existingByContact = beatCustomerRepository
                .findByOrgIdAndBeatId(orgId, beatId)
                .stream()
                .collect(java.util.stream.Collectors.toMap(
                        BeatCustomer::getContactId, assignment -> assignment,
                        (first, ignored) -> first));
        Set<UUID> requestedContactIds = new HashSet<>();
        List<BeatCustomer> changes = new ArrayList<>();

        for (int index = 0; index < assignments.size(); index++) {
            BeatCustomerAssignmentRequest request = assignments.get(index);
            requestedContactIds.add(request.contactId());
            BeatCustomer assignment = existingByContact.get(request.contactId());
            if (assignment == null) {
                assignment = BeatCustomer.builder()
                        .orgId(orgId)
                        .beatId(beatId)
                        .contactId(request.contactId())
                        .build();
            }
            assignment.setVisitSequence(
                    request.visitSequence() != null ? request.visitSequence() : index + 1);
            assignment.setVisitFrequency(normalizeVisitFrequency(request.visitFrequency()));
            assignment.setActive(true);
            changes.add(assignment);
        }

        for (BeatCustomer existing : existingByContact.values()) {
            if (!requestedContactIds.contains(existing.getContactId()) && existing.isActive()) {
                existing.setActive(false);
                changes.add(existing);
            }
        }

        if (!changes.isEmpty()) {
            beatCustomerRepository.saveAll(changes);
        }
    }

    /** Ensures a beat can only contain active Customer or Both contacts. */
    private void validateCustomerAssignments(UUID orgId,
                                             List<BeatCustomerAssignmentRequest> assignments) {
        Set<UUID> contactIds = new LinkedHashSet<>();
        for (BeatCustomerAssignmentRequest assignment : assignments) {
            if (assignment == null || assignment.contactId() == null) {
                throw new BusinessException(
                        "Every beat assignment must identify a customer contact",
                        "FS_BEAT_CUSTOMER_REQUIRED", HttpStatus.BAD_REQUEST);
            }
            if (!contactIds.add(assignment.contactId())) {
                throw new BusinessException(
                        "A customer can only be assigned to a beat once",
                        "FS_BEAT_CUSTOMER_DUPLICATE", HttpStatus.CONFLICT);
            }
        }

        if (contactIds.isEmpty()) {
            return;
        }

        Map<UUID, Contact> contactsById = contactRepository
                .findByOrgIdAndIsDeletedFalseAndIdIn(orgId, contactIds)
                .stream()
                .collect(java.util.stream.Collectors.toMap(Contact::getId, contact -> contact));

        for (UUID contactId : contactIds) {
            Contact contact = contactsById.get(contactId);
            if (contact == null) {
                throw BusinessException.notFound("Customer contact", contactId);
            }
            boolean canBeVisited = contact.isActive()
                    && (contact.getContactType() == ContactType.CUSTOMER
                    || contact.getContactType() == ContactType.BOTH);
            if (!canBeVisited) {
                throw new BusinessException(
                        "Only active customer contacts can be assigned to a beat",
                        "FS_BEAT_CONTACT_NOT_CUSTOMER", HttpStatus.BAD_REQUEST);
            }
        }
    }

    private String normalizeVisitFrequency(String visitFrequency) {
        return visitFrequency == null || visitFrequency.isBlank()
                ? "WEEKLY" : visitFrequency.trim().toUpperCase(Locale.ROOT);
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

        List<UUID> validatedBeatIds = validateRouteBeatIds(orgId, beatIds);

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
        if (!validatedBeatIds.isEmpty()) {
            createRouteBeats(orgId, route.getId(), validatedBeatIds);
        }

        log.info("Created route {} (code={}) with {} beats for org {}",
                route.getId(), input.getCode(), validatedBeatIds.size(), orgId);
        return route;
    }

    @Transactional
    public Route updateRoute(UUID id, Route input) {
        return updateRoute(id, input, null);
    }

    /**
     * Updates route details and, when supplied, replaces its ordered beat plan in
     * the same transaction. Null preserves the plan for backwards-compatible API
     * callers; an empty list intentionally clears the plan.
     */
    @Transactional
    public Route updateRoute(UUID id, Route input, List<UUID> beatIds) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Route route = routeRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Route", id));

        route.setName(input.getName());
        route.setDayOfWeek(input.getDayOfWeek());
        route.setFrequency(input.getFrequency() != null ? input.getFrequency() : route.getFrequency());
        route.setWarehouseId(input.getWarehouseId());

        if (beatIds != null) {
            replaceRouteBeats(orgId, route.getId(), beatIds);
        }

        route = routeRepository.save(route);
        log.info("Updated route {} for org {}", id, orgId);
        return route;
    }

    /**
     * Paginated list of routes for the current org.
     */
    @Transactional(readOnly = true)
    public Page<RouteSummaryResponse> listRoutes(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Page<Route> routes = routeRepository.findByOrgIdAndIsDeletedFalse(orgId, pageable);
        if (!routes.hasContent()) {
            return routes.map(route -> toRouteSummary(route, 0));
        }

        List<UUID> routeIds = routes.getContent().stream().map(Route::getId).toList();
        Map<UUID, Long> beatCounts = routeBeatRepository
                .countByOrgIdAndRouteIdIn(orgId, routeIds)
                .stream()
                .collect(java.util.stream.Collectors.toMap(
                        RouteBeatCountProjection::getRouteId,
                        RouteBeatCountProjection::getBeatCount));

        return routes.map(route -> toRouteSummary(
                route, beatCounts.getOrDefault(route.getId(), 0L)));
    }

    private RouteSummaryResponse toRouteSummary(Route route, long beatCount) {
        return new RouteSummaryResponse(
                route.getId(),
                route.getCode(),
                route.getName(),
                route.getDayOfWeek(),
                route.getFrequency(),
                route.getWarehouseId(),
                route.getEstimatedDistanceKm(),
                route.getEstimatedDurationMinutes(),
                route.isActive(),
                beatCount);
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
    public List<RouteBeatResponse> getRouteBeats(UUID routeId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<RouteBeat> routeBeats =
                routeBeatRepository.findByOrgIdAndRouteIdOrderBySequenceNumber(orgId, routeId);
        if (routeBeats.isEmpty()) {
            return List.of();
        }

        Set<UUID> beatIds = routeBeats.stream()
                .map(RouteBeat::getBeatId)
                .collect(java.util.stream.Collectors.toSet());
        Map<UUID, Beat> beatsById = beatRepository
                .findByOrgIdAndIsDeletedFalseAndIdIn(orgId, beatIds)
                .stream()
                .collect(java.util.stream.Collectors.toMap(Beat::getId, beat -> beat));

        return routeBeats.stream()
                .map(routeBeat -> {
                    Beat beat = beatsById.get(routeBeat.getBeatId());
                    return new RouteBeatResponse(
                            routeBeat.getId(),
                            routeBeat.getRouteId(),
                            routeBeat.getBeatId(),
                            beat != null ? beat.getCode() : null,
                            beat != null ? beat.getName() : "Unavailable beat",
                            beat != null ? beat.getArea() : null,
                            beat != null ? beat.getCity() : null,
                            routeBeat.getSequenceNumber());
                })
                .toList();
    }

    /** Validates the full proposed route plan before any existing plan is removed. */
    private List<UUID> validateRouteBeatIds(UUID orgId, List<UUID> beatIds) {
        if (beatIds == null || beatIds.isEmpty()) {
            return List.of();
        }

        LinkedHashSet<UUID> uniqueBeatIds = new LinkedHashSet<>(beatIds);
        if (uniqueBeatIds.size() != beatIds.size()) {
            throw new BusinessException(
                    "A beat can only appear once in a route plan",
                    "FS_ROUTE_DUPLICATE_BEAT",
                    HttpStatus.BAD_REQUEST);
        }

        int activeBeatCount = beatRepository
                .findByOrgIdAndIsActiveTrueAndIsDeletedFalseAndIdIn(orgId, uniqueBeatIds)
                .size();
        if (activeBeatCount != uniqueBeatIds.size()) {
            throw new BusinessException(
                    "Every route stop must be an active beat in this organisation",
                    "FS_ROUTE_INVALID_BEAT",
                    HttpStatus.BAD_REQUEST);
        }
        return List.copyOf(uniqueBeatIds);
    }

    private void replaceRouteBeats(UUID orgId, UUID routeId, List<UUID> beatIds) {
        List<UUID> validatedBeatIds = validateRouteBeatIds(orgId, beatIds);
        routeBeatRepository.deleteByOrgIdAndRouteId(orgId, routeId);
        if (!validatedBeatIds.isEmpty()) {
            createRouteBeats(orgId, routeId, validatedBeatIds);
        }
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

    private void validateSalespersonActive(UUID orgId, UUID salespersonId) {
        if (salespersonId == null) {
            throw new BusinessException("Salesperson ID is required", "FS_SALESPERSON_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        AppUser user = appUserRepository.findByIdAndOrgIdAndIsDeletedFalse(salespersonId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Salesperson user", salespersonId));
        if (!user.isActive()) {
            throw new BusinessException("Salesperson user is inactive", "FS_SALESPERSON_INACTIVE", HttpStatus.BAD_REQUEST);
        }
    }

    private void validateNoAssignmentOverlap(UUID orgId, UUID salespersonId, UUID routeId,
                                             LocalDate from, LocalDate to, UUID currentAssignmentId) {
        if (routeId == null) return;
        List<FieldSalesAssignment> existing = assignmentRepository
                .findByOrgIdAndSalespersonIdAndRouteIdAndIsActiveTrue(orgId, salespersonId, routeId);

        LocalDate effectiveTo = to != null ? to : LocalDate.MAX;
        for (FieldSalesAssignment a : existing) {
            if (currentAssignmentId != null && currentAssignmentId.equals(a.getId())) {
                continue;
            }
            LocalDate existFrom = a.getEffectiveFrom();
            LocalDate existTo = a.getEffectiveTo() != null ? a.getEffectiveTo() : LocalDate.MAX;

            // Overlap condition: from <= existTo && existFrom <= to
            if (!from.isAfter(existTo) && !existFrom.isAfter(effectiveTo)) {
                throw new BusinessException(
                        "An active assignment for this salesperson and route already exists in date range " +
                                existFrom + " to " + (a.getEffectiveTo() != null ? a.getEffectiveTo() : "ongoing"),
                        "FS_ASSIGNMENT_OVERLAP", HttpStatus.CONFLICT);
            }
        }
    }

    /**
     * Creates a new field sales assignment with strict entity, membership, and overlap validation.
     */
    @Transactional
    public FieldSalesAssignment createAssignment(FieldSalesAssignment input) {
        UUID orgId = TenantContext.getCurrentOrgId();

        validateSalespersonActive(orgId, input.getSalespersonId());

        if (input.getEffectiveFrom() == null) {
            throw new BusinessException("Effective From date is required", "FS_EFFECTIVE_FROM_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        if (input.getEffectiveTo() != null && input.getEffectiveTo().isBefore(input.getEffectiveFrom())) {
            throw new BusinessException("Effective To date cannot be before Effective From date", "FS_INVALID_EFFECTIVE_DATES", HttpStatus.BAD_REQUEST);
        }
        if (input.getRouteId() != null) {
            routeRepository.findByIdAndOrgIdAndIsDeletedFalse(input.getRouteId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("Route", input.getRouteId()));
            if (input.isActive()) {
                validateNoAssignmentOverlap(orgId, input.getSalespersonId(), input.getRouteId(),
                        input.getEffectiveFrom(), input.getEffectiveTo(), null);
            }
        }
        if (input.getVanId() != null) {
            vanRepository.findByIdAndOrgIdAndIsDeletedFalse(input.getVanId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("Van", input.getVanId()));
        }

        FieldSalesAssignment assignment = FieldSalesAssignment.builder()
                .orgId(orgId)
                .salespersonId(input.getSalespersonId())
                .routeId(input.getRouteId())
                .vanId(input.getVanId())
                .territory(input.getTerritory())
                .effectiveFrom(input.getEffectiveFrom())
                .effectiveTo(input.getEffectiveTo())
                .isActive(input.isActive())
                .build();

        assignment = assignmentRepository.save(assignment);
        log.info("Created field sales assignment {} for salesperson {} on route {} for org {}",
                assignment.getId(), input.getSalespersonId(), input.getRouteId(), orgId);
        return assignment;
    }

    /**
     * Updates an existing field sales assignment with membership and overlap validation.
     */
    @Transactional
    public FieldSalesAssignment updateAssignment(UUID id, FieldSalesAssignment input) {
        UUID orgId = TenantContext.getCurrentOrgId();
        FieldSalesAssignment existing = assignmentRepository.findByIdAndOrgId(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("FieldSalesAssignment", id));

        UUID salespersonId = input.getSalespersonId() != null ? input.getSalespersonId() : existing.getSalespersonId();
        validateSalespersonActive(orgId, salespersonId);

        LocalDate effectiveFrom = input.getEffectiveFrom() != null ? input.getEffectiveFrom() : existing.getEffectiveFrom();
        LocalDate effectiveTo = input.getEffectiveTo();

        if (effectiveTo != null && effectiveTo.isBefore(effectiveFrom)) {
            throw new BusinessException("Effective To date cannot be before Effective From date", "FS_INVALID_EFFECTIVE_DATES", HttpStatus.BAD_REQUEST);
        }

        UUID routeId = input.getRouteId() != null ? input.getRouteId() : existing.getRouteId();
        if (routeId != null) {
            routeRepository.findByIdAndOrgIdAndIsDeletedFalse(routeId, orgId)
                    .orElseThrow(() -> BusinessException.notFound("Route", routeId));
            if (existing.isActive()) {
                validateNoAssignmentOverlap(orgId, salespersonId, routeId, effectiveFrom, effectiveTo, id);
            }
            existing.setRouteId(routeId);
        }

        if (input.getVanId() != null) {
            vanRepository.findByIdAndOrgIdAndIsDeletedFalse(input.getVanId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("Van", input.getVanId()));
            existing.setVanId(input.getVanId());
        }

        existing.setSalespersonId(salespersonId);
        if (input.getTerritory() != null) {
            existing.setTerritory(input.getTerritory());
        }
        existing.setEffectiveFrom(effectiveFrom);
        existing.setEffectiveTo(effectiveTo);
        // isActive is intentionally NOT updated here.
        // Use POST /assignments/{id}/end to end, DELETE /assignments/{id} to deactivate.

        existing = assignmentRepository.save(existing);
        log.info("Updated field sales assignment {} for org {}", id, orgId);
        return existing;
    }

    /**
     * Ends an assignment as of a given date (defaults to today).
     */
    @Transactional
    public FieldSalesAssignment endAssignment(UUID id, LocalDate endDate) {
        UUID orgId = TenantContext.getCurrentOrgId();
        FieldSalesAssignment existing = assignmentRepository.findByIdAndOrgId(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("FieldSalesAssignment", id));

        LocalDate finalEndDate = endDate != null ? endDate : LocalDate.now();
        if (existing.getEffectiveFrom() != null && finalEndDate.isBefore(existing.getEffectiveFrom())) {
            throw new BusinessException("Effective To date cannot be before Effective From date",
                    "FS_INVALID_EFFECTIVE_DATES", HttpStatus.BAD_REQUEST);
        }
        existing.setEffectiveTo(finalEndDate);
        existing.setActive(false);
        existing = assignmentRepository.save(existing);
        log.info("Ended field sales assignment {} as of {} for org {}", id, finalEndDate, orgId);
        return existing;
    }

    /**
     * Deactivates a field sales assignment (does not hard delete).
     */
    @Transactional
    public void deleteAssignment(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        FieldSalesAssignment existing = assignmentRepository.findByIdAndOrgId(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("FieldSalesAssignment", id));
        existing.setActive(false);
        if (existing.getEffectiveTo() == null || existing.getEffectiveTo().isAfter(LocalDate.now())) {
            existing.setEffectiveTo(LocalDate.now());
        }
        assignmentRepository.save(existing);
        log.info("Deactivated field sales assignment {} for org {}", id, orgId);
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
     * Returns active assignments for the currently logged-in user with optional date filter.
     */
    @Transactional(readOnly = true)
    public List<FieldSalesAssignment> getMyAssignments(UUID userId, LocalDate effectiveOn) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (effectiveOn != null) {
            return assignmentRepository.findActiveAssignmentsForSalespersonOnDate(orgId, userId, effectiveOn);
        }
        return assignmentRepository.findByOrgIdAndSalespersonIdAndIsActiveTrue(orgId, userId);
    }

    /**
     * Returns all active assignments for the current org.
     */
    @Transactional(readOnly = true)
    public List<FieldSalesAssignment> getAllAssignments() {
        return getAllAssignments(false, null);
    }

    /**
     * Returns assignments with optional filtering by inactive inclusion or effective date.
     */
    @Transactional(readOnly = true)
    public List<FieldSalesAssignment> getAllAssignments(boolean includeInactive, LocalDate effectiveOn) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (effectiveOn != null) {
            return assignmentRepository.findActiveAssignmentsOnDate(orgId, effectiveOn);
        }
        if (includeInactive) {
            return assignmentRepository.findByOrgId(orgId);
        }
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

        // Pessimistic lock so a concurrent double-confirm can't both pass the DRAFT
        // check and post duplicate stock movements / double van credit.
        VanStockTransfer transfer = vanStockTransferRepository
                .findByIdAndOrgIdForUpdate(transferId, orgId)
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
            // Deduct warehouse stock via InventoryService. The returned movement
            // carries the TRUE (FIFO/weighted-avg) unit cost the goods left the
            // warehouse at ï¿½ stamp it on the van so the return leg re-opens the
            // warehouse lot at the same basis (value-neutral round-trip).
            StockMovement outMovement = inventoryService.recordMovement(new StockMovementRequest(
                    line.getItemId(),
                    transfer.getWarehouseId(),
                    MovementType.TRANSFER_OUT,
                    line.getQuantity().negate(),  // negative = stock out
                    null,                         // unitCost ï¿½ resolved by the gate
                    transfer.getTransferDate(),
                    ReferenceType.VAN_LOAD,
                    transfer.getId(),
                    "VAN-LOAD-" + transfer.getId().toString().substring(0, 8),
                    "Van load to van " + transfer.getVanId(),
                    line.getBatchId()
            ));

            // Add to van stock balance, carrying the recorded load cost.
            BigDecimal loadCost = outMovement != null ? outMovement.getUnitCost() : null;
            adjustVanStockBalance(orgId, transfer.getVanId(), line.getItemId(),
                    line.getBatchId(), line.getQuantity(), loadCost);
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

        // Pessimistic lock so a concurrent double-confirm can't both post the
        // TRANSFER_IN and double-credit the warehouse.
        VanStockTransfer transfer = vanStockTransferRepository
                .findByIdAndOrgIdForUpdate(transferId, orgId)
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
            // Read the cost the goods carried on the van BEFORE deducting, so the
            // warehouse lot re-opens at the load-leg basis (a pure custody move must
            // not mint/destroy inventory value). Null ? gate falls back to
            // item.purchasePrice (legacy behaviour for un-costed vans).
            BigDecimal returnCost = (line.getBatchId() != null
                    ? vanStockBalanceRepository.findByOrgIdAndVanIdAndItemIdAndBatchId(
                            orgId, transfer.getVanId(), line.getItemId(), line.getBatchId())
                    : vanStockBalanceRepository.findByOrgIdAndVanIdAndItemIdAndBatchIdIsNull(
                            orgId, transfer.getVanId(), line.getItemId()))
                    .map(VanStockBalance::getAverageCost).orElse(null);

            // Deduct from van stock balance
            adjustVanStockBalance(orgId, transfer.getVanId(), line.getItemId(),
                    line.getBatchId(), line.getQuantity().negate());

            // Add warehouse stock via InventoryService at the van's carried cost
            inventoryService.recordMovement(new StockMovementRequest(
                    line.getItemId(),
                    transfer.getWarehouseId(),
                    MovementType.TRANSFER_IN,
                    line.getQuantity(),           // positive = stock in
                    returnCost,                   // load-leg cost (null ? purchasePrice)
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
        adjustVanStockBalance(orgId, vanId, itemId, batchId, delta, null);
    }

    /**
     * Adjusts a van_stock_balance row and maintains its weighted-average cost.
     * On a positive delta (load) with a supplied {@code unitCost}, averageCost is
     * blended so the van tracks what the goods cost when loaded; on a negative
     * delta (return/unload) averageCost is left unchanged (it is the cost of what
     * remains). The null-batch path targets ONLY the null-batch grain so a
     * batch-less line can never match ï¿½ or crash against ï¿½ batched rows.
     */
    private void adjustVanStockBalance(UUID orgId, UUID vanId, UUID itemId,
                                        UUID batchId, BigDecimal delta, BigDecimal unitCost) {
        Optional<VanStockBalance> existing = batchId != null
                ? vanStockBalanceRepository.findByOrgIdAndVanIdAndItemIdAndBatchId(orgId, vanId, itemId, batchId)
                : vanStockBalanceRepository.findByOrgIdAndVanIdAndItemIdAndBatchIdIsNull(orgId, vanId, itemId);

        if (existing.isPresent()) {
            VanStockBalance balance = existing.get();
            BigDecimal newQty = balance.getQuantityOnHand().add(delta);
            // Blend the average cost only when adding costed stock.
            if (delta.signum() > 0 && unitCost != null) {
                BigDecimal existingQty = balance.getQuantityOnHand().max(BigDecimal.ZERO);
                BigDecimal existingCost = balance.getAverageCost() != null
                        ? balance.getAverageCost() : unitCost;
                BigDecimal totalQty = existingQty.add(delta);
                if (totalQty.signum() > 0) {
                    balance.setAverageCost(existingQty.multiply(existingCost).add(delta.multiply(unitCost))
                            .divide(totalQty, 4, RoundingMode.HALF_UP));
                }
            }
            balance.setQuantityOnHand(newQty);
            balance.setLastMovementAt(Instant.now());
            vanStockBalanceRepository.save(balance);
        } else {
            VanStockBalance balance = VanStockBalance.builder()
                    .orgId(orgId)
                    .vanId(vanId)
                    .itemId(itemId)
                    .batchId(batchId)
                    .quantityOnHand(delta)
                    .averageCost(delta.signum() > 0 ? unitCost : null)
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
        Optional<VanStockBalance> existing = batchId != null
                ? vanStockBalanceRepository.findByOrgIdAndVanIdAndItemIdAndBatchId(orgId, vanId, itemId, batchId)
                : vanStockBalanceRepository.findByOrgIdAndVanIdAndItemIdAndBatchIdIsNull(orgId, vanId, itemId);

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
        return startExecution(routeId, salespersonId, vanId, executionDate, null);
    }

    @Transactional
    public RouteExecution startExecution(UUID routeId, UUID salespersonId,
                                         UUID vanId, LocalDate executionDate,
                                         String overrideReason) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID currentUserId = TenantContext.getCurrentUserId();
        boolean isAdmin = isFieldAdmin();

        // A non-admin may only start an execution for themselves; admins legitimately
        // plan for others.
        if (!isAdmin && !salespersonId.equals(currentUserId)) {
            throw new BusinessException(
                    "Only the assigned salesperson can start this execution",
                    "FS_NOT_ASSIGNED_SALESPERSON", HttpStatus.FORBIDDEN);
        }

        Route route = routeRepository.findByIdAndOrgIdAndIsDeletedFalse(routeId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Route", routeId));

        // Always validate salesperson org-membership and active status, even for admin overrides.
        validateSalespersonActive(orgId, salespersonId);

        // Enforce that salesperson has an active assignment for this route on executionDate
        List<FieldSalesAssignment> activeAssignments = assignmentRepository
                .findActiveAssignmentsForSalespersonAndRouteOnDate(orgId, salespersonId, routeId, executionDate);

        String executionNotes = null;
        UUID finalVanId = vanId;
        String overrideType = null;   // ROUTE_UNASSIGNED | VAN_MISMATCH

        if (activeAssignments.isEmpty()) {
            if (!isAdmin) {
                throw new BusinessException(
                        "Salesperson is not actively assigned to route '" + route.getName() + "' on " + executionDate,
                        "FS_NO_ACTIVE_ASSIGNMENT", HttpStatus.BAD_REQUEST);
            }
            if (overrideReason == null || overrideReason.trim().isEmpty()) {
                throw new BusinessException(
                        "Admin override reason is required to start an execution without an active route assignment",
                        "FS_OVERRIDE_REASON_REQUIRED", HttpStatus.BAD_REQUEST);
            }
            overrideType = "ROUTE_UNASSIGNED";
            executionNotes = "[ADMIN OVERRIDE]: " + overrideReason.trim();
            log.warn("Admin {} created unassigned route execution for salesperson {} on route {} with reason: {}",
                    currentUserId, salespersonId, routeId, overrideReason.trim());
        } else {
            // Assignment exists — validate van match
            UUID assignedVanId = activeAssignments.get(0).getVanId();
            if (assignedVanId != null) {
                if (finalVanId == null) {
                    finalVanId = assignedVanId;
                } else if (!finalVanId.equals(assignedVanId)) {
                    if (!isAdmin) {
                        throw new BusinessException(
                                "Selected van does not match the assigned van for this route",
                                "FS_VAN_MISMATCH", HttpStatus.BAD_REQUEST);
                    }
                    if (overrideReason == null || overrideReason.trim().isEmpty()) {
                        throw new BusinessException(
                                "Admin override reason is required to override the assigned van for this route",
                                "FS_OVERRIDE_REASON_REQUIRED", HttpStatus.BAD_REQUEST);
                    }
                    overrideType = "VAN_MISMATCH";
                    executionNotes = "[ADMIN VAN OVERRIDE]: " + overrideReason.trim();
                    log.warn("Admin {} overrode assigned van for salesperson {} on route {} with reason: {}",
                            currentUserId, salespersonId, routeId, overrideReason.trim());
                }
            }
        }

        // Validate van existence if specified
        final UUID resolvedVanId = finalVanId;
        if (resolvedVanId != null) {
            vanRepository.findByIdAndOrgIdAndIsDeletedFalse(resolvedVanId, orgId)
                    .orElseThrow(() -> BusinessException.notFound("Van", resolvedVanId));
        }

        // Create route execution
        RouteExecution execution = RouteExecution.builder()
                .routeId(routeId)
                .salespersonId(salespersonId)
                .vanId(finalVanId)
                .executionDate(executionDate)
                .status("PLANNED")
                .plannedVisits(0)
                .completedVisits(0)
                .skippedVisits(0)
                .totalOrdersValue(BigDecimal.ZERO)
                .totalCollections(BigDecimal.ZERO)
                .notes(executionNotes)
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

        // Write structured, immutable audit record for any admin override (P2).
        if (overrideType != null && overrideReason != null) {
            final UUID capturedFinalVanId = finalVanId;
            executionAuditRepository.save(
                com.katasticho.erp.fieldsales.entity.FieldSalesExecutionAudit.builder()
                    .orgId(orgId)
                    .executionId(execution.getId())
                    .actorId(currentUserId)
                    .salespersonId(salespersonId)
                    .routeId(routeId)
                    .vanId(capturedFinalVanId)
                    .executionDate(executionDate)
                    .overrideType(overrideType)
                    .overrideReason(overrideReason.trim())
                    .build());
        }

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
        ensureExecutionOwnership(execution);

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
        ensureExecutionOwnership(execution);

        if (!"IN_PROGRESS".equals(execution.getStatus())) {
            throw new BusinessException(
                    "Route execution must be IN_PROGRESS to complete, current: " + execution.getStatus(),
                    "FS_EXECUTION_NOT_IN_PROGRESS", HttpStatus.BAD_REQUEST);
        }

        // A route cannot be closed while a planned visit is silently left open.
        List<FieldVisit> visits = fieldVisitRepository
                .findByOrgIdAndRouteExecutionIdAndIsDeletedFalseOrderBySequenceNumber(orgId, executionId);
        long openVisits = visits.stream()
                .filter(visit -> !Set.of("COMPLETED", "SKIPPED").contains(visit.getStatus()))
                .count();
        if (openVisits > 0) {
            throw new BusinessException(
                    "Complete or skip all visits before closing the route (open: " + openVisits + ")",
                    "FS_VISITS_NOT_CLOSED", HttpStatus.BAD_REQUEST);
        }

        int completedVisits = 0;
        int skippedVisits = 0;
        BigDecimal totalOrdersValue = BigDecimal.ZERO;
        BigDecimal cashCollections = BigDecimal.ZERO;
        BigDecimal totalCollections = BigDecimal.ZERO;

        for (FieldVisit visit : visits) {
            if ("COMPLETED".equals(visit.getStatus())) {
                completedVisits++;
            } else if ("SKIPPED".equals(visit.getStatus())) {
                skippedVisits++;
            }
            totalOrdersValue = totalOrdersValue.add(
                    visit.getOrderValue() != null ? visit.getOrderValue() : BigDecimal.ZERO);
            BigDecimal visitCollection = visit.getCollectionAmount() != null
                    ? visit.getCollectionAmount() : BigDecimal.ZERO;
            totalCollections = totalCollections.add(visitCollection);
            if (visit.getCollectionPaymentMethod() == null
                    || "CASH".equals(visit.getCollectionPaymentMethod())) {
                cashCollections = cashCollections.add(visitCollection);
            }
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
        applyGeofence(visit, orgId, latitude, longitude);

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

        // salesOrderId is optional ï¿½ quick-amount orders from the field app record value only
        if (salesOrderId != null) {
            salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(salesOrderId, orgId)
                    .orElseThrow(() -> BusinessException.notFound("SalesOrder", salesOrderId));
            visit.setSalesOrderId(salesOrderId);
        }
        visit.setOrderValue(orderValue != null ? orderValue : BigDecimal.ZERO);

        visit = fieldVisitRepository.save(visit);
        log.info("Recorded order {} (value={}) on visit {} for org {}",
                salesOrderId, orderValue, visitId, orgId);
        return visit;
    }

    /**
     * Records a cash collection on a visit for legacy callers.
     */
    @Transactional
    public FieldVisit recordVisitCollection(UUID visitId, BigDecimal collectionAmount) {
        return recordVisitCollection(visitId, collectionAmount, "CASH");
    }

    /**
     * Records the collection amount and payment channel on a visit.
     */
    @Transactional
    public FieldVisit recordVisitCollection(UUID visitId, BigDecimal collectionAmount,
                                             String paymentMethod) {
        UUID orgId = TenantContext.getCurrentOrgId();

        FieldVisit visit = fieldVisitRepository.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId)
                .orElseThrow(() -> BusinessException.notFound("FieldVisit", visitId));
        ensureVisitOwnership(visit, orgId);

        visit.setCollectionAmount(collectionAmount != null ? collectionAmount : BigDecimal.ZERO);
        visit.setCollectionPaymentMethod(normalizeCollectionPaymentMethod(paymentMethod));

        visit = fieldVisitRepository.save(visit);
        log.info("Recorded collection {} ({}) on visit {} for org {}",
                collectionAmount, paymentMethod, visitId, orgId);
        return visit;
    }

    /**
     * Records a field collection through the AR receipt engine. The receipt is
     * allocated oldest-invoice-first and any remainder becomes customer
     * advance. The visit link makes retries idempotent.
     */
    @Transactional
    public Map<String, Object> recordVisitCollectionWithReceipt(UUID visitId,
                                                                  BigDecimal collectionAmount,
                                                                  String paymentMethod,
                                                                  String referenceNumber) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (collectionAmount == null || collectionAmount.signum() <= 0) {
            throw new BusinessException("Collection amount must be positive",
                    "FS_COLLECTION_INVALID", HttpStatus.BAD_REQUEST);
        }

        FieldVisit visit = fieldVisitRepository.findByIdAndOrgIdAndIsDeletedFalse(visitId, orgId)
                .orElseThrow(() -> BusinessException.notFound("FieldVisit", visitId));
        ensureVisitOwnership(visit, orgId);

        if (visit.getCustomerReceiptId() != null) {
            CustomerReceiptResponse existing = customerReceiptService
                    .getReceiptResponse(visit.getCustomerReceiptId());
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("visit", visit);
            result.put("receipt", existing);
            result.put("idempotent", true);
            return result;
        }

        String method = normalizeCollectionPaymentMethod(paymentMethod);

        List<Invoice> invoices = invoiceRepository
                .findByOrgIdAndContactIdAndIsDeletedFalseOrderByInvoiceDateDesc(
                        orgId, visit.getContactId(), PageRequest.of(0, 500))
                .getContent().stream()
                .filter(invoice -> invoice.getBalanceDue() != null
                        && invoice.getBalanceDue().signum() > 0)
                .sorted(Comparator.comparing(Invoice::getInvoiceDate))
                .toList();

        BigDecimal remaining = collectionAmount;
        List<CustomerReceiptRequest.AllocationRequest> allocations = new ArrayList<>();
        for (Invoice invoice : invoices) {
            if (remaining.signum() <= 0) break;
            BigDecimal applied = invoice.getBalanceDue().min(remaining);
            if (applied.signum() > 0) {
                allocations.add(new CustomerReceiptRequest.AllocationRequest(
                        invoice.getId(), applied));
                remaining = remaining.subtract(applied);
            }
        }

        CustomerReceiptResponse receipt = customerReceiptService.recordReceipt(
                new CustomerReceiptRequest(
                        visit.getContactId(), collectionAmount, method, LocalDate.now(),
                        referenceNumber,
                        "Field collection for visit " + visitId,
                        null, allocations));

        visit.setCollectionAmount(collectionAmount);
        visit.setCollectionPaymentMethod(method);
        visit.setCustomerReceiptId(receipt.id());
        fieldVisitRepository.save(visit);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("visit", visit);
        result.put("receipt", receipt);
        result.put("idempotent", false);
        result.put("advanceAmount", receipt.advanceAmount());
        return result;
    }

    private String normalizeCollectionPaymentMethod(String paymentMethod) {
        String method = paymentMethod == null || paymentMethod.isBlank()
                ? "CASH" : paymentMethod.trim().toUpperCase(Locale.ROOT);
        if (!Set.of("CASH", "UPI", "BANK_TRANSFER", "CHEQUE", "CARD").contains(method)) {
            throw new BusinessException("Unsupported collection payment method: " + method,
                    "FS_COLLECTION_PAYMENT_METHOD_INVALID", HttpStatus.BAD_REQUEST);
        }
        return method;
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

    /**
     * Geofence verification at check-in: compares the check-in coordinates
     * against the beat customer's stored geo location. Sets geoVerified
     * true/false + distance when both coordinates exist; leaves them null
     * when the customer has no stored location or no GPS was sent.
     * Never blocks the check-in ï¿½ a failed geofence is a flag for review.
     */
    private void applyGeofence(FieldVisit visit, UUID orgId,
                               BigDecimal latitude, BigDecimal longitude) {
        if (visit.getBeatId() == null
                || latitude == null || longitude == null
                || (latitude.signum() == 0 && longitude.signum() == 0)) {
            return;
        }
        beatCustomerRepository
                .findFirstByOrgIdAndBeatIdAndContactId(orgId, visit.getBeatId(), visit.getContactId())
                .ifPresent(bc -> {
                    if (bc.getGeoLatitude() == null || bc.getGeoLongitude() == null) return;
                    double distance = FieldTrackingService.distanceMeters(
                            bc.getGeoLatitude(), bc.getGeoLongitude(), latitude, longitude);
                    double radius = Double.parseDouble(orgSettingsService.get(
                            orgId, "field_sales.geofence_radius_m", "250"));
                    visit.setGeoDistanceM(BigDecimal.valueOf(distance).setScale(2, RoundingMode.HALF_UP));
                    visit.setGeoVerified(distance <= radius);
                    if (distance > radius) {
                        log.warn("Geofence mismatch on visit {}: {}m from customer location (radius {}m)",
                                visit.getId(), Math.round(distance), Math.round(radius));
                    }
                });
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

    private static boolean isFieldAdmin() {
        String role = TenantContext.getCurrentRole();
        return role != null && (role.contains("OWNER") || role.contains("ADMIN"));
    }

    /** OWNER/ADMIN or the execution's assigned salesperson only. */
    private void ensureExecutionOwnership(RouteExecution execution) {
        if (isFieldAdmin()) return;
        if (!execution.getSalespersonId().equals(TenantContext.getCurrentUserId())) {
            throw new BusinessException(
                    "Only the assigned salesperson can perform this action",
                    "FS_NOT_ASSIGNED_SALESPERSON", HttpStatus.FORBIDDEN);
        }
    }

    /** OWNER/ADMIN or the day-close's assigned salesperson only. */
    private void ensureDayCloseOwnership(DayClose dayClose) {
        if (isFieldAdmin()) return;
        if (!dayClose.getSalespersonId().equals(TenantContext.getCurrentUserId())) {
            throw new BusinessException(
                    "Only the assigned salesperson can perform this action",
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
        return initiateDayClose(routeExecutionId, BigDecimal.ZERO);
    }

    @Transactional
    public DayClose initiateDayClose(UUID routeExecutionId, BigDecimal openingCash) {
        UUID orgId = TenantContext.getCurrentOrgId();

        RouteExecution execution = routeExecutionRepository
                .findByIdAndOrgIdAndIsDeletedFalse(routeExecutionId, orgId)
                .orElseThrow(() -> BusinessException.notFound("RouteExecution", routeExecutionId));
        ensureExecutionOwnership(execution);

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

        if (openingCash != null && openingCash.signum() < 0) {
            throw new BusinessException("Opening cash cannot be negative",
                    "FS_OPENING_CASH_INVALID", HttpStatus.BAD_REQUEST);
        }

        // Gather visit summary
        List<FieldVisit> visits = fieldVisitRepository
                .findByOrgIdAndRouteExecutionIdAndIsDeletedFalseOrderBySequenceNumber(orgId, routeExecutionId);

        int visitsPlanned = visits.size();
        int visitsCompleted = 0;
        int visitsProductive = 0;
        BigDecimal totalOrdersValue = BigDecimal.ZERO;
        BigDecimal cashCollections = BigDecimal.ZERO;
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
            BigDecimal visitCollection = visit.getCollectionAmount() != null
                    ? visit.getCollectionAmount() : BigDecimal.ZERO;
            totalCollections = totalCollections.add(visitCollection);
            if (visit.getCollectionPaymentMethod() == null
                    || "CASH".equals(visit.getCollectionPaymentMethod())) {
                cashCollections = cashCollections.add(visitCollection);
            }
        }

        DayClose dayClose = DayClose.builder()
                .routeExecutionId(routeExecutionId)
                .salespersonId(execution.getSalespersonId())
                .vanId(execution.getVanId())
                .closeDate(execution.getExecutionDate())
                .status("PENDING")
                .openingCash(openingCash != null ? openingCash : BigDecimal.ZERO)
                .cashCollections(cashCollections)
                .cashExpenses(Optional.ofNullable(expenseRepository
                        .sumCashTotalByOrgAndCreatedByAndDate(orgId, execution.getSalespersonId(), execution.getExecutionDate()))
                        .orElse(BigDecimal.ZERO))
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
        ensureDayCloseOwnership(dayClose);

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
        BigDecimal cashCollections = BigDecimal.ZERO;
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
