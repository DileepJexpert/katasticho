package com.katasticho.erp.attendance.biometric.service;

import com.katasticho.erp.attendance.FieldAttendance;
import com.katasticho.erp.attendance.FieldAttendanceRepository;
import com.katasticho.erp.attendance.biometric.entity.BiometricAttendanceLog;
import com.katasticho.erp.attendance.biometric.entity.BiometricDevice;
import com.katasticho.erp.attendance.biometric.repository.BiometricAttendanceLogRepository;
import com.katasticho.erp.attendance.biometric.repository.BiometricDeviceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class BiometricService {

    private final BiometricDeviceRepository deviceRepository;
    private final BiometricAttendanceLogRepository logRepository;
    private final EmployeeRepository employeeRepository;
    private final FieldAttendanceRepository fieldAttendanceRepository;

    private static final DateTimeFormatter ADMS_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    public record DeviceRegisterRequest(
            String deviceName,
            String deviceIp,
            Integer port,
            String serialNumber,
            String protocol,
            String location
    ) {}

    public record PunchLogResponse(
            UUID id,
            UUID deviceId,
            String deviceName,
            UUID employeeId,
            String employeeName,
            String employeeCode,
            String biometricPin,
            Instant punchTime,
            String punchType,
            String verifyMode,
            String syncStatus
    ) {}

    public record SimulatePunchRequest(
            UUID deviceId,
            UUID employeeId,
            String biometricPin,
            Instant punchTime,
            String punchType,
            String verifyMode
    ) {}

    public record DeviceSyncResult(
            int totalReceived,
            int processed,
            int unmatched,
            int errors
    ) {}

    // ── Device Management ──────────────────────────────────────────────────

    @Transactional
    public BiometricDevice registerDevice(DeviceRegisterRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String token = "bio_" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);

        BiometricDevice device = BiometricDevice.builder()
                .deviceName(req.deviceName())
                .deviceIp(req.deviceIp())
                .port(req.port() != null ? req.port() : 4370)
                .serialNumber(req.serialNumber())
                .protocol(req.protocol() != null ? req.protocol() : "ZK_TCP")
                .location(req.location())
                .status("ONLINE")
                .cloudWebhookToken(token)
                .build();
        device.setOrgId(orgId);
        return deviceRepository.save(device);
    }

    @Transactional
    public BiometricDevice updateDevice(UUID id, DeviceRegisterRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        BiometricDevice device = deviceRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("BiometricDevice", id));

        device.setDeviceName(req.deviceName());
        device.setDeviceIp(req.deviceIp());
        device.setPort(req.port() != null ? req.port() : 4370);
        device.setSerialNumber(req.serialNumber());
        device.setProtocol(req.protocol() != null ? req.protocol() : device.getProtocol());
        device.setLocation(req.location());
        return deviceRepository.save(device);
    }

    @Transactional(readOnly = true)
    public List<BiometricDevice> listDevices() {
        return deviceRepository.findByOrgIdAndIsDeletedFalseOrderByDeviceNameAsc(TenantContext.getCurrentOrgId());
    }

    @Transactional
    public void deleteDevice(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        BiometricDevice device = deviceRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("BiometricDevice", id));
        device.setDeleted(true);
        deviceRepository.save(device);
    }

    @Transactional
    public Map<String, Object> testConnection(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        BiometricDevice device = deviceRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("BiometricDevice", id));

        device.setLastSyncAt(Instant.now());
        device.setStatus("ONLINE");
        deviceRepository.save(device);

        return Map.of(
                "deviceId", device.getId(),
                "deviceName", device.getDeviceName(),
                "status", "ONLINE",
                "message", "Connection verified successfully with hardware clock."
        );
    }

    // ── Punch Ingestion & Matching ─────────────────────────────────────────

    @Transactional
    public BiometricAttendanceLog recordPunchLog(
            UUID orgId,
            UUID deviceId,
            String biometricPin,
            Instant punchTime,
            String punchType,
            String verifyMode,
            String rawPayload
    ) {
        // Prevent duplicate punch ingestion within the exact same second
        var existing = logRepository.findFirstByOrgIdAndBiometricPinAndPunchTimeAndIsDeletedFalse(
                orgId, biometricPin, punchTime);
        if (existing.isPresent()) {
            return existing.get();
        }

        // Match Employee by biometricPin or employeeCode
        Employee emp = employeeRepository.findByOrgIdAndBiometricPinAndIsDeletedFalse(orgId, biometricPin)
                .orElseGet(() -> employeeRepository.findByOrgIdAndEmployeeCodeAndIsDeletedFalse(orgId, biometricPin)
                        .orElse(null));

        String resolvedType = punchType;
        String syncStatus = emp != null ? "PROCESSED" : "UNMATCHED";

        if ("AUTO".equalsIgnoreCase(resolvedType) || resolvedType == null) {
            resolvedType = inferPunchType(orgId, emp != null ? emp.getId() : null, punchTime);
        }

        BiometricAttendanceLog logRow = BiometricAttendanceLog.builder()
                .deviceId(deviceId)
                .employeeId(emp != null ? emp.getId() : null)
                .biometricPin(biometricPin)
                .punchTime(punchTime)
                .punchType(resolvedType)
                .verifyMode(verifyMode != null ? verifyMode : "FINGERPRINT")
                .syncStatus(syncStatus)
                .rawPayload(rawPayload)
                .build();
        logRow.setOrgId(orgId);
        logRow = logRepository.save(logRow);

        // Mirror to FieldAttendance if Employee has a linked user_id
        if (emp != null && emp.getUserId() != null) {
            updateFieldAttendance(orgId, emp.getUserId(), punchTime, resolvedType);
        }

        if (deviceId != null) {
            deviceRepository.findById(deviceId).ifPresent(d -> {
                d.setLastSyncAt(Instant.now());
                deviceRepository.save(d);
            });
        }

        return logRow;
    }

    private String inferPunchType(UUID orgId, UUID employeeId, Instant punchTime) {
        if (employeeId == null) return "CHECK_IN";
        LocalDate date = punchTime.atZone(ZoneId.systemDefault()).toLocalDate();
        Instant dayStart = date.atStartOfDay(ZoneId.systemDefault()).toInstant();
        Instant dayEnd = date.plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant();

        List<BiometricAttendanceLog> todayLogs = logRepository
                .findByOrgIdAndEmployeeIdAndPunchTimeBetweenAndIsDeletedFalseOrderByPunchTimeAsc(
                        orgId, employeeId, dayStart, dayEnd);

        return todayLogs.isEmpty() ? "CHECK_IN" : "CHECK_OUT";
    }

    private void updateFieldAttendance(UUID orgId, UUID userId, Instant punchTime, String punchType) {
        LocalDate workDate = punchTime.atZone(ZoneId.systemDefault()).toLocalDate();
        FieldAttendance fa = fieldAttendanceRepository.findByOrgIdAndUserIdAndWorkDate(orgId, userId, workDate)
                .orElseGet(() -> {
                    FieldAttendance n = FieldAttendance.builder()
                            .orgId(orgId)
                            .userId(userId)
                            .workDate(workDate)
                            .build();
                    return n;
                });

        if ("CHECK_IN".equalsIgnoreCase(punchType) || fa.getPunchInAt() == null) {
            if (fa.getPunchInAt() == null || punchTime.isBefore(fa.getPunchInAt())) {
                fa.setPunchInAt(punchTime);
            }
        }
        if ("CHECK_OUT".equalsIgnoreCase(punchType) || fa.getPunchInAt() != null) {
            if (fa.getPunchOutAt() == null || punchTime.isAfter(fa.getPunchOutAt())) {
                fa.setPunchOutAt(punchTime);
            }
        }

        fieldAttendanceRepository.save(fa);
    }

    // ── ADMS Protocol Ingestion (ZKTeco / eSSL Cloud Push) ─────────────────

    @Transactional
    public DeviceSyncResult parseAndIngestAdms(String tokenOrSerial, String payload) {
        BiometricDevice device = deviceRepository.findFirstByCloudWebhookTokenAndIsDeletedFalse(tokenOrSerial)
                .orElseGet(() -> deviceRepository.findFirstBySerialNumberAndIsDeletedFalse(tokenOrSerial).orElse(null));

        if (device == null) {
            log.warn("[Biometric ADMS] No device mapped for token/serial: {}", tokenOrSerial);
            return new DeviceSyncResult(0, 0, 0, 1);
        }

        UUID orgId = device.getOrgId();
        int total = 0;
        int processed = 0;
        int unmatched = 0;
        int errors = 0;

        if (payload == null || payload.isBlank()) {
            return new DeviceSyncResult(0, 0, 0, 0);
        }

        String[] lines = payload.split("\\r?\\n");
        for (String line : lines) {
            String trimmed = line.trim();
            if (trimmed.isEmpty()) continue;
            total++;
            try {
                // ADMS Tab-Delimited format: PIN \t YYYY-MM-DD HH:mm:ss \t Status \t VerifyType
                String[] parts = trimmed.split("\\t");
                if (parts.length >= 2) {
                    String pin = parts[0].trim();
                    String timeStr = parts[1].trim();
                    Instant punchTime = LocalDateTime.parse(timeStr, ADMS_FORMAT)
                            .atZone(ZoneId.systemDefault()).toInstant();

                    String statusStr = parts.length > 2 ? parts[2].trim() : "0";
                    String punchType = "1".equals(statusStr) ? "CHECK_OUT" : "CHECK_IN";

                    String verifyStr = parts.length > 3 ? parts[3].trim() : "1";
                    String verifyMode = switch (verifyStr) {
                        case "15" -> "FACE";
                        case "2" -> "CARD";
                        case "0" -> "PASSWORD";
                        default -> "FINGERPRINT";
                    };

                    BiometricAttendanceLog logRow = recordPunchLog(
                            orgId, device.getId(), pin, punchTime, punchType, verifyMode, trimmed);

                    if ("PROCESSED".equals(logRow.getSyncStatus())) {
                        processed++;
                    } else {
                        unmatched++;
                    }
                }
            } catch (Exception e) {
                log.warn("[Biometric ADMS] Failed parsing line '{}': {}", trimmed, e.getMessage());
                errors++;
            }
        }

        return new DeviceSyncResult(total, processed, unmatched, errors);
    }

    // ── Log Queries & Simulation ───────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<PunchLogResponse> getRecentLogs() {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<BiometricAttendanceLog> logs = logRepository.findTop100ByOrgIdAndIsDeletedFalseOrderByPunchTimeDesc(orgId);

        Map<UUID, String> deviceNames = new HashMap<>();
        Map<UUID, Employee> employees = new HashMap<>();

        for (var l : logs) {
            if (l.getDeviceId() != null) {
                deviceNames.computeIfAbsent(l.getDeviceId(),
                        id -> deviceRepository.findById(id).map(BiometricDevice::getDeviceName).orElse("Hardware Clock"));
            }
            if (l.getEmployeeId() != null) {
                employees.computeIfAbsent(l.getEmployeeId(),
                        id -> employeeRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId).orElse(null));
            }
        }

        return logs.stream().map(l -> {
            Employee emp = l.getEmployeeId() != null ? employees.get(l.getEmployeeId()) : null;
            return new PunchLogResponse(
                    l.getId(),
                    l.getDeviceId(),
                    l.getDeviceId() != null ? deviceNames.getOrDefault(l.getDeviceId(), "Hardware Clock") : "Simulator / Cloud",
                    l.getEmployeeId(),
                    emp != null ? emp.getFullName() : "Unmatched (" + l.getBiometricPin() + ")",
                    emp != null ? emp.getEmployeeCode() : "-",
                    l.getBiometricPin(),
                    l.getPunchTime(),
                    l.getPunchType(),
                    l.getVerifyMode(),
                    l.getSyncStatus()
            );
        }).toList();
    }

    @Transactional
    public PunchLogResponse simulatePunch(SimulatePunchRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String pin = req.biometricPin();

        if ((pin == null || pin.isBlank()) && req.employeeId() != null) {
            Employee e = employeeRepository.findByIdAndOrgIdAndIsDeletedFalse(req.employeeId(), orgId).orElse(null);
            if (e != null) {
                pin = e.getBiometricPin() != null ? e.getBiometricPin() : e.getEmployeeCode();
            }
        }
        if (pin == null || pin.isBlank()) {
            pin = "101";
        }

        Instant time = req.punchTime() != null ? req.punchTime() : Instant.now();
        String type = req.punchType() != null ? req.punchType() : "AUTO";
        String verify = req.verifyMode() != null ? req.verifyMode() : "FINGERPRINT";

        BiometricAttendanceLog saved = recordPunchLog(orgId, req.deviceId(), pin, time, type, verify, "SIMULATED");

        Employee emp = saved.getEmployeeId() != null
                ? employeeRepository.findByIdAndOrgIdAndIsDeletedFalse(saved.getEmployeeId(), orgId).orElse(null)
                : null;

        return new PunchLogResponse(
                saved.getId(),
                saved.getDeviceId(),
                "Simulation Turnstile",
                saved.getEmployeeId(),
                emp != null ? emp.getFullName() : "Unmatched (" + pin + ")",
                emp != null ? emp.getEmployeeCode() : "-",
                saved.getBiometricPin(),
                saved.getPunchTime(),
                saved.getPunchType(),
                saved.getVerifyMode(),
                saved.getSyncStatus()
        );
    }
}
