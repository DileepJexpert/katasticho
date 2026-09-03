package com.katasticho.erp.inventory.service;

import com.katasticho.erp.inventory.dto.BarcodeLabelRequest;
import com.katasticho.erp.inventory.dto.BarcodeLabelResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;

@Service
@Slf4j
public class ZplLabelGeneratorService {

    public BarcodeLabelResponse generateLabel(BarcodeLabelRequest request) {
        double dotsPerMm = request.getDpi() == 300 ? 11.81 : 8.0;
        int widthDots = (int) Math.round(request.getLabelWidthMm() * dotsPerMm);
        int heightDots = (int) Math.round(request.getLabelHeightMm() * dotsPerMm);
        int copies = Math.max(1, request.getCopies());

        String zpl = buildZpl(request, widthDots, heightDots, copies);
        String epl = buildEpl(request, widthDots, heightDots, copies);

        return BarcodeLabelResponse.builder()
                .zplCode(zpl)
                .eplCode(epl)
                .labelWidthDots(widthDots)
                .labelHeightDots(heightDots)
                .copies(copies)
                .build();
    }

    private String buildZpl(BarcodeLabelRequest req, int width, int height, int copies) {
        StringBuilder sb = new StringBuilder();
        sb.append("^XA\n");
        sb.append("^PW").append(width).append("\n");
        sb.append("^LL").append(height).append("\n");
        sb.append("^LH0,0\n");

        int currentY = 16;

        // 1. Company Name Header (if provided)
        if (req.getCompanyName() != null && !req.getCompanyName().isBlank()) {
            sb.append("^FO20,").append(currentY).append("^A0N,20,20^FD")
                    .append(sanitizeZpl(req.getCompanyName().toUpperCase()))
                    .append("^FS\n");
            currentY += 24;
        }

        // 2. Item Title
        sb.append("^FO20,").append(currentY).append("^A0N,26,26^FD")
                .append(sanitizeZpl(truncate(req.getItemName(), 28)))
                .append("^FS\n");
        currentY += 32;

        // 3. Barcode Block
        String barcodeType = req.getBarcodeType() != null ? req.getBarcodeType().toUpperCase() : "CODE128";
        if ("QR".equals(barcodeType)) {
            sb.append("^FO20,").append(currentY).append("^BQN,2,4^FDQA,")
                    .append(req.getBarcodeValue())
                    .append("^FS\n");
            currentY += 75;
        } else if ("EAN13".equals(barcodeType)) {
            sb.append("^BY2,2,45^FO20,").append(currentY).append("^BEN,45,Y,N^FD")
                    .append(req.getBarcodeValue())
                    .append("^FS\n");
            currentY += 60;
        } else {
            // Default CODE 128
            sb.append("^BY2,2,45^FO20,").append(currentY).append("^BCN,45,Y,N,N^FD")
                    .append(req.getBarcodeValue())
                    .append("^FS\n");
            currentY += 60;
        }

        // 4. Batch & Expiry Row
        StringBuilder meta1 = new StringBuilder();
        if (req.getBatchNumber() != null && !req.getBatchNumber().isBlank()) {
            meta1.append("B.No: ").append(req.getBatchNumber()).append("  ");
        }
        if (req.getExpiryDate() != null && !req.getExpiryDate().isBlank()) {
            meta1.append("Exp: ").append(req.getExpiryDate());
        }

        if (!meta1.isEmpty()) {
            sb.append("^FO20,").append(currentY).append("^A0N,20,20^FD")
                    .append(sanitizeZpl(meta1.toString()))
                    .append("^FS\n");
            currentY += 24;
        }

        // 5. MRP / Pricing Row
        StringBuilder priceStr = new StringBuilder();
        if (req.getMrp() != null && req.getMrp().compareTo(BigDecimal.ZERO) > 0) {
            priceStr.append("MRP: Rs. ").append(req.getMrp().toPlainString()).append("  ");
        }
        if (req.getSellingPrice() != null && req.getSellingPrice().compareTo(BigDecimal.ZERO) > 0) {
            priceStr.append("Our Price: Rs. ").append(req.getSellingPrice().toPlainString());
        }

        if (!priceStr.isEmpty()) {
            sb.append("^FO20,").append(currentY).append("^A0N,22,22^FD")
                    .append(sanitizeZpl(priceStr.toString()))
                    .append("^FS\n");
            currentY += 24;
        }

        // 6. FSSAI / SKU footer
        if (req.getFssaiLicNo() != null && !req.getFssaiLicNo().isBlank()) {
            sb.append("^FO20,").append(currentY).append("^A0N,18,18^FDFSSAI Lic: ")
                    .append(sanitizeZpl(req.getFssaiLicNo()))
                    .append("^FS\n");
        }

        sb.append("^PQ").append(copies).append("\n");
        sb.append("^XZ\n");
        return sb.toString();
    }

    private String buildEpl(BarcodeLabelRequest req, int width, int height, int copies) {
        StringBuilder sb = new StringBuilder();
        sb.append("N\n");
        sb.append("q").append(width).append("\n");
        sb.append("Q").append(height).append(",0\n");

        int currentY = 16;
        sb.append("A20,").append(currentY).append(",0,3,1,1,N,\"").append(truncate(req.getItemName(), 24)).append("\"\n");
        currentY += 30;

        sb.append("B20,").append(currentY).append(",0,1,2,2,40,B,\"").append(req.getBarcodeValue()).append("\"\n");
        currentY += 55;

        if (req.getMrp() != null) {
            sb.append("A20,").append(currentY).append(",0,2,1,1,N,\"MRP: Rs. ").append(req.getMrp().toPlainString()).append("\"\n");
        }

        sb.append("P").append(copies).append("\n");
        return sb.toString();
    }

    private String sanitizeZpl(String input) {
        if (input == null) return "";
        return input.replace("^", "").replace("~", "").replace("₹", "Rs.");
    }

    private String truncate(String str, int maxLen) {
        if (str == null) return "";
        return str.length() <= maxLen ? str : str.substring(0, maxLen) + "...";
    }
}