package com.katasticho.erp.transport.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.transport.dto.FleetDtos.*;
import com.katasticho.erp.transport.entity.VehicleLog;
import com.katasticho.erp.transport.repository.VehicleLogRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class VehicleLogServiceTest {

    @Mock private VehicleLogRepository repository;
    private VehicleLogService service;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new VehicleLogService(repository);
        TenantContext.setCurrentOrgId(orgId);
        when(repository.save(any(VehicleLog.class))).thenAnswer(inv -> {
            VehicleLog l = inv.getArgument(0);
            if (l.getId() == null) l.setId(UUID.randomUUID());
            return l;
        });
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    private VehicleLog log(String type, String amount, String odo, String litres) {
        VehicleLog l = VehicleLog.builder()
                .vehicleNumber("MH12AB1234").logType(type).logDate(LocalDate.now())
                .amount(new BigDecimal(amount))
                .odometerKm(odo == null ? null : new BigDecimal(odo))
                .quantity(litres == null ? null : new BigDecimal(litres))
                .build();
        l.setOrgId(orgId);
        return l;
    }

    @Test
    void create_rejectsUnknownType() {
        assertThatThrownBy(() -> service.create(new VehicleLogRequest(
                "MH12AB1234", null, "WASH", LocalDate.now(), null, null,
                new BigDecimal("100"), null, null, null)))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo("VEHICLE_LOG_BAD_TYPE");
    }

    @Test
    void summary_computesTcoCostPerKmAndMileage() {
        // Odometer 1000 → 2000 (ran 1000 km). Fuel 100 L total. Spend 8000 + 2000 = 10000.
        when(repository.findByOrgIdAndVehicleNumberIgnoreCaseAndIsDeletedFalseOrderByLogDateDesc(
                eq(orgId), eq("MH12AB1234")))
                .thenReturn(List.of(
                        log("FUEL", "8000", "2000", "100"),   // latest odometer
                        log("FUEL", "0", "1000", "0"),         // opening odometer
                        log("SERVICE", "2000", null, null)));

        VehicleTcoSummary s = service.summary("MH12AB1234");

        assertThat(s.totalSpend()).isEqualByComparingTo("10000");
        assertThat(s.distanceKm()).isEqualByComparingTo("1000");      // 2000 - 1000
        assertThat(s.costPerKm()).isEqualByComparingTo("10");         // 10000 / 1000
        assertThat(s.fuelLitres()).isEqualByComparingTo("100");
        assertThat(s.mileageKmPerLitre()).isEqualByComparingTo("10"); // 1000 / 100
        assertThat(s.spendByType().get("FUEL")).isEqualByComparingTo("8000");
        assertThat(s.spendByType().get("SERVICE")).isEqualByComparingTo("2000");
    }

    @Test
    void summary_noOdometer_zeroDerivedMetrics() {
        when(repository.findByOrgIdAndVehicleNumberIgnoreCaseAndIsDeletedFalseOrderByLogDateDesc(
                eq(orgId), any()))
                .thenReturn(List.of(log("REPAIR", "1500", null, null)));

        VehicleTcoSummary s = service.summary("MH12AB1234");

        assertThat(s.totalSpend()).isEqualByComparingTo("1500");
        assertThat(s.distanceKm()).isEqualByComparingTo("0");
        assertThat(s.costPerKm()).isEqualByComparingTo("0");   // no distance → no ₹/km
        assertThat(s.mileageKmPerLitre()).isEqualByComparingTo("0");
    }
}
