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

    private final VisionModelRouter visionModelRouter;
    private final ObjectMapper objectMapper;

    private static final String SYSTEM_PROMPT = """
            You are an expert Indian bill/invoice OCR system, specialised in pharmaceutical
            and medical store distributor invoices. Extract structured data from the bill image.

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
                  "gstRate": number or null,
                  "batchNumber": "string or null",
                  "expiryDate": "YYYY-MM-DD or null",
                  "mrp": number or null,
                  "freeQuantity": number or null
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
            - Extract ALL line items visible on the bill, even faint or partially legible rows
            - If GSTIN is visible, extract the full 15-character code
            - Identify HSN/SAC codes if present
            - Separate CGST, SGST, IGST amounts if shown

            Pharmaceutical / medical store bill columns (common headers):
            - "Product"/"Description": the medicine name with strength & pack (e.g. "DYTOR 5MG TAB 15'S")
            - "Pack": pack size — fold this into the description, do NOT treat as quantity
            - "Qty"/"Quantity": number of packs/strips purchased -> "quantity"
            - "Free": free/scheme units given by distributor -> "freeQuantity" (0 if none)
            - "Batch"/"Batch No": the batch code (e.g. "NM4820054A") -> "batchNumber"
            - "Exp"/"Expiry": expiry date, usually MM/YY or MM/YYYY (e.g. "12/26" means Dec 2026).
              Convert to YYYY-MM-DD using the LAST day of that month (e.g. "12/26" -> "2026-12-31")
            - "MRP": Maximum Retail Price per pack -> "mrp"
            - "Rate"/"Net Rate": the distributor's selling/purchase price per pack -> "unitPrice"
            - "Amount": line total -> "amount"
            - The bill is GST-inclusive of MRP; gstRate is the % shown (often 5, 12, 18). For pharma
              the GST is frequently 5% split as CGST 2.5% + SGST 2.5% — set gstRate to the combined %.

            General:
            - Set confidence based on image clarity and extraction certainty
            - Use 0 for numeric values you cannot determine, null for unknown strings/dates
            - All dates must be in YYYY-MM-DD format
            - Never invent batch numbers or expiry dates — use null if not clearly visible
            """;

    public BillScanResponse scanBill(String base64Image, String mediaType) {
        log.info("Scanning bill image (mediaType={})", mediaType);

        String response = visionModelRouter.sendMessageWithImage(
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
