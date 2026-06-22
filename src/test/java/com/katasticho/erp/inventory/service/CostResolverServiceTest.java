package com.katasticho.erp.inventory.service;

import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.organisation.OrgSettingsService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link CostResolverService} — the precedence ladder for
 * resolving a sale movement's unit cost when the item has no known purchase
 * price (bill-freely path).
 */
@ExtendWith(MockitoExtension.class)
class CostResolverServiceTest {

    @Mock private OrgSettingsService orgSettingsService;

    private CostResolverService service;
    private UUID orgId;

    @BeforeEach
    void setUp() {
        service = new CostResolverService(orgSettingsService);
        orgId = UUID.randomUUID();
        // Default-margin path — overridden per-test as needed.
        lenient().when(orgSettingsService.get(eq(orgId), eq("inventory.provisional_margin_pct"), anyString()))
                .thenReturn("0.25");
    }

    @Test
    void returnsPurchasePriceNonProvisional_whenPurchasePriceSet() {
        Item item = Item.builder()
                .purchasePrice(new BigDecimal("20.00"))
                .mrp(new BigDecimal("30.00"))
                .salePrice(new BigDecimal("25.00"))
                .build();

        CostResolverService.CostBasis basis = service.resolve(item, orgId);

        assertThat(basis).isNotNull();
        assertThat(basis.unitCost()).isEqualByComparingTo("20.00");
        assertThat(basis.provisional()).isFalse();
        assertThat(basis.source()).isEqualTo("PURCHASE_PRICE");
        // Should NOT bother loading the margin setting when purchase price is set.
        verify(orgSettingsService, never()).get(eq(orgId), anyString(), anyString());
    }

    @Test
    void fallsBackToMrpMinusMargin_whenPurchasePriceMissing() {
        Item item = Item.builder()
                .purchasePrice(BigDecimal.ZERO)  // null-equivalent in this codebase (NOT NULL DEFAULT 0)
                .mrp(new BigDecimal("100.00"))
                .salePrice(new BigDecimal("90.00"))
                .build();

        CostResolverService.CostBasis basis = service.resolve(item, orgId);

        assertThat(basis).isNotNull();
        // 100 × (1 − 0.25) = 75.0000
        assertThat(basis.unitCost()).isEqualByComparingTo("75.0000");
        assertThat(basis.provisional()).isTrue();
        assertThat(basis.source()).isEqualTo("MRP_MINUS_MARGIN");
    }

    @Test
    void fallsBackToSalePriceMinusMargin_whenPurchasePriceAndMrpMissing() {
        Item item = Item.builder()
                .purchasePrice(BigDecimal.ZERO)
                .mrp(null)
                .salePrice(new BigDecimal("80.00"))
                .build();

        CostResolverService.CostBasis basis = service.resolve(item, orgId);

        assertThat(basis).isNotNull();
        // 80 × 0.75 = 60.0000
        assertThat(basis.unitCost()).isEqualByComparingTo("60.0000");
        assertThat(basis.provisional()).isTrue();
        assertThat(basis.source()).isEqualTo("SALE_PRICE_MINUS_MARGIN");
    }

    @Test
    void returnsNull_whenNothingIsSet() {
        Item item = Item.builder()
                .purchasePrice(BigDecimal.ZERO)
                .mrp(null)
                .salePrice(BigDecimal.ZERO)
                .build();

        assertThat(service.resolve(item, orgId)).isNull();
    }

    @Test
    void appliesCustomMarginFromOrgSetting() {
        when(orgSettingsService.get(eq(orgId), eq("inventory.provisional_margin_pct"), anyString()))
                .thenReturn("0.30");

        Item item = Item.builder()
                .purchasePrice(BigDecimal.ZERO)
                .mrp(new BigDecimal("100.00"))
                .build();

        CostResolverService.CostBasis basis = service.resolve(item, orgId);

        assertThat(basis).isNotNull();
        // 100 × (1 − 0.30) = 70.0000
        assertThat(basis.unitCost()).isEqualByComparingTo("70.0000");
        assertThat(basis.provisional()).isTrue();
    }
}
