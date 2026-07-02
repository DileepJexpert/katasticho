package com.katasticho.erp.tax;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.tax.entity.TaxConfiguration;
import com.katasticho.erp.tax.entity.TaxGroup;
import com.katasticho.erp.tax.entity.TaxRate;
import com.katasticho.erp.tax.repository.TaxConfigurationRepository;
import com.katasticho.erp.tax.repository.TaxGroupRateRepository;
import com.katasticho.erp.tax.repository.TaxGroupRepository;
import com.katasticho.erp.tax.repository.TaxRateRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TaxSeedServiceTest {

    @Mock private TaxConfigurationRepository configRepo;
    @Mock private TaxRateRepository rateRepo;
    @Mock private TaxGroupRepository groupRepo;
    @Mock private TaxGroupRateRepository groupRateRepo;
    @Mock private AccountRepository accountRepo;

    private TaxSeedService service;

    @BeforeEach
    void setUp() {
        service = new TaxSeedService(configRepo, rateRepo, groupRepo, groupRateRepo, accountRepo);
        lenient().when(configRepo.existsByOrgId(any())).thenReturn(false);
        lenient().when(configRepo.save(any())).thenAnswer(inv -> {
            TaxConfiguration c = inv.getArgument(0);
            if (c.getId() == null) c.setId(UUID.randomUUID());
            return c;
        });
        lenient().when(rateRepo.save(any())).thenAnswer(inv -> {
            TaxRate r = inv.getArgument(0);
            if (r.getId() == null) r.setId(UUID.randomUUID());
            return r;
        });
        lenient().when(groupRepo.save(any())).thenAnswer(inv -> {
            TaxGroup g = inv.getArgument(0);
            if (g.getId() == null) g.setId(UUID.randomUUID());
            return g;
        });
        lenient().when(groupRateRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));
        lenient().when(accountRepo.findByOrgIdAndCodeAndIsDeletedFalse(any(), any()))
                .thenReturn(Optional.empty());
        lenient().when(accountRepo.save(any())).thenAnswer(inv -> {
            Account a = inv.getArgument(0);
            if (a.getId() == null) a.setId(UUID.randomUUID());
            return a;
        });
    }

    private Organisation org(String country, String currency) {
        return Organisation.builder()
                .id(UUID.randomUUID()).name("Test Org")
                .countryCode(country).baseCurrency(currency)
                .build();
    }

    @Test
    @DisplayName("Oman seeds flat 5% VAT against the Gulf 2041/1511 accounts in OMR")
    void omanSeedsFivePercentVat() {
        service.seedForOrg(org("OM", "OMR"));

        ArgumentCaptor<TaxConfiguration> config = ArgumentCaptor.forClass(TaxConfiguration.class);
        verify(configRepo).save(config.capture());
        assertThat(config.getValue().getCountryCode()).isEqualTo("OM");
        assertThat(config.getValue().getName()).isEqualTo("Oman VAT");
        assertThat(config.getValue().getTaxSystem()).isEqualTo("VAT");

        ArgumentCaptor<TaxRate> rates = ArgumentCaptor.forClass(TaxRate.class);
        verify(rateRepo).save(rates.capture());
        assertThat(rates.getValue().getPercentage()).isEqualByComparingTo(new BigDecimal("5.00"));

        ArgumentCaptor<Account> accounts = ArgumentCaptor.forClass(Account.class);
        verify(accountRepo, org.mockito.Mockito.times(2)).save(accounts.capture());
        List<String> codes = accounts.getAllValues().stream().map(Account::getCode).toList();
        assertThat(codes).containsExactlyInAnyOrder("2041", "1511");
        assertThat(accounts.getAllValues()).allSatisfy(a ->
                assertThat(a.getCurrency()).isEqualTo("OMR"));
    }

    @Test
    @DisplayName("Kenya seeds 16% standard + zero-rated VAT")
    void kenyaSeedsSixteenPercentVat() {
        service.seedForOrg(org("KE", "KES"));

        ArgumentCaptor<TaxConfiguration> config = ArgumentCaptor.forClass(TaxConfiguration.class);
        verify(configRepo).save(config.capture());
        assertThat(config.getValue().getCountryCode()).isEqualTo("KE");
        assertThat(config.getValue().getName()).isEqualTo("Kenya VAT");

        ArgumentCaptor<TaxRate> rates = ArgumentCaptor.forClass(TaxRate.class);
        verify(rateRepo, org.mockito.Mockito.times(2)).save(rates.capture());
        List<BigDecimal> percents = rates.getAllValues().stream().map(TaxRate::getPercentage).toList();
        assertThat(percents).anySatisfy(pc -> assertThat(pc).isEqualByComparingTo("16.00"));
        assertThat(percents).anySatisfy(pc -> assertThat(pc).isEqualByComparingTo("0.00"));
    }

    @Test
    @DisplayName("UAE still seeds through the shared Gulf path with its own labels")
    void uaeSeedsThroughGulfPath() {
        service.seedForOrg(org("AE", "AED"));

        ArgumentCaptor<TaxConfiguration> config = ArgumentCaptor.forClass(TaxConfiguration.class);
        verify(configRepo).save(config.capture());
        assertThat(config.getValue().getCountryCode()).isEqualTo("AE");
        assertThat(config.getValue().getName()).isEqualTo("UAE VAT");

        ArgumentCaptor<Account> accounts = ArgumentCaptor.forClass(Account.class);
        verify(accountRepo, org.mockito.Mockito.times(2)).save(accounts.capture());
        assertThat(accounts.getAllValues()).allSatisfy(a ->
                assertThat(a.getCurrency()).isEqualTo("AED"));
    }

    @Test
    @DisplayName("UK VAT output no longer collides with 2042 Stock-Out Suspense")
    void ukVatUsesNonCollidingCode() {
        service.seedForOrg(org("GB", "GBP"));

        ArgumentCaptor<Account> accounts = ArgumentCaptor.forClass(Account.class);
        verify(accountRepo, org.mockito.Mockito.times(2)).save(accounts.capture());
        List<String> codes = accounts.getAllValues().stream().map(Account::getCode).toList();
        assertThat(codes).contains("2045").doesNotContain("2042");
    }

    @Test
    @DisplayName("US sales tax no longer collides with 2050 PF/Gratuity")
    void usSalesTaxUsesNonCollidingCode() {
        service.seedForOrg(org("US", "USD"));

        ArgumentCaptor<Account> accounts = ArgumentCaptor.forClass(Account.class);
        verify(accountRepo).save(accounts.capture());
        assertThat(accounts.getValue().getCode()).isEqualTo("2046").isNotEqualTo("2050");
    }
}
