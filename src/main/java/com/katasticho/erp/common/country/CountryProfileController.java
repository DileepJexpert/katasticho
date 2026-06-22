package com.katasticho.erp.common.country;

import com.katasticho.erp.common.currency.repository.CurrencyRepository;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.DayOfWeek;
import java.util.Comparator;
import java.util.List;

/**
 * Exposes the current org's resolved {@link CountryProfile} so the Flutter
 * client can localize per country WITHOUT hardcoding India assumptions:
 * the tax-id label ("GSTIN" vs "TRN" vs "PIN"), the currency symbol + decimal
 * places, the weekend days, the fiscal-year start, and the default locales.
 *
 * <p>Deliberately NOT module-gated and open to every role — every org needs its
 * own country settings to render forms (mirrors {@code StateCodeController}).
 */
@RestController
@RequestMapping("/api/v1/reference/country-profile")
@RequiredArgsConstructor
public class CountryProfileController {

    private final CountryAccessService countryAccessService;
    private final CountryRegistry countryRegistry;
    private final CurrencyRepository currencyRepository;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<CountryProfileResponse>> current() {
        CountryProfile p = countryRegistry.get(countryAccessService.currentCountry());
        String symbol = currencyRepository.findByCode(p.currencyCode())
                .map(c -> c.getSymbol())
                .orElse(p.currencyCode());
        List<String> weekend = p.weekendDays().stream()
                .sorted(Comparator.comparingInt(DayOfWeek::getValue))
                .map(Enum::name)
                .toList();
        return ResponseEntity.ok(ApiResponse.ok(new CountryProfileResponse(
                p.code(),
                p.displayName(),
                p.currencyCode(),
                symbol,
                p.currencyDecimals(),
                p.taxIdLabel(),
                p.defaultLocales(),
                weekend,
                p.fiscalYearStartMonth())));
    }

    /** The org's country settings the Flutter client renders forms from. */
    public record CountryProfileResponse(
            String countryCode,
            String displayName,
            String currencyCode,
            String currencySymbol,
            int currencyDecimals,
            String taxIdLabel,
            List<String> defaultLocales,
            List<String> weekendDays,
            int fiscalYearStartMonth) {}
}
