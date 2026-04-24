package com.katasticho.erp.ai.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.dto.ItemScanResponse;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class ItemScanService {

    private final ClaudeApiClient claudeApiClient;
    private final ObjectMapper objectMapper;

    private static final String LABEL_PROMPT = """
            You are an expert product label OCR system for Indian retail. Extract product details from the image.

            Return ONLY a valid JSON object (no markdown, no explanations):
            {
              "items": [
                {
                  "name": "product name",
                  "barcode": "barcode number if visible, else null",
                  "hsnCode": "HSN code if visible, else null",
                  "category": "inferred category (e.g. GROCERY, DAIRY, SNACKS, BEVERAGES, PERSONAL_CARE, MEDICINE, ELECTRONICS, HARDWARE, CLOTHING)",
                  "brand": "brand name if visible, else null",
                  "manufacturer": "manufacturer name if visible, else null",
                  "unitOfMeasure": "PCS or KG or LTR or ML or GM based on product type",
                  "mrp": MRP as number if visible (look for ₹ or Rs or MRP on label), else null,
                  "salePrice": same as MRP unless a selling price is shown separately,
                  "purchasePrice": null,
                  "gstRate": GST rate as number if visible, else guess from category (5 for essentials, 12 for processed food, 18 for most goods, 28 for luxury),
                  "description": "brief product description if visible",
                  "genericName": "generic/scientific name if medicine, else null",
                  "composition": "drug composition if medicine, else null",
                  "dosageForm": "TABLET/CAPSULE/SYRUP/INJECTION/CREAM if medicine, else null",
                  "drugSchedule": "H/H1/X if medicine and visible, else null",
                  "packSize": "pack size if visible (e.g. 10 tablets, 500ml), else null",
                  "weight": weight as number if visible, else null,
                  "weightUnit": "g or kg or ml or l if weight shown, else null",
                  "reorderLevel": null
                }
              ],
              "confidence": 0.0 to 1.0,
              "source": "PRODUCT_LABEL"
            }

            Rules:
            - Extract EVERY product visible in the image (there may be multiple)
            - MRP is usually printed as "MRP ₹XX" or "M.R.P. Rs. XX" on Indian products
            - Barcode is usually a 13-digit EAN number printed below the barcode lines
            - For medicines: look for composition, drug schedule (H, H1, X), dosage form
            - For FMCG: look for net weight, brand, manufacturer address
            - Set confidence based on image clarity
            - If the image is not a product label, return items as empty array with confidence 0
            """;

    private static final String INVOICE_PROMPT = """
            You are an expert purchase invoice OCR system for Indian retail. Extract ALL item details from this purchase bill/invoice image.

            Return ONLY a valid JSON object (no markdown, no explanations):
            {
              "items": [
                {
                  "name": "item name from invoice line",
                  "barcode": null,
                  "hsnCode": "HSN if shown in table, else null",
                  "category": "inferred category based on items",
                  "brand": "brand if identifiable, else null",
                  "manufacturer": null,
                  "unitOfMeasure": "PCS or KG or LTR or BOX or CASE etc as shown",
                  "mrp": MRP if shown in invoice, else null,
                  "salePrice": null,
                  "purchasePrice": unit price from invoice as number,
                  "gstRate": GST rate if shown per line, else null,
                  "description": null,
                  "genericName": null,
                  "composition": null,
                  "dosageForm": null,
                  "drugSchedule": null,
                  "packSize": "pack size if shown, else null",
                  "weight": null,
                  "weightUnit": null,
                  "reorderLevel": null
                }
              ],
              "confidence": 0.0 to 1.0,
              "source": "PURCHASE_INVOICE"
            }

            Rules:
            - Extract EVERY line item from the invoice table
            - Purchase price = unit rate shown in the invoice
            - If MRP and rate are both shown, MRP is the higher one (retail price)
            - HSN codes are usually in a column in the invoice table
            - GST rate is per line item if shown (5%, 12%, 18%, 28%)
            - Unit of measure: look for qty column format (10 Pcs, 5 Kg, etc.)
            - Set confidence based on image clarity and table legibility
            """;

    public ItemScanResponse scanProductLabel(String base64Image, String mediaType) {
        log.info("Scanning product label (mediaType={})", mediaType);
        return doScan(base64Image, mediaType, LABEL_PROMPT,
                "Extract all product details from this product label/packaging image.");
    }

    public ItemScanResponse scanPurchaseInvoice(String base64Image, String mediaType) {
        log.info("Scanning purchase invoice for items (mediaType={})", mediaType);
        return doScan(base64Image, mediaType, INVOICE_PROMPT,
                "Extract all line items from this purchase invoice/bill image.");
    }

    private ItemScanResponse doScan(String base64Image, String mediaType,
                                     String systemPrompt, String userMessage) {
        String response = claudeApiClient.sendMessageWithImage(
                systemPrompt, userMessage, base64Image, mediaType);

        String cleaned = response.strip();
        if (cleaned.startsWith("```json")) cleaned = cleaned.substring(7);
        if (cleaned.startsWith("```")) cleaned = cleaned.substring(3);
        if (cleaned.endsWith("```")) cleaned = cleaned.substring(0, cleaned.length() - 3);
        cleaned = cleaned.strip();

        try {
            ItemScanResponse result = objectMapper.readValue(cleaned, ItemScanResponse.class);
            log.info("Item scan complete: {} items extracted, confidence={}",
                    result.items() != null ? result.items().size() : 0, result.confidence());
            return result;
        } catch (Exception e) {
            log.error("Failed to parse item scan response: {}", e.getMessage());
            throw new BusinessException(
                    "Could not extract item data from the image. Please try a clearer photo.",
                    "ERR_AI_ITEM_PARSE",
                    HttpStatus.UNPROCESSABLE_ENTITY
            );
        }
    }
}
