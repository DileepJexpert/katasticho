package com.katasticho.erp.payment.service;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PayoutGatewayClient {

    public static final String KEY_ID = "payouts.razorpayx.key_id";
    public static final String KEY_SECRET = "payouts.razorpayx.key_secret";
    public static final String ACCOUNT_NUMBER = "payouts.razorpayx.account_number";
    public static final String ENABLED = "payouts.enabled";
    public static final String BASE_URL = "payouts.razorpayx.base_url";
    private static final String DEFAULT_BASE_URL = "https://api.razorpay.com";

    private final OrgSettingsService orgSettingsService;
    private final RestTemplate gspRestTemplate;

    public record PayoutGatewayResult(
        boolean success,
        String providerPayoutId,
        String utr,
        String status,
        String failureReason
    ) {}

    public PayoutGatewayResult disburse(
            UUID orgId,
            BigDecimal amount,
            String currency,
            String payoutMode,
            String beneficiaryName,
            String accountNumber,
            String ifscCode,
            String vpa,
            String narration
    ) {
        boolean enabled = Boolean.parseBoolean(orgSettingsService.get(orgId, ENABLED, "false"));
        String keyId = orgSettingsService.get(orgId, KEY_ID, null);
        String keySecret = orgSettingsService.get(orgId, KEY_SECRET, null);
        String debitAccount = orgSettingsService.get(orgId, ACCOUNT_NUMBER, null);

        // A missing or test configuration must never clear a payable or post a
        // journal. Production payouts are opt-in and fail closed.
        if (!enabled) {
            return new PayoutGatewayResult(false, null, null, "NOT_CONFIGURED",
                    "Payouts are disabled for this organisation");
        }
        if (keyId == null || keyId.isBlank() || keySecret == null || keySecret.isBlank()
                || debitAccount == null || debitAccount.isBlank()) {
            return new PayoutGatewayResult(false, null, null, "NOT_CONFIGURED",
                    "RazorpayX credentials and source account are required before payouts can be enabled");
        }
        if (keyId.startsWith("test_")) {
            return new PayoutGatewayResult(false, null, null, "NOT_CONFIGURED",
                    "Test gateway credentials cannot be used for financial disbursements");
        }

        // Live Gateway Integration (RazorpayX API)
        try {
            log.info("[PayoutGatewayClient] Executing live RazorpayX payout of ₹{} via {} for org {}",
                    amount, payoutMode, orgId);

            String baseUrl = orgSettingsService.get(orgId, BASE_URL, DEFAULT_BASE_URL);
            String url = (baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl) + "/v1/payouts";

            Map<String, Object> body = new LinkedHashMap<>();
            body.put("account_number", debitAccount != null ? debitAccount.trim() : "");
            long amountPaise = amount.multiply(BigDecimal.valueOf(100)).longValue();
            body.put("amount", amountPaise);
            body.put("currency", currency != null && !currency.isBlank() ? currency : "INR");
            body.put("mode", payoutMode != null ? payoutMode.toUpperCase(Locale.ROOT) : "NEFT");
            body.put("purpose", "payout");
            body.put("narration", narration != null && !narration.isBlank() ? narration : "Vendor Bill Payment");

            Map<String, Object> fundAccount = new LinkedHashMap<>();
            if (vpa != null && !vpa.isBlank()) {
                fundAccount.put("account_type", "vpa");
                Map<String, Object> vpaObj = new LinkedHashMap<>();
                vpaObj.put("address", vpa.trim());
                fundAccount.put("vpa", vpaObj);
            } else {
                fundAccount.put("account_type", "bank_account");
                Map<String, Object> bankObj = new LinkedHashMap<>();
                bankObj.put("name", beneficiaryName != null ? beneficiaryName : "Beneficiary");
                bankObj.put("ifsc", ifscCode != null ? ifscCode.trim() : "");
                bankObj.put("account_number", accountNumber != null ? accountNumber.trim() : "");
                fundAccount.put("bank_account", bankObj);
            }
            body.put("fund_account", fundAccount);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBasicAuth(keyId.trim(), keySecret != null ? keySecret.trim() : "");

            @SuppressWarnings("rawtypes")
            ResponseEntity<Map> resp = gspRestTemplate.exchange(
                    url, HttpMethod.POST, new HttpEntity<>(body, headers), Map.class);

            Map respBody = resp.getBody();
            if (respBody == null) {
                return new PayoutGatewayResult(false, null, null, "FAILED", "Gateway returned empty response body");
            }

            String payoutId = respBody.get("id") != null ? respBody.get("id").toString() : null;
            String utr = respBody.get("utr") != null ? respBody.get("utr").toString() : payoutId;
            String status = respBody.get("status") != null ? respBody.get("status").toString().toUpperCase(Locale.ROOT) : "PROCESSED";
            String failureReason = respBody.get("failure_reason") != null ? respBody.get("failure_reason").toString() : null;

            // PROCESSING and QUEUED are provider acknowledgements, not settled
            // money. Accounting must wait for a final successful callback or
            // reconciliation result.
            boolean success = "PROCESSED".equals(status);
            return new PayoutGatewayResult(success, payoutId, utr, status, failureReason);

        } catch (HttpStatusCodeException e) {
            String errorMsg = "HTTP " + e.getStatusCode() + ": " + e.getResponseBodyAsString();
            log.error("[PayoutGatewayClient] RazorpayX live payout rejected for org {}: {}", orgId, errorMsg);
            return new PayoutGatewayResult(false, null, null, "FAILED", errorMsg);
        } catch (Exception e) {
            log.error("[PayoutGatewayClient] Live payout error for org {}: {}", orgId, e.getMessage());
            return new PayoutGatewayResult(false, null, null, "FAILED", e.getMessage());
        }
    }
}
