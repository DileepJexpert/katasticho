package com.katasticho.erp.settings.pdf.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PdfTemplateSettingRequest {

    @NotBlank(message = "Document type is required")
    private String documentType; // INVOICE, QUOTATION, BILL, DELIVERY_CHALLAN

    private String templateTheme; // CLASSIC, MODERN, MINIMAL, COMPACT_THERMAL
    private String primaryColor;
    private String headerLayout;
    private Boolean showGstColumns;
    private Boolean showHsnColumn;
    private Boolean showPaymentQr;
    private Boolean showTerms;
    private String termsAndConditions;
    private Boolean showSignature;
    private String signatureLabel;
    private String watermarkText;
    private Boolean active;
}