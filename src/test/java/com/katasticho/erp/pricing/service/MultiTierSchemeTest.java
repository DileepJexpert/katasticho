package com.katasticho.erp.pricing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.pricing.dto.SchemeCalculationResult;
import com.katasticho.erp.pricing.dto.SchemeEvaluationRequest;
import com.katasticho.erp.pricing.entity.Scheme;
import com.katasticho.erp.pricing.repository.SchemeRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MultiTierSchemeTest {

    @Mock
    private SchemeRepository schemeRepository;

    @InjectMocks
    private SchemeService schemeService;

    private UUID orgId;
    private UUID itemId;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        itemId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void evaluateScheme_fullScheme_appliesMultiplierAndCalculatesFreeQuantity() {
        Scheme scheme = Scheme.builder()
                .id(UUID.randomUUID())
                .orgId(orgId)
                .name("Buy 10 Get 1 Free (Augmentin)")
                .schemeType("BUY_X_GET_Y")
                .itemId(itemId)
                .buyQuantity(new BigDecimal("10"))
                .freeQuantity(new BigDecimal("1"))
                .allowHalfScheme(true)
                .companySubsidyPercent(new BigDecimal("100.00"))
                .active(true)
                .build();

        when(schemeRepository.findApplicable(eq(orgId), eq(itemId), any(LocalDate.class)))
                .thenReturn(List.of(scheme));

        SchemeEvaluationRequest req = new SchemeEvaluationRequest(
                itemId,
                new BigDecimal("20"),
                new BigDecimal("100.00"),
                null
        );

        SchemeCalculationResult res = schemeService.evaluateScheme(req);

        assertThat(res).isNotNull();
        assertThat(res.freeQuantity()).isEqualByComparingTo("2");
        assertThat(res.discountPercent()).isEqualByComparingTo("0.00");
        assertThat(res.isHalfSchemeApplied()).isFalse();
        assertThat(res.companyFundedAmount()).isEqualByComparingTo("200.00"); // 2 free * 100
        assertThat(res.distributorFundedAmount()).isEqualByComparingTo("0.00");
    }

    @Test
    void evaluateScheme_halfScheme_convertsFreeGoodsToCashDiscount() {
        Scheme scheme = Scheme.builder()
                .id(UUID.randomUUID())
                .orgId(orgId)
                .name("10+1 Half Scheme Allowed")
                .schemeType("BUY_X_GET_Y")
                .itemId(itemId)
                .buyQuantity(new BigDecimal("10"))
                .freeQuantity(new BigDecimal("1"))
                .allowHalfScheme(true)
                .halfSchemeMinQty(new BigDecimal("5"))
                .companySubsidyPercent(new BigDecimal("80.00"))
                .active(true)
                .build();

        when(schemeRepository.findApplicable(eq(orgId), eq(itemId), any(LocalDate.class)))
                .thenReturn(List.of(scheme));

        // Order 5 strips (Half scheme qualification)
        SchemeEvaluationRequest req = new SchemeEvaluationRequest(
                itemId,
                new BigDecimal("5"),
                new BigDecimal("100.00"),
                null
        );

        SchemeCalculationResult res = schemeService.evaluateScheme(req);

        assertThat(res).isNotNull();
        assertThat(res.isHalfSchemeApplied()).isTrue();
        assertThat(res.freeQuantity()).isEqualByComparingTo("0");
        // 1 / (10 + 1) = 9.09% discount
        assertThat(res.discountPercent()).isEqualByComparingTo("9.09");
        assertThat(res.discountAmount()).isEqualByComparingTo("45.45"); // 500 * 9.09% = 45.45
        assertThat(res.totalLineAmount()).isEqualByComparingTo("454.55");
        assertThat(res.companyFundedAmount()).isEqualByComparingTo("36.36"); // 80% of 45.45
    }

    @Test
    void evaluateScheme_specialNetRate_recalculatesEffectivePrice() {
        Scheme scheme = Scheme.builder()
                .id(UUID.randomUUID())
                .orgId(orgId)
                .name("Bulk Net Rate @ Rs 75")
                .schemeType("SPECIAL_NET_RATE")
                .itemId(itemId)
                .minOrderQuantity(new BigDecimal("50"))
                .specialNetRate(new BigDecimal("75.00"))
                .companySubsidyPercent(new BigDecimal("100.00"))
                .active(true)
                .build();

        when(schemeRepository.findApplicable(eq(orgId), eq(itemId), any(LocalDate.class)))
                .thenReturn(List.of(scheme));

        SchemeEvaluationRequest req = new SchemeEvaluationRequest(
                itemId,
                new BigDecimal("50"),
                new BigDecimal("100.00"), // Base PTR 100
                null
        );

        SchemeCalculationResult res = schemeService.evaluateScheme(req);

        assertThat(res).isNotNull();
        assertThat(res.effectiveUnitPrice()).isEqualByComparingTo("75.00");
        assertThat(res.totalLineAmount()).isEqualByComparingTo("3750.00");
        assertThat(res.discountAmount()).isEqualByComparingTo("1250.00");
        assertThat(res.companyFundedAmount()).isEqualByComparingTo("1250.00");
    }

    @Test
    void evaluateScheme_freeQuantityCap_respectsUpperLimit() {
        Scheme scheme = Scheme.builder()
                .id(UUID.randomUUID())
                .orgId(orgId)
                .name("10+1 Capped at 5 Free")
                .schemeType("BUY_X_GET_Y")
                .itemId(itemId)
                .buyQuantity(new BigDecimal("10"))
                .freeQuantity(new BigDecimal("1"))
                .maxFreeQuantityCap(new BigDecimal("5"))
                .active(true)
                .build();

        when(schemeRepository.findApplicable(eq(orgId), eq(itemId), any(LocalDate.class)))
                .thenReturn(List.of(scheme));

        // Ordering 100 units would yield 10 free, but capped at 5
        SchemeEvaluationRequest req = new SchemeEvaluationRequest(
                itemId,
                new BigDecimal("100"),
                new BigDecimal("50.00"),
                null
        );

        SchemeCalculationResult res = schemeService.evaluateScheme(req);

        assertThat(res).isNotNull();
        assertThat(res.freeQuantity()).isEqualByComparingTo("5");
    }
}
