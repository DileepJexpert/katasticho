package com.katasticho.erp.settings.pdf.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.*;

@Entity
@Table(name = "pdf_template_setting")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PdfTemplateSetting extends BaseEntity {

    @Column(name = "document_type", nullable = false, length = 50)
    private String documentType; // INVOICE, QUOTATION, BILL, DELIVERY_CHALLAN

    @Column(name = "template_theme", nullable = false, length = 50)
    @Builder.Default
    private String templateTheme = "CLASSIC"; // CLASSIC, MODERN, MINIMAL, COMPACT_THERMAL

    @Column(name = "primary_color", nullable = false, length = 20)
    @Builder.Default
    private String primaryColor = "#0F8576";

    @Column(name = "header_layout", nullable = false, length = 30)
    @Builder.Default
    private String headerLayout = "LOGO_LEFT"; // LOGO_LEFT, LOGO_RIGHT, LOGO_CENTER

    @Column(name = "show_gst_columns", nullable = false)
    @Builder.Default
    private boolean showGstColumns = true;

    @Column(name = "show_hsn_column", nullable = false)
    @Builder.Default
    private boolean showHsnColumn = true;

    @Column(name = "show_payment_qr", nullable = false)
    @Builder.Default
    private boolean showPaymentQr = true;

    @Column(name = "show_terms", nullable = false)
    @Builder.Default
    private boolean showTerms = true;

    @Column(name = "terms_and_conditions", columnDefinition = "TEXT")
    private String termsAndConditions;

    @Column(name = "show_signature", nullable = false)
    @Builder.Default
    private boolean showSignature = true;

    @Column(name = "signature_label", length = 100)
    @Builder.Default
    private String signatureLabel = "Authorized Signatory";

    @Column(name = "watermark_text", length = 100)
    private String watermarkText;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;
}