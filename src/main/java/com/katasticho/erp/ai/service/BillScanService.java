package com.katasticho.erp.ai.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.dto.BillScanResponse;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Bill/invoice scanning using Claude Vision.
 *
 * Flow:
 * 1. User uploads a photo of a bill/invoice
 * 2. Claude Vision extracts structured data (vendor, items, GST, totals)
 * 3. Returns structured BillScanResponse for pre-filling invoice forms
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class BillScanService {

    private final ClaudeApiClient claudeApiClient;
    private final ObjectMapper objectMapper;

    private static final String SYSTEM_PROMPT = """
            You are an expert Indian bill/invoice OCR system. Extract structured data from the bill image.

            Return ONLY a valid JSON object with this exact structure (no markdown, no explanations):
            {
              "vendorName": "string",
              "vendorGstin": "string or null",
              "invoiceNumber": "string or null",
              "invoiceDate": "YYYY-MM-DD or null",
              "dueDate": "YYYY-MM-DD or null",
              "subtotal": number,
              "taxAmount": number,
              "totalAmount": number,
              "currency": "INR",
              "lineItems": [
                {
                  "lineNumber": 1,
                  "description": "string",
                  "hsnCode": "string or null",
                  "quantity": number,
                  "unitPrice": number,
                  "amount": number,
                  "gstRate": number or null
                }
              ],
              "taxDetails": {
                "cgst": number or null,
                "sgst": number or null,
                "igst": number or null,
                "taxRegime": "INDIA_GST"
              },
              "confidence": 0.0 to 1.0
            }

            Rules:
            - Extract ALL line items visible on the bill
            - If GSTIN is visible, extract the full 15-character code
            - Identify HSN/SAC codes if present
            - Separate CGST, SGST, IGST amounts if shown
            - Set confidence based on image clarity and extraction certainty
            - Use 0 for amounts you cannot determine
            - Dates must be in YYYY-MM-DD format
            """;

    public BillScanResponse scanBill(String base64Image, String mediaType) {
        log.info("Scanning bill image (mediaType={})", mediaType);

        String response = claudeApiClient.sendMessageWithImage(
                SYSTEM_PROMPT,
                "Extract all data from this bill/invoice image.",
                base64Image,
                mediaType
        );

        // Clean response — remove any markdown wrapping
        String cleaned = response.strip();
        if (cleaned.startsWith("```json")) {
            cleaned = cleaned.substring(7);
        }
        if (cleaned.startsWith("```")) {
            cleaned = cleaned.substring(3);
        }
        if (cleaned.endsWith("```")) {
            cleaned = cleaned.substring(0, cleaned.length() - 3);
        }
        cleaned = cleaned.strip();

        try {
            BillScanResponse result = objectMapper.readValue(cleaned, BillScanResponse.class);
            log.info("Bill scanned: vendor={}, total={}, confidence={}",
                    result.vendorName(), result.totalAmount(), result.confidence());
            return result;
        } catch (Exception e) {
            log.error("Failed to parse bill scan response: {}", e.getMessage());
            throw new BusinessException(
                    "Could not extract data from the bill image. Please try a clearer photo.",
                    "ERR_AI_BILL_PARSE",
                    HttpStatus.UNPROCESSABLE_ENTITY
            );
        }
    }
}
