package com.katasticho.erp.inventory.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BarcodeLabelRequest {

    @NotBlank(message = "Item name is required")
    private String itemName;

    private String sku;

    @NotBlank(message = "Barcode value is required")
    private String barcodeValue;

    @Builder.Default
    private String barcodeType = "CODE128"; // CODE128, EAN13, QR

    private String batchNumber;
    private String expiryDate;
    private BigDecimal mrp;
    private BigDecimal sellingPrice;
    private String fssaiLicNo;
    private String companyName;

    @Builder.Default
    private int labelWidthMm = 50;

    @Builder.Default
    private int labelHeightMm = 25;

    @Builder.Default
    private int dpi = 203; // 203 dpi (8 dots/mm) or 300 dpi (12 dots/mm)

    @Builder.Default
    private int copies = 1;
}