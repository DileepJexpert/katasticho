package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.UomConversion;
import com.katasticho.erp.inventory.repository.UomConversionRepository;
import com.katasticho.erp.inventory.repository.UomRepository;
import com.katasticho.erp.organisation.IndustryFeatureConfigRepository;
import com.katasticho.erp.organisation.IndustryTemplateRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/**
 * Unit tests for the core UoM conversion engine. These tests are the
 * first gate on Feature 1 (UoM foundation) — every downstream v2
 * feature (FEFO selling, BOM, price lists, stock count) will route
 * through {@link UomService#convert} so the resolution order
 * (identity -> per-item override -> org-wide -> fail) MUST stay
 * stable.
 */
@ExtendWith(MockitoExtension.class)
class UomServiceTest {

    @Mock private UomRepository uomRepository;
    @Mock private UomConversionRepository uomConversionRepository;
    @Mock private IndustryTemplateRepository industryTemplateRepository;
    @Mock private IndustryFeatureConfigRepository featureConfigRepository;

    private UomService uomService;
    private UUID orgId;
    private UUID userId;

    @BeforeEach
    void setUp() {
        uomService = new UomService(uomRepository, uomConversionRepository,
                industryTemplateRepository, featureConfigRepository);
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
    void identity_returnsSameQuantityWithoutHittingRepository() {
        UUID kg = UUID.randomUUID();

        BigDecimal result = uomService.convert(new BigDecimal("2.5"), kg, kg, null);

        assertEquals(0, new BigDecimal("2.5").compareTo(result));
        verifyNoInteractions(uomConversionRepository);
    }

    @Test
    void orgWide_kgToGm_multipliesByThousand() {
        UUID kg = UUID.randomUUID();
        UUID gm = UUID.randomUUID();
        UomConversion orgRule = UomConversion.builder()
                .fromUomId(kg)
                .toUomId(gm)
                .factor(new BigDecimal("1000"))
                .build();

        when(uomConversionRepository.findOrgWide(orgId, kg, gm))
                .thenReturn(Optional.of(orgRule));

        BigDecimal result = uomService.convert(new BigDecimal("2.5"), kg, gm, null);

        assertEquals(0, new BigDecimal("2500").compareTo(result),
                "2.5 KG should equal 2500 GM");
        verify(uomConversionRepository).findOrgWide(orgId, kg, gm);
    }

    @Test
    void perItemOverride_boxToStrip_beatsOrgWide() {
        UUID box = UUID.randomUUID();
        UUID strip = UUID.randomUUID();
        UUID paracetamolId = UUID.randomUUID();

        UomConversion perItem = UomConversion.builder()
                .itemId(paracetamolId)
                .fromUomId(box)
                .toUomId(strip)
                .factor(new BigDecimal("10"))
                .build();

        when(uomConversionRepository.findPerItem(orgId, paracetamolId, box, strip))
                .thenReturn(Optional.of(perItem));

        BigDecimal result = uomService.convert(
                new BigDecimal("3"), box, strip, paracetamolId);

        assertEquals(0, new BigDecimal("30").compareTo(result),
                "3 BOX of paracetamol should equal 30 STRIP");

        // Per-item hit short-circuits — org-wide must not be queried.
        verify(uomConversionRepository).findPerItem(orgId, paracetamolId, box, strip);
        verify(uomConversionRepository, never()).findOrgWide(any(), any(), any());
    }

    @Test
    void perItemMiss_fallsThroughToOrgWide() {
        UUID box = UUID.randomUUID();
        UUID strip = UUID.randomUUID();
        UUID someItemId = UUID.randomUUID();

        UomConversion orgRule = UomConversion.builder()
                .fromUomId(box)
                .toUomId(strip)
                .factor(new BigDecimal("10"))
                .build();

        when(uomConversionRepository.findPerItem(orgId, someItemId, box, strip))
                .thenReturn(Optional.empty());
        when(uomConversionRepository.findOrgWide(orgId, box, strip))
                .thenReturn(Optional.of(orgRule));

        BigDecimal result = uomService.convert(
                new BigDecimal("2"), box, strip, someItemId);

        assertEquals(0, new BigDecimal("20").compareTo(result));
        verify(uomConversionRepository).findPerItem(orgId, someItemId, box, strip);
        verify(uomConversionRepository).findOrgWide(orgId, box, strip);
    }

    @Test
    void noConversionRule_throwsBusinessException() {
        UUID a = UUID.randomUUID();
        UUID b = UUID.randomUUID();

        when(uomConversionRepository.findOrgWide(orgId, a, b))
                .thenReturn(Optional.empty());

        BusinessException ex = assertThrows(BusinessException.class,
                () -> uomService.convert(BigDecimal.ONE, a, b, null));

        assertEquals("UOM_NO_CONVERSION", ex.getErrorCode());
    }

    @Test
    void nullQuantity_throwsBusinessException() {
        UUID a = UUID.randomUUID();
        UUID b = UUID.randomUUID();

        BusinessException ex = assertThrows(BusinessException.class,
                () -> uomService.convert(null, a, b, null));

        assertEquals("UOM_QTY_REQUIRED", ex.getErrorCode());
    }

    @Test
    void factorLookup_identityReturnsOne() {
        UUID kg = UUID.randomUUID();
        assertEquals(0, BigDecimal.ONE.compareTo(uomService.factor(kg, kg, null)));
        verifyNoInteractions(uomConversionRepository);
    }
}
