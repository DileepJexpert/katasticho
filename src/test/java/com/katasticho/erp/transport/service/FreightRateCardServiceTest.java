package com.katasticho.erp.transport.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.transport.dto.TransportDtos.RateQuoteResponse;
import com.katasticho.erp.transport.entity.FreightRateCard;
import com.katasticho.erp.transport.repository.FreightRateCardRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class FreightRateCardServiceTest {

    @Mock private FreightRateCardRepository repository;
    private FreightRateCardService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID transporter = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new FreightRateCardService(repository);
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    private FreightRateCard card(String origin, String dest, String rateType, String rate,
                                 String min, String slabMin, String slabMax) {
        FreightRateCard c = FreightRateCard.builder()
                .transporterContactId(transporter).origin(origin).destination(dest).mode("ROAD")
                .rateType(rateType).rate(new BigDecimal(rate)).minCharge(new BigDecimal(min))
                .weightSlabMinKg(new BigDecimal(slabMin))
                .weightSlabMaxKg(slabMax == null ? null : new BigDecimal(slabMax))
                .active(true).build();
        c.setId(UUID.randomUUID());
        c.setOrgId(orgId);
        c.setCreatedAt(Instant.now());
        return c;
    }

    @Test
    void resolve_perKg_multipliesByWeight() {
        when(repository.findByOrgIdAndTransporterContactIdAndModeAndActiveTrueAndIsDeletedFalse(
                eq(orgId), eq(transporter), eq("ROAD")))
                .thenReturn(List.of(card("Mumbai", "Pune", "PER_KG", "8", "0", "0", null)));

        RateQuoteResponse q = service.resolveRate(transporter, "Mumbai", "Pune", "ROAD", new BigDecimal("100"));

        assertThat(q.found()).isTrue();
        assertThat(q.freightAmount()).isEqualByComparingTo("800"); // 8 × 100
    }

    @Test
    void resolve_perKg_appliesMinChargeFloor() {
        when(repository.findByOrgIdAndTransporterContactIdAndModeAndActiveTrueAndIsDeletedFalse(
                eq(orgId), eq(transporter), eq("ROAD")))
                .thenReturn(List.of(card("Mumbai", "Pune", "PER_KG", "8", "500", "0", null)));

        RateQuoteResponse q = service.resolveRate(transporter, "Mumbai", "Pune", "ROAD", new BigDecimal("10"));

        assertThat(q.freightAmount()).isEqualByComparingTo("500"); // 8×10=80 floored to 500
    }

    @Test
    void resolve_flat_ignoresWeight() {
        when(repository.findByOrgIdAndTransporterContactIdAndModeAndActiveTrueAndIsDeletedFalse(
                eq(orgId), eq(transporter), eq("ROAD")))
                .thenReturn(List.of(card("Mumbai", "Delhi", "FLAT", "3500", "0", "0", null)));

        RateQuoteResponse q = service.resolveRate(transporter, "Mumbai", "Delhi", "ROAD", new BigDecimal("250"));

        assertThat(q.freightAmount()).isEqualByComparingTo("3500");
    }

    @Test
    void resolve_picksMatchingWeightSlab() {
        // Two slabs: 0–50 @ ₹10/kg, 50+ @ ₹6/kg. A 120kg parcel hits the open slab.
        when(repository.findByOrgIdAndTransporterContactIdAndModeAndActiveTrueAndIsDeletedFalse(
                eq(orgId), eq(transporter), eq("ROAD")))
                .thenReturn(List.of(
                        card("Mumbai", "Pune", "PER_KG", "10", "0", "0", "50"),
                        card("Mumbai", "Pune", "PER_KG", "6", "0", "50", null)));

        RateQuoteResponse q = service.resolveRate(transporter, "Mumbai", "Pune", "ROAD", new BigDecimal("120"));

        assertThat(q.freightAmount()).isEqualByComparingTo("720"); // 6 × 120, not 10
    }

    @Test
    void resolve_noLaneMatch_returnsNotFound() {
        when(repository.findByOrgIdAndTransporterContactIdAndModeAndActiveTrueAndIsDeletedFalse(
                eq(orgId), eq(transporter), eq("ROAD")))
                .thenReturn(List.of(card("Mumbai", "Pune", "PER_KG", "8", "0", "0", null)));

        RateQuoteResponse q = service.resolveRate(transporter, "Chennai", "Bengaluru", "ROAD", new BigDecimal("50"));

        assertThat(q.found()).isFalse();
        assertThat(q.freightAmount()).isEqualByComparingTo("0");
    }
}
