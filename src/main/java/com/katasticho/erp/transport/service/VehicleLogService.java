package com.katasticho.erp.transport.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.transport.dto.FleetDtos.*;
import com.katasticho.erp.transport.entity.VehicleLog;
import com.katasticho.erp.transport.repository.VehicleLogRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.*;

/**
 * Own-fleet running-cost ledger + total-cost-of-ownership rollup. Pure
 * operational record — the actual expense is still booked through the normal
 * expense/bill flow; this is the per-vehicle cost view (₹/km, mileage).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class VehicleLogService {

    private static final Set<String> TYPES = Set.of(
            "FUEL", "SERVICE", "REPAIR", "INSURANCE", "FITNESS", "PERMIT", "TYRE", "OTHER");

    private final VehicleLogRepository repository;

    @Transactional
    public VehicleLogResponse create(VehicleLogRequest req) {
        UUID orgId = requireOrgId();
        String type = req.logType() == null ? "" : req.logType().trim().toUpperCase();
        if (!TYPES.contains(type)) {
            throw new BusinessException("Unknown log type: " + type + ". Known: " + TYPES,
                    "VEHICLE_LOG_BAD_TYPE", HttpStatus.BAD_REQUEST);
        }
        VehicleLog log = VehicleLog.builder()
                .vehicleNumber(req.vehicleNumber().trim())
                .vanId(req.vanId())
                .logType(type)
                .logDate(req.logDate())
                .odometerKm(req.odometerKm())
                .quantity(req.quantity())
                .amount(req.amount() == null ? BigDecimal.ZERO : req.amount())
                .vendorContactId(req.vendorContactId())
                .referenceNo(req.referenceNo())
                .notes(req.notes())
                .build();
        log.setOrgId(orgId);
        return toResponse(repository.save(log));
    }

    @Transactional
    public void delete(UUID id) {
        VehicleLog l = require(id);
        l.setDeleted(true);
        repository.save(l);
    }

    @Transactional(readOnly = true)
    public List<VehicleLogResponse> list(String vehicleNumber) {
        UUID orgId = requireOrgId();
        List<VehicleLog> rows = (vehicleNumber == null || vehicleNumber.isBlank())
                ? repository.findByOrgIdAndIsDeletedFalseOrderByLogDateDesc(orgId)
                : repository.findByOrgIdAndVehicleNumberIgnoreCaseAndIsDeletedFalseOrderByLogDateDesc(
                        orgId, vehicleNumber.trim());
        return rows.stream().map(this::toResponse).toList();
    }

    /** TCO for one vehicle: total + by-type spend, distance, ₹/km, fuel mileage. */
    @Transactional(readOnly = true)
    public VehicleTcoSummary summary(String vehicleNumber) {
        UUID orgId = requireOrgId();
        List<VehicleLog> logs = repository
                .findByOrgIdAndVehicleNumberIgnoreCaseAndIsDeletedFalseOrderByLogDateDesc(
                        orgId, vehicleNumber.trim());

        BigDecimal total = BigDecimal.ZERO;
        BigDecimal fuelLitres = BigDecimal.ZERO;
        Map<String, BigDecimal> byType = new LinkedHashMap<>();
        BigDecimal minOdo = null, maxOdo = null;
        for (VehicleLog l : logs) {
            BigDecimal amt = nz(l.getAmount());
            total = total.add(amt);
            byType.merge(l.getLogType(), amt, BigDecimal::add);
            if ("FUEL".equals(l.getLogType()) && l.getQuantity() != null) {
                fuelLitres = fuelLitres.add(l.getQuantity());
            }
            if (l.getOdometerKm() != null) {
                minOdo = minOdo == null ? l.getOdometerKm() : minOdo.min(l.getOdometerKm());
                maxOdo = maxOdo == null ? l.getOdometerKm() : maxOdo.max(l.getOdometerKm());
            }
        }
        BigDecimal distance = (minOdo != null && maxOdo != null)
                ? maxOdo.subtract(minOdo) : BigDecimal.ZERO;
        BigDecimal costPerKm = distance.signum() > 0
                ? total.divide(distance, 2, RoundingMode.HALF_UP) : BigDecimal.ZERO;
        BigDecimal mileage = fuelLitres.signum() > 0 && distance.signum() > 0
                ? distance.divide(fuelLitres, 2, RoundingMode.HALF_UP) : BigDecimal.ZERO;

        return new VehicleTcoSummary(vehicleNumber, total, byType, distance,
                costPerKm, fuelLitres, mileage, logs.size());
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private VehicleLog require(UUID id) {
        return repository.findByIdAndOrgIdAndIsDeletedFalse(id, requireOrgId())
                .orElseThrow(() -> new BusinessException(
                        "Vehicle log not found", "VEHICLE_LOG_NOT_FOUND", HttpStatus.NOT_FOUND));
    }

    private VehicleLogResponse toResponse(VehicleLog l) {
        return new VehicleLogResponse(l.getId(), l.getVehicleNumber(), l.getVanId(),
                l.getLogType(), l.getLogDate(), l.getOdometerKm(), l.getQuantity(),
                l.getAmount(), l.getVendorContactId(), l.getReferenceNo(), l.getNotes());
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
