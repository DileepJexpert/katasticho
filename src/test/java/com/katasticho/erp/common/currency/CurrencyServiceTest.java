package com.katasticho.erp.common.currency;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.currency.entity.Currency;
import com.katasticho.erp.common.currency.entity.ExchangeRate;
import com.katasticho.erp.common.currency.repository.CurrencyRepository;
import com.katasticho.erp.common.currency.repository.ExchangeRateRepository;
import com.katasticho.erp.common.currency.service.CurrencyManagementService;
import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockedStatic;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CurrencyServiceTest {

    @Mock private CurrencyRepository currencyRepo;
    @Mock private ExchangeRateRepository exchangeRateRepo;

    @InjectMocks private CurrencyManagementService service;

    private MockedStatic<TenantContext> tenantMock;
    private final UUID ORG_ID = UUID.randomUUID();
    private final LocalDate TODAY = LocalDate.of(2026, 6, 11);

    @BeforeEach
    void setUp() {
        tenantMock = mockStatic(TenantContext.class);
        tenantMock.when(TenantContext::getCurrentOrgId).thenReturn(ORG_ID);
    }

    @AfterEach
    void tearDown() {
        tenantMock.close();
    }

    // ── Test 1: listCurrencies returns active currencies ─────────────────────

    @Test
    void listCurrencies_returnsActiveOnly() {
        Currency inr = Currency.builder().code("INR").name("Indian Rupee").isActive(true).build();
        Currency usd = Currency.builder().code("USD").name("US Dollar").isActive(true).build();
        when(currencyRepo.findByIsActiveTrue()).thenReturn(List.of(inr, usd));

        List<Currency> result = service.listCurrencies();

        assertThat(result).hasSize(2);
        assertThat(result).extracting(Currency::getCode).containsExactly("INR", "USD");
    }

    // ── Test 2: convert using stored rate ────────────────────────────────────

    @Test
    void convert_usesStoredRate() {
        ExchangeRate rate = ExchangeRate.builder()
                .fromCurrency("USD").toCurrency("INR")
                .rate(new BigDecimal("83.5")).effectiveDate(TODAY).build();
        when(exchangeRateRepo.findLatestRate(ORG_ID, "USD", "INR", TODAY))
                .thenReturn(Optional.of(rate));

        BigDecimal result = service.convert(new BigDecimal("100"), "USD", "INR", TODAY);

        // 100 * 83.5 = 8350.00
        assertThat(result).isEqualByComparingTo(new BigDecimal("8350.00"));
    }

    // ── Test 3: same-currency conversion returns identity ────────────────────

    @Test
    void convert_sameCurrency_returnsIdentity() {
        BigDecimal result = service.convert(new BigDecimal("500"), "INR", "INR", TODAY);

        assertThat(result).isEqualByComparingTo(new BigDecimal("500.00"));
        verifyNoInteractions(exchangeRateRepo);
    }

    // ── Test 4: fallback to latest rate when no exact date match ─────────────

    @Test
    void getExchangeRate_fallsBackToLatestRate() {
        LocalDate older = TODAY.minusDays(5);
        ExchangeRate rate = ExchangeRate.builder()
                .fromCurrency("EUR").toCurrency("INR")
                .rate(new BigDecimal("90.2")).effectiveDate(older).build();
        // No exact date, but findLatestRate returns the most recent available
        when(exchangeRateRepo.findLatestRate(ORG_ID, "EUR", "INR", TODAY))
                .thenReturn(Optional.of(rate));

        BigDecimal result = service.getExchangeRate("EUR", "INR", TODAY);

        assertThat(result).isEqualByComparingTo(new BigDecimal("90.2"));
    }

    // ── Test 5: throws when no rate found ────────────────────────────────────

    @Test
    void getExchangeRate_throwsWhenNotFound() {
        when(exchangeRateRepo.findLatestRate(any(), any(), any(), any()))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.getExchangeRate("GBP", "INR", TODAY))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("No exchange rate found");
    }

    // ── Test 6: setExchangeRate upserts correctly ─────────────────────────────

    @Test
    void setExchangeRate_createsNewRecord() {
        when(exchangeRateRepo
                .findByOrgIdAndFromCurrencyAndToCurrencyAndEffectiveDateAndIsDeletedFalse(
                        ORG_ID, "USD", "INR", TODAY))
                .thenReturn(Optional.empty());
        when(exchangeRateRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        ExchangeRate result = service.setExchangeRate("USD", "INR", new BigDecimal("84.0"), TODAY);

        assertThat(result.getFromCurrency()).isEqualTo("USD");
        assertThat(result.getToCurrency()).isEqualTo("INR");
        assertThat(result.getRate()).isEqualByComparingTo(new BigDecimal("84.0"));
        assertThat(result.getSource()).isEqualTo("MANUAL");
    }

    @Test
    void setExchangeRate_updatesExisting() {
        ExchangeRate existing = ExchangeRate.builder()
                .fromCurrency("USD").toCurrency("INR")
                .rate(new BigDecimal("83.0")).effectiveDate(TODAY).source("MANUAL").build();
        when(exchangeRateRepo
                .findByOrgIdAndFromCurrencyAndToCurrencyAndEffectiveDateAndIsDeletedFalse(
                        ORG_ID, "USD", "INR", TODAY))
                .thenReturn(Optional.of(existing));
        when(exchangeRateRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        ExchangeRate result = service.setExchangeRate("USD", "INR", new BigDecimal("84.5"), TODAY);

        assertThat(result.getRate()).isEqualByComparingTo(new BigDecimal("84.5"));
        verify(exchangeRateRepo, times(1)).save(existing);
    }

    // ── Test 7: invalid rate throws ──────────────────────────────────────────

    @Test
    void setExchangeRate_throwsForZeroRate() {
        assertThatThrownBy(() -> service.setExchangeRate("USD", "INR", BigDecimal.ZERO, TODAY))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("positive");
    }
}
