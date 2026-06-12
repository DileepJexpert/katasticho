package com.katasticho.erp.common.currency.controller;

import com.katasticho.erp.common.currency.entity.Currency;
import com.katasticho.erp.common.currency.entity.ExchangeRate;
import com.katasticho.erp.common.currency.service.CurrencyManagementService;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/currencies")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
public class CurrencyController {

    private final CurrencyManagementService service;

    /** List all active currencies. */
    @GetMapping
    public ApiResponse<List<Currency>> listCurrencies() {
        return ApiResponse.ok(service.listCurrencies());
    }

    /** List exchange rates for a base currency (defaults to INR). */
    @GetMapping("/rates")
    public ApiResponse<List<ExchangeRate>> listRates(
            @RequestParam(defaultValue = "INR") String base) {
        return ApiResponse.ok(service.listRates(base));
    }

    /** Set / upsert an exchange rate. */
    @PostMapping("/rates")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ApiResponse<ExchangeRate> setRate(@RequestBody Map<String, Object> body) {
        String from  = (String) body.get("fromCurrency");
        String to    = (String) body.get("toCurrency");
        BigDecimal rate = new BigDecimal(body.get("rate").toString());
        LocalDate date  = body.containsKey("effectiveDate")
                ? LocalDate.parse((String) body.get("effectiveDate"))
                : LocalDate.now();
        return ApiResponse.ok(service.setExchangeRate(from, to, rate, date));
    }

    /** Convert an amount between two currencies. */
    @GetMapping("/convert")
    public ApiResponse<Map<String, Object>> convert(
            @RequestParam BigDecimal amount,
            @RequestParam String from,
            @RequestParam String to,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        LocalDate effectiveDate = date != null ? date : LocalDate.now();
        BigDecimal converted = service.convert(amount, from, to, effectiveDate);
        return ApiResponse.ok(Map.of(
                "from", from,
                "to", to,
                "inputAmount", amount,
                "convertedAmount", converted,
                "date", effectiveDate.toString()
        ));
    }
}
