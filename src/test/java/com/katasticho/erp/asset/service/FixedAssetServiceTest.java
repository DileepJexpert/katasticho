package com.katasticho.erp.asset.service;

import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.asset.entity.FixedAsset;
import com.katasticho.erp.asset.repository.FixedAssetDepreciationRepository;
import com.katasticho.erp.asset.repository.FixedAssetRepository;
import com.katasticho.erp.common.context.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class FixedAssetServiceTest {

    @Mock private FixedAssetRepository assetRepository;
    @Mock private FixedAssetDepreciationRepository depreciationRepository;
    @Mock private JournalService journalService;
    private FixedAssetService service;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new FixedAssetService(assetRepository, depreciationRepository, journalService);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
        when(journalService.postJournal(any())).thenAnswer(i -> {
            JournalEntry je = new JournalEntry();
            je.setId(UUID.randomUUID());
            return je;
        });
        when(assetRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        when(depreciationRepository.save(any())).thenAnswer(i -> i.getArgument(0));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private FixedAsset slm(String cost, int lifeMonths, String residual) {
        return FixedAsset.builder().id(UUID.randomUUID()).orgId(orgId)
                .assetCode("A1").name("Laptop").acquisitionDate(LocalDate.of(2026, 4, 1))
                .cost(new BigDecimal(cost)).residualValue(new BigDecimal(residual))
                .bookMethod("SLM").bookUsefulLifeMonths(lifeMonths)
                .accumulatedDepreciation(BigDecimal.ZERO).status("ACTIVE").build();
    }

    private FixedAsset wdv(String cost, String ratePct, String accumulated) {
        return FixedAsset.builder().id(UUID.randomUUID()).orgId(orgId)
                .assetCode("A2").name("Machine").acquisitionDate(LocalDate.of(2026, 4, 1))
                .cost(new BigDecimal(cost)).residualValue(BigDecimal.ZERO)
                .bookMethod("WDV").bookRatePct(new BigDecimal(ratePct))
                .accumulatedDepreciation(new BigDecimal(accumulated)).status("ACTIVE").build();
    }

    @Test
    void slm_monthlyDepreciation() {
        // (120000 - 0) / 36 months = 3333.33
        FixedAsset a = slm("120000", 36, "0");
        assertEquals(0, new BigDecimal("3333.33").compareTo(service.monthlyBookDepreciation(a)));
    }

    @Test
    void wdv_monthlyDepreciationOnBookValue() {
        // book value 100000, 12% WDV annual → 12000/yr → 1000/month
        FixedAsset a = wdv("100000", "12", "0");
        assertEquals(0, new BigDecimal("1000.00").compareTo(service.monthlyBookDepreciation(a)));
    }

    @Test
    void depreciation_flooredAtResidual() {
        // depreciable = 100, already 95 accumulated → only 5 left though monthly would be more
        FixedAsset a = slm("100", 1, "0");
        a.setAccumulatedDepreciation(new BigDecimal("95"));
        assertEquals(0, new BigDecimal("5").compareTo(service.monthlyBookDepreciation(a)));
    }

    @Test
    void runDepreciation_postsOneJournalAndSkipsAlreadyCharged() {
        FixedAsset a = slm("120000", 36, "0");
        FixedAsset b = wdv("100000", "12", "0");
        when(assetRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByAcquisitionDateAsc(orgId, "ACTIVE"))
                .thenReturn(List.of(a, b));
        // b already charged this period → skipped
        when(depreciationRepository.existsByOrgIdAndFixedAssetIdAndPeriodYearAndPeriodMonth(
                orgId, b.getId(), 2026, 5)).thenReturn(true);
        when(depreciationRepository.existsByOrgIdAndFixedAssetIdAndPeriodYearAndPeriodMonth(
                orgId, a.getId(), 2026, 5)).thenReturn(false);

        Map<String, Object> r = service.runDepreciation(2026, 5);

        assertEquals(1, r.get("assetCount")); // only a charged
        assertEquals(0, new BigDecimal("3333.33").compareTo((BigDecimal) r.get("totalDepreciation")));
        verify(journalService, times(1)).postJournal(any());
        // a's accumulated grew, a dep row was written
        verify(depreciationRepository, times(1)).save(any());
    }

    @Test
    void runDepreciation_noEligibleAssets_postsNothing() {
        when(assetRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByAcquisitionDateAsc(orgId, "ACTIVE"))
                .thenReturn(List.of());
        Map<String, Object> r = service.runDepreciation(2026, 5);
        assertEquals(0, r.get("assetCount"));
        verify(journalService, never()).postJournal(any());
    }

    @Test
    void dispose_computesGainAndPostsBalancedJournal() {
        FixedAsset a = slm("100000", 36, "0");
        a.setAccumulatedDepreciation(new BigDecimal("40000")); // book value 60000
        when(assetRepository.findByIdAndOrgIdAndIsDeletedFalse(a.getId(), orgId))
                .thenReturn(java.util.Optional.of(a));

        // sold for 70000 → gain 10000
        Map<String, Object> r = service.dispose(a.getId(), LocalDate.of(2026, 9, 30),
                new BigDecimal("70000"), "1010", "4900");

        assertEquals("GAIN", r.get("result"));
        assertEquals(0, new BigDecimal("10000").compareTo((BigDecimal) r.get("gainLoss")));
        assertEquals("DISPOSED", a.getStatus());

        ArgumentCaptor<JournalPostRequest> cap = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(cap.capture());
        var lines = cap.getValue().lines();
        BigDecimal dr = lines.stream().map(l -> l.debit()).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal cr = lines.stream().map(l -> l.credit()).reduce(BigDecimal.ZERO, BigDecimal::add);
        assertEquals(0, dr.compareTo(cr)); // journal balances
    }

    @Test
    void incomeTax_blockSchedule_appliesHalfRateInAcquisitionYearUnder180Days() {
        // Computer, 40% IT WDV, bought 2026-12-01 (FY 2026-27) → < 180 days → half rate 20%
        FixedAsset comp = FixedAsset.builder().id(UUID.randomUUID()).orgId(orgId)
                .assetCode("C1").name("Server").acquisitionDate(LocalDate.of(2026, 12, 1))
                .cost(new BigDecimal("100000")).residualValue(BigDecimal.ZERO)
                .bookMethod("WDV").bookRatePct(new BigDecimal("40"))
                .itBlock("COMPUTER_40").itRatePct(new BigDecimal("40"))
                .accumulatedDepreciation(BigDecimal.ZERO).status("ACTIVE").build();
        when(assetRepository.findByOrgIdAndIsDeletedFalseOrderByAcquisitionDateDesc(orgId))
                .thenReturn(List.of(comp));

        Map<String, Object> r = service.incomeTaxSchedule(2026);

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> blocks = (List<Map<String, Object>>) r.get("blocks");
        assertEquals(1, blocks.size());
        Map<String, Object> blk = blocks.get(0);
        assertEquals("COMPUTER_40", blk.get("block"));
        // half rate (20%) of 100000 in the acquisition year = 20000
        assertEquals(0, new BigDecimal("20000.00").compareTo((BigDecimal) blk.get("depreciation")));
        assertEquals(0, new BigDecimal("80000.00").compareTo((BigDecimal) blk.get("closingWdv")));
    }
}
