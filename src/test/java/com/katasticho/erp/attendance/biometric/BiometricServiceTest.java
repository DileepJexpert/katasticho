package com.katasticho.erp.attendance.biometric;

import com.katasticho.erp.attendance.FieldAttendanceRepository;
import com.katasticho.erp.attendance.biometric.entity.BiometricAttendanceLog;
import com.katasticho.erp.attendance.biometric.entity.BiometricDevice;
import com.katasticho.erp.attendance.biometric.repository.BiometricAttendanceLogRepository;
import com.katasticho.erp.attendance.biometric.repository.BiometricDeviceRepository;
import com.katasticho.erp.attendance.biometric.service.BiometricService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class BiometricServiceTest {

    @Mock private BiometricDeviceRepository deviceRepository;
    @Mock private BiometricAttendanceLogRepository logRepository;
    @Mock private EmployeeRepository employeeRepository;
    @Mock private FieldAttendanceRepository fieldAttendanceRepository;

    private BiometricService service;
    private final UUID orgId = UUID.randomUUID();
    private final UUID deviceId = UUID.randomUUID();
    private final UUID employeeId = UUID.randomUUID();
    private Employee mockEmployee;
    private BiometricDevice mockDevice;

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        service = new BiometricService(deviceRepository, logRepository, employeeRepository, fieldAttendanceRepository);

        mockEmployee = Employee.builder()
                .fullName("Rajesh Kumar")
                .employeeCode("EMP-001")
                .biometricPin("101")
                .build();
        mockEmployee.setId(employeeId);
        mockEmployee.setOrgId(orgId);

        mockDevice = BiometricDevice.builder()
                .deviceName("Main Entrance ZKTeco")
                .deviceIp("192.168.1.201")
                .port(4370)
                .serialNumber("ZK987654321")
                .protocol("ZK_TCP")
                .location("Reception Gate 1")
                .status("ONLINE")
                .cloudWebhookToken("bio_token_123")
                .build();
        mockDevice.setId(deviceId);
        mockDevice.setOrgId(orgId);

        when(deviceRepository.save(any(BiometricDevice.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        when(logRepository.save(any(BiometricAttendanceLog.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        when(employeeRepository.findByOrgIdAndBiometricPinAndIsDeletedFalse(eq(orgId), eq("101")))
                .thenReturn(Optional.of(mockEmployee));
        when(employeeRepository.findByOrgIdAndEmployeeCodeAndIsDeletedFalse(eq(orgId), eq("EMP-001")))
                .thenReturn(Optional.of(mockEmployee));
        when(employeeRepository.findByIdAndOrgIdAndIsDeletedFalse(eq(employeeId), eq(orgId)))
                .thenReturn(Optional.of(mockEmployee));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void testRegisterDevice_GeneratesCloudTokenAndSaves() {
        var req = new BiometricService.DeviceRegisterRequest(
                "Warehouse Turnstile", "192.168.1.205", 4370, "SN_WH_01", "ZK_TCP", "Warehouse B"
        );

        BiometricDevice saved = service.registerDevice(req);

        assertNotNull(saved);
        assertEquals("Warehouse Turnstile", saved.getDeviceName());
        assertEquals("192.168.1.205", saved.getDeviceIp());
        assertEquals(4370, saved.getPort());
        assertEquals("ONLINE", saved.getStatus());
        assertNotNull(saved.getCloudWebhookToken());
        assertTrue(saved.getCloudWebhookToken().startsWith("bio_"));
        verify(deviceRepository).save(any(BiometricDevice.class));
    }

    @Test
    void testRecordPunchLog_MatchesEmployeeByBiometricPin() {
        Instant now = Instant.now();
        BiometricAttendanceLog log = service.recordPunchLog(
                orgId, deviceId, "101", now, "CHECK_IN", "FINGERPRINT", "RAW_ZK"
        );

        assertNotNull(log);
        assertEquals(employeeId, log.getEmployeeId());
        assertEquals("101", log.getBiometricPin());
        assertEquals("CHECK_IN", log.getPunchType());
        assertEquals("FINGERPRINT", log.getVerifyMode());
        assertEquals("PROCESSED", log.getSyncStatus());
    }

    @Test
    void testRecordPunchLog_UnmatchedPinRecordedSafely() {
        when(employeeRepository.findByOrgIdAndBiometricPinAndIsDeletedFalse(eq(orgId), eq("999")))
                .thenReturn(Optional.empty());
        when(employeeRepository.findByOrgIdAndEmployeeCodeAndIsDeletedFalse(eq(orgId), eq("999")))
                .thenReturn(Optional.empty());

        Instant now = Instant.now();
        BiometricAttendanceLog log = service.recordPunchLog(
                orgId, deviceId, "999", now, "CHECK_IN", "CARD", "RAW_ZK"
        );

        assertNotNull(log);
        assertNull(log.getEmployeeId());
        assertEquals("999", log.getBiometricPin());
        assertEquals("UNMATCHED", log.getSyncStatus());
    }

    @Test
    void testAdmsIngestion_ParsesTabDelimitedPayload() {
        when(deviceRepository.findFirstByCloudWebhookTokenAndIsDeletedFalse("bio_token_123"))
                .thenReturn(Optional.of(mockDevice));

        String admsPayload = "101\t2026-08-18 09:00:00\t0\t1\n" +
                             "101\t2026-08-18 18:30:00\t1\t15\n";

        var result = service.parseAndIngestAdms("bio_token_123", admsPayload);

        assertNotNull(result);
        assertEquals(2, result.totalReceived());
        assertEquals(2, result.processed());
        assertEquals(0, result.unmatched());
        assertEquals(0, result.errors());
    }

    @Test
    void testSimulatePunch_RecordsAndReturnsResponse() {
        var req = new BiometricService.SimulatePunchRequest(
                deviceId, employeeId, "101", Instant.now(), "CHECK_IN", "FACE"
        );

        var resp = service.simulatePunch(req);

        assertNotNull(resp);
        assertEquals(employeeId, resp.employeeId());
        assertEquals("Rajesh Kumar", resp.employeeName());
        assertEquals("CHECK_IN", resp.punchType());
        assertEquals("FACE", resp.verifyMode());
        assertEquals("PROCESSED", resp.syncStatus());
    }
}
