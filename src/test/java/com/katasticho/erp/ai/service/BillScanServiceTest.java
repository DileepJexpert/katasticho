package com.katasticho.erp.ai.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.dto.BillScanResponse;
import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BillScanServiceTest {

    @Mock private ClaudeApiClient claudeApiClient;

    private BillScanService billScanService;

    @BeforeEach
    void setUp() {
        billScanService = new BillScanService(claudeApiClient, new ObjectMapper());
    }

    @Test
    @DisplayName("T-AI-17: Parses valid bill scan response")
    void parsesValidResponse() {
        String claudeResponse = """
                {
                  "vendorName": "ABC Trading Co.",
                  "vendorGstin": "29AABCT1332L1ZM",
                  "invoiceNumber": "INV-2025-001",
                  "invoiceDate": "2025-03-15",
                  "dueDate": "2025-04-14",
                  "subtotal": 10000.00,
                  "taxAmount": 1800.00,
                  "totalAmount": 11800.00,
                  "currency": "INR",
                  "lineItems": [
                    {
                      "lineNumber": 1,
                      "description": "Cotton Fabric 40s",
                      "hsnCode": "5208",
                      "quantity": 100,
                      "unitPrice": 100.00,
                      "amount": 10000.00,
                      "gstRate": 18
                    }
                  ],
                  "taxDetails": {
                    "cgst": 900.00,
                    "sgst": 900.00,
                    "igst": null,
                    "taxRegime": "INDIA_GST"
                  },
                  "confidence": 0.95
                }
                """;

        when(claudeApiClient.sendMessageWithImage(anyString(), anyString(), anyString(), anyString()))
                .thenReturn(claudeResponse);

        BillScanResponse result = billScanService.scanBill("base64data", "image/jpeg");

        assertThat(result.vendorName()).isEqualTo("ABC Trading Co.");
        assertThat(result.vendorGstin()).isEqualTo("29AABCT1332L1ZM");
        assertThat(result.invoiceNumber()).isEqualTo("INV-2025-001");
        assertThat(result.totalAmount()).isEqualByComparingTo(new BigDecimal("11800.00"));
        assertThat(result.lineItems()).hasSize(1);
        assertThat(result.lineItems().get(0).description()).isEqualTo("Cotton Fabric 40s");
        assertThat(result.lineItems().get(0).hsnCode()).isEqualTo("5208");
        assertThat(result.taxDetails().cgst()).isEqualByComparingTo(new BigDecimal("900.00"));
        assertThat(result.taxDetails().sgst()).isEqualByComparingTo(new BigDecimal("900.00"));
        assertThat(result.confidence()).isEqualTo(0.95);
    }

    @Test
    @DisplayName("T-AI-18: Handles markdown-wrapped JSON response")
    void handlesMarkdownWrapped() {
        String claudeResponse = """
                ```json
                {
                  "vendorName": "Test Vendor",
                  "vendorGstin": null,
                  "invoiceNumber": null,
                  "invoiceDate": null,
                  "dueDate": null,
                  "subtotal": 500.00,
                  "taxAmount": 0,
                  "totalAmount": 500.00,
                  "currency": "INR",
                  "lineItems": [],
                  "taxDetails": {"cgst": null, "sgst": null, "igst": null, "taxRegime": "INDIA_GST"},
                  "confidence": 0.6
                }
                ```
                """;

        when(claudeApiClient.sendMessageWithImage(anyString(), anyString(), anyString(), anyString()))
                .thenReturn(claudeResponse);

        BillScanResponse result = billScanService.scanBill("base64data", "image/png");

        assertThat(result.vendorName()).isEqualTo("Test Vendor");
        assertThat(result.totalAmount()).isEqualByComparingTo(new BigDecimal("500.00"));
        assertThat(result.confidence()).isEqualTo(0.6);
    }

    @Test
    @DisplayName("T-AI-19: Throws on unparseable response")
    void throwsOnBadResponse() {
        when(claudeApiClient.sendMessageWithImage(anyString(), anyString(), anyString(), anyString()))
                .thenReturn("Sorry, I can't read this image.");

        assertThatThrownBy(() -> billScanService.scanBill("base64data", "image/jpeg"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Could not extract data")
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo("ERR_AI_BILL_PARSE");
    }
}
