package com.katasticho.erp.settings.pdf.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.settings.pdf.dto.PdfTemplateSettingRequest;
import com.katasticho.erp.settings.pdf.dto.PdfTemplateSettingResponse;
import com.katasticho.erp.settings.pdf.entity.PdfTemplateSetting;
import com.katasticho.erp.settings.pdf.repository.PdfTemplateSettingRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PdfTemplateSettingService {

    private final PdfTemplateSettingRepository repository;

    @Transactional(readOnly = true)
    public PdfTemplateSettingResponse getSetting(String documentType) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return repository.findByOrgIdAndDocumentTypeAndIsDeletedFalse(orgId, documentType.toUpperCase())
                .map(PdfTemplateSettingResponse::from)
                .orElseGet(() -> getDefaultResponse(orgId, documentType.toUpperCase()));
    }

    @Transactional(readOnly = true)
    public List<PdfTemplateSettingResponse> getAllSettings() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return repository.findByOrgIdAndIsDeletedFalse(orgId).stream()
                .map(PdfTemplateSettingResponse::from)
                .toList();
    }

    @Transactional
    public PdfTemplateSettingResponse saveOrUpdate(PdfTemplateSettingRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String docType = request.getDocumentType().toUpperCase();

        PdfTemplateSetting setting = repository.findByOrgIdAndDocumentTypeAndIsDeletedFalse(orgId, docType)
                .orElseGet(() -> {
                    PdfTemplateSetting s = new PdfTemplateSetting();
                    s.setOrgId(orgId);
                    s.setDocumentType(docType);
                    return s;
                });

        if (request.getTemplateTheme() != null) setting.setTemplateTheme(request.getTemplateTheme());
        if (request.getPrimaryColor() != null) setting.setPrimaryColor(request.getPrimaryColor());
        if (request.getHeaderLayout() != null) setting.setHeaderLayout(request.getHeaderLayout());
        if (request.getShowGstColumns() != null) setting.setShowGstColumns(request.getShowGstColumns());
        if (request.getShowHsnColumn() != null) setting.setShowHsnColumn(request.getShowHsnColumn());
        if (request.getShowPaymentQr() != null) setting.setShowPaymentQr(request.getShowPaymentQr());
        if (request.getShowTerms() != null) setting.setShowTerms(request.getShowTerms());
        if (request.getTermsAndConditions() != null) setting.setTermsAndConditions(request.getTermsAndConditions());
        if (request.getShowSignature() != null) setting.setShowSignature(request.getShowSignature());
        if (request.getSignatureLabel() != null) setting.setSignatureLabel(request.getSignatureLabel());
        if (request.getWatermarkText() != null) setting.setWatermarkText(request.getWatermarkText());
        if (request.getActive() != null) setting.setActive(request.getActive());

        PdfTemplateSetting saved = repository.save(setting);
        log.info("Saved PDF template settings for org [{}] docType [{}]", orgId, docType);
        return PdfTemplateSettingResponse.from(saved);
    }

    private PdfTemplateSettingResponse getDefaultResponse(UUID orgId, String docType) {
        return PdfTemplateSettingResponse.builder()
                .orgId(orgId)
                .documentType(docType)
                .templateTheme("CLASSIC")
                .primaryColor("#0F8576")
                .headerLayout("LOGO_LEFT")
                .showGstColumns(true)
                .showHsnColumn(true)
                .showPaymentQr(true)
                .showTerms(true)
                .termsAndConditions("1. Goods once sold will not be taken back.\n2. Interest @ 18% p.a. will be charged if payment is not made within the due date.")
                .showSignature(true)
                .signatureLabel("Authorized Signatory")
                .watermarkText(null)
                .active(true)
                .build();
    }
}