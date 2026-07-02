package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.HsnGstRateHistoryResponse;
import com.katasticho.erp.inventory.entity.HsnGstMaster;
import com.katasticho.erp.inventory.entity.HsnGstRateHistory;
import com.katasticho.erp.inventory.repository.HsnGstMasterRepository;
import com.katasticho.erp.inventory.repository.HsnGstRateHistoryRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class HsnGstRateHistoryServiceTest {

    @Mock private HsnGstMasterRepository hsnRepository;
    @Mock private HsnGstRateHistoryRepository rateHistoryRepository;

    private PharmacyMasterService svc;

    // Fixed "today" = 2026-07-02, so a 2025-09-22 open period is effective-now.
    private final Clock clock = Clock.fixed(
            LocalDate.of(2026, 7, 2).atStartOfDay(ZoneId.systemDefault()).toInstant(),
            ZoneId.systemDefault());

    @BeforeEach
    void setUp() {
        svc = new PharmacyMasterService(null, hsnRepository, rateHistoryRepository,
                null, null, null, null, null, null, clock);
        when(rateHistoryRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        // Rate-change (open-ended) writes are platform-admin only; default the
        // role so the happy-path tests exercise the real current-rate flow.
        TenantContext.setCurrentRole("PLATFORM_ADMIN");
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private HsnGstRateHistory period(String code, String rate, LocalDate from, LocalDate to) {
        return HsnGstRateHistory.builder()
                .hsnCode(code).gstRate(new BigDecimal(rate))
                .effectiveFrom(from).effectiveTo(to).source("SEED").build();
    }

    @Test
    void rateHistory_maps_periods_newest_first() {
        when(rateHistoryRepository.findByHsnCodeOrderByEffectiveFromDesc("3004"))
                .thenReturn(List.of(
                        period("3004", "5", LocalDate.of(2025, 9, 22), null),
                        period("3004", "12", LocalDate.of(2017, 7, 1), LocalDate.of(2025, 9, 21))));

        List<HsnGstRateHistoryResponse> history = svc.rateHistory("3004");
        assertThat(history).hasSize(2);
        assertThat(history.get(0).gstRate()).isEqualByComparingTo("5");
        assertThat(history.get(0).effectiveTo()).isNull();
        assertThat(history.get(1).gstRate()).isEqualByComparingTo("12");
    }

    @Test
    void rateAsOf_returns_the_covering_period_or_null() {
        when(rateHistoryRepository.findEffectiveOn(eq("3004"), eq(LocalDate.of(2024, 5, 1)), any()))
                .thenReturn(List.of(period("3004", "12", LocalDate.of(2017, 7, 1), LocalDate.of(2025, 9, 21))));
        when(rateHistoryRepository.findEffectiveOn(eq("3004"), eq(LocalDate.of(2010, 1, 1)), any()))
                .thenReturn(List.of());

        assertThat(svc.rateAsOf("3004", LocalDate.of(2024, 5, 1)).gstRate()).isEqualByComparingTo("12");
        assertThat(svc.rateAsOf("3004", LocalDate.of(2010, 1, 1))).isNull();
    }

    @Test
    void addRateHistory_openEnded_closes_prior_period_and_syncs_master() {
        HsnGstRateHistory prior = period("3004", "12", LocalDate.of(2017, 7, 1), null);
        when(rateHistoryRepository.existsByHsnCodeAndEffectiveFrom("3004", LocalDate.of(2025, 9, 22)))
                .thenReturn(false);
        when(rateHistoryRepository.findByHsnCodeAndEffectiveToIsNull("3004"))
                .thenReturn(new java.util.ArrayList<>(List.of(prior)));
        HsnGstMaster master = new HsnGstMaster();
        master.setHsnCode("3004");
        master.setGstRate(new BigDecimal("12"));
        when(hsnRepository.findByHsnCodeAndActiveTrue("3004")).thenReturn(Optional.of(master));

        HsnGstRateHistoryResponse added = svc.addRateHistory("3004", new BigDecimal("5"), null,
                LocalDate.of(2025, 9, 22), null, "Notification 9/2025-CT(Rate)", "GST_2_0", "medicines");

        assertThat(added.gstRate()).isEqualByComparingTo("5");
        // prior open period closed the day before
        assertThat(prior.getEffectiveTo()).isEqualTo(LocalDate.of(2025, 9, 21));
        // master current rate synced to the new open rate
        assertThat(master.getGstRate()).isEqualByComparingTo("5");
        verify(hsnRepository).save(master);
    }

    @Test
    void addRateHistory_duplicate_start_is_rejected() {
        when(rateHistoryRepository.existsByHsnCodeAndEffectiveFrom("3004", LocalDate.of(2025, 9, 22)))
                .thenReturn(true);

        assertThatThrownBy(() -> svc.addRateHistory("3004", new BigDecimal("5"), null,
                LocalDate.of(2025, 9, 22), null, null, null, null))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "HSN_RATE_PERIOD_EXISTS");
        verify(rateHistoryRepository, never()).save(any());
    }

    @Test
    void addRateHistory_rejects_bad_rate_and_range() {
        assertThatThrownBy(() -> svc.addRateHistory("3004", new BigDecimal("150"), null,
                LocalDate.of(2025, 9, 22), null, null, null, null))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "HSN_RATE_INVALID");
        assertThatThrownBy(() -> svc.addRateHistory("3004", new BigDecimal("5"), null,
                LocalDate.of(2025, 9, 22), LocalDate.of(2025, 9, 1), null, null, null))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "HSN_RATE_RANGE_INVALID");
    }

    @Test
    void addRateHistory_openEnded_overlapping_current_is_rejected() {
        // current open period starts 2025-09-22; a new open period must start AFTER it
        HsnGstRateHistory current = period("3004", "5", LocalDate.of(2025, 9, 22), null);
        when(rateHistoryRepository.existsByHsnCodeAndEffectiveFrom("3004", LocalDate.of(2025, 1, 1)))
                .thenReturn(false);
        when(rateHistoryRepository.findByHsnCodeAndEffectiveToIsNull("3004"))
                .thenReturn(new java.util.ArrayList<>(List.of(current)));

        assertThatThrownBy(() -> svc.addRateHistory("3004", new BigDecimal("18"), null,
                LocalDate.of(2025, 1, 1), null, null, null, null))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "HSN_RATE_PERIOD_OVERLAP");
    }

    @Test
    void addRateHistory_closedPeriod_does_not_sync_master() {
        // a CLOSED backfill period is allowed for a non-platform admin and must
        // not touch the shared current master rate
        TenantContext.setCurrentRole("ADMIN");
        when(rateHistoryRepository.existsByHsnCodeAndEffectiveFrom("3004", LocalDate.of(2017, 7, 1)))
                .thenReturn(false);

        svc.addRateHistory("3004", new BigDecimal("12"), null,
                LocalDate.of(2017, 7, 1), LocalDate.of(2025, 9, 21), null, "HISTORICAL", null);

        verify(hsnRepository, never()).save(any());
        verify(rateHistoryRepository).save(any());
    }

    @Test
    void addRateHistory_openEnded_requires_platform_admin() {
        // Bug 3: an org ADMIN must NOT be able to change the shared current
        // rate that drives every tenant's tax defaults.
        TenantContext.setCurrentRole("ADMIN");
        when(rateHistoryRepository.existsByHsnCodeAndEffectiveFrom("3004", LocalDate.of(2025, 9, 22)))
                .thenReturn(false);

        assertThatThrownBy(() -> svc.addRateHistory("3004", new BigDecimal("1"), null,
                LocalDate.of(2025, 9, 22), null, null, null, null))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "HSN_PLATFORM_ROW_READONLY");
        verify(rateHistoryRepository, never()).save(any());
        verify(hsnRepository, never()).save(any());
    }

    @Test
    void addRateHistory_futureDated_openPeriod_does_not_sync_master_early() {
        // Bug 4: a period effective 2027-01-01 (fixed today = 2026-07-02) must
        // NOT overwrite the live master rate before its effective_from arrives.
        when(rateHistoryRepository.existsByHsnCodeAndEffectiveFrom("3004", LocalDate.of(2027, 1, 1)))
                .thenReturn(false);
        when(rateHistoryRepository.findByHsnCodeAndEffectiveToIsNull("3004"))
                .thenReturn(new java.util.ArrayList<>());

        svc.addRateHistory("3004", new BigDecimal("18"), null,
                LocalDate.of(2027, 1, 1), null, "future change", "GST_FUTURE", null);

        // history row saved, but master current rate untouched
        verify(rateHistoryRepository).save(any());
        verify(hsnRepository, never()).save(any());
    }
}
