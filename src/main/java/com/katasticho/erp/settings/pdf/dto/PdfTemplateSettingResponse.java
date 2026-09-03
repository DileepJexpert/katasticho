package com.katasticho.erp.settings.pdf.dto;

import com.katasticho.erp.settings.pdf.entity.PdfTemplateSetting;
import lombok.Builder;
import java.time.Instant;
import java.util.UUID;

@Builder
public record PdfTemplateSettingResponse(
        UUID id,
        UUID orgId,
        String documentType,
        String templateTheme,
        String primaryColor,
        String headerLayout,
        boolean showGstColumns,
        boolean showHsnColumn,
        boolean showPaymentQr,
        boolean showTerms,
        String termsAndConditions,
        boolean showSignature,
        String signatureLabel,
        String watermarkText,
        boolean active,
        Instant createdAt,
        Instant updatedAt
) {
    public static PdfTemplateSettingResponse from(PdfTemplateSetting s) {
        return new PdfTemplateSettingResponse(
                s.getId(),
                s.getOrgId(),
                s.getDocumentType(),
                s.getTemplateTheme(),
                s.getPrimaryColor(),
                s.getHeaderLayout(),
                s.isShowGstColumns(),
                s.isShowHsnColumn(),
                s.isShowPaymentQr(),
                s.isShowTerms(),
                s.getTermsAndConditions(),
                s.isShowSignature(),
                s.getSignatureLabel(),
                s.getWatermarkText(),
                s.isActive(),
                s.getCreatedAt(),
                s.getUpdatedAt()
        );
    }
}