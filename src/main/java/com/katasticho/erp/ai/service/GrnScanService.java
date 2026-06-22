package com.katasticho.erp.ai.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.dto.GrnScanResponse;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Photo-to-GRN OCR: extract a receivable-shaped payload from a goods-arrival
 * photo (typically the supplier's invoice or delivery challan the truck
 * arrived with).
 *
 * <p>Distinct from {@link BillScanService}: a GRN cares about the batch /
 * expiry / received-qty / unit-cost block that drives stock posting, not the
 * tax breakdown that drives a vendor bill. In practice the same photo can
 * power both flows — we just ask for a different JSON shape.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class GrnScanService {

    private final VisionModelRouter visionModelRouter;
    private final ObjectMapper objectMapper;

    private static final String SYSTEM_PROMPT = """
            You are an expert Indian goods-receipt OCR system, specialised in
            pharmaceutical and medical-store distributor invoices / delivery challans.
            The downstream system is recording a GOODS RECEIPT — what matters is the
            per-line batch / expiry / received-quantity / unit-cost block, not the
            tax breakdown.

            Return ONLY a valid JSON object with this exact structure (no markdown,
            no explanations):
            {
              "supplierName": "string",
              "supplierGstin": "string or null",
              "invoiceNumber": "string or null",
              "invoiceDate": "YYYY-MM-DD or null",
              "subtotal": number,
              "totalAmount": number,
              "currency": "INR",
              "lines": [
                {
                  "lineNumber": 1,
                  "description": "string",
                  "hsnCode": "string or null",
                  "quantity": number,
                  "unitPrice": number,
                  "mrp": number or null,
                  "batchNumber": "string or null",
                  "expiryDate": "YYYY-MM-DD or null",
                  "gstRate": number or null
                }
              ],
              "confidence": 0.0 to 1.0
            }

            Rules:
            - Extract ALL line items visible, even faint or partially legible rows.
            - "Product"/"Description": the medicine name with strength & pack
              (e.g. "DYTOR 5MG TAB 15'S").
            - "Pack": pack size — fold this into the description, do NOT treat as quantity.
            - "Qty"/"Quantity": packs/strips received -> "quantity".
            - "Batch"/"Batch No": batch code (e.g. "NM4820054A") -> "batchNumber".
            - "Exp"/"Expiry": expiry date, usually MM/YY or MM/YYYY (e.g. "12/26"
              means Dec 2026). Convert to YYYY-MM-DD using the LAST day of that
              month (e.g. "12/26" -> "2026-12-31").
            - "MRP": Maximum Retail Price per pack -> "mrp".
            - "Rate"/"Net Rate": distributor's purchase price per pack -> "unitPrice".

            General:
            - Set confidence based on image clarity and extraction certainty.
            - Use 0 for numeric values you cannot determine, null for unknown strings/dates.
            - All dates must be in YYYY-MM-DD format.
            - Never invent batch numbers or expiry dates — use null if not clearly visible.
            """;

    public GrnScanResponse scanGrn(String base64Image, String mediaType) {
        log.info("Scanning GRN image (mediaType={})", mediaType);

        String response = visionModelRouter.sendMessageWithImage(
                SYSTEM_PROMPT,
                "Extract all goods-receipt data from this image.",
                base64Image,
                mediaType
        );

        // Strip any markdown fencing the model might emit.
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
            GrnScanResponse result = objectMapper.readValue(cleaned, GrnScanResponse.class);
            log.info("GRN scanned: supplier={}, lines={}, confidence={}",
                    result.supplierName(),
                    result.lines() == null ? 0 : result.lines().size(),
                    result.confidence());
            return result;
        } catch (Exception e) {
            log.error("Failed to parse GRN scan response: {}", e.getMessage());
            throw new BusinessException(
                    "Could not extract data from the goods-receipt image. Please try a clearer photo.",
                    "ERR_AI_GRN_PARSE",
                    HttpStatus.UNPROCESSABLE_ENTITY
            );
        }
    }
}
