package com.katasticho.erp.settings.pdf;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.settings.pdf.dto.PdfTemplateSettingRequest;
import com.katasticho.erp.settings.pdf.dto.PdfTemplateSettingResponse;
import com.katasticho.erp.settings.pdf.entity.PdfTemplateSetting;
import com.katasticho.erp.settings.pdf.repository.PdfTemplateSettingRepository;
import com.katasticho.erp.settings.pdf.service.PdfTemplateSettingService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PdfTemplateSettingServiceTest {

    @Mock
    private PdfTemplateSettingRepository repository;

    @InjectMocks
    private PdfTemplateSettingService service;

    private UUID orgId;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void getSetting_returnsExisting() {
        PdfTemplateSetting existing = PdfTemplateSetting.builder()
                .documentType("INVOICE")
                .templateTheme("MODERN")
                .primaryColor("#1E40AF")
                .headerLayout("LOGO_CENTER")
                .build();
        existing.setId(UUID.randomUUID());
        existing.setOrgId(orgId);

        when(repository.findByOrgIdAndDocumentTypeAndIsDeletedFalse(orgId, "INVOICE"))
                .thenReturn(Optional.of(existing));

        PdfTemplateSettingResponse res = service.getSetting("INVOICE");

        assertThat(res).isNotNull();
        assertThat(res.templateTheme()).isEqualTo("MODERN");
        assertThat(res.primaryColor()).isEqualTo("#1E40AF");
        assertThat(res.headerLayout()).isEqualTo("LOGO_CENTER");
    }

    @Test
    void getSetting_returnsDefaultWhenNotConfigured() {
        when(repository.findByOrgIdAndDocumentTypeAndIsDeletedFalse(orgId, "QUOTATION"))
                .thenReturn(Optional.empty());

        PdfTemplateSettingResponse res = service.getSetting("QUOTATION");

        assertThat(res).isNotNull();
        assertThat(res.documentType()).isEqualTo("QUOTATION");
        assertThat(res.templateTheme()).isEqualTo("CLASSIC");
        assertThat(res.primaryColor()).isEqualTo("#0F8576");
    }

    @Test
    void saveOrUpdate_savesSuccessfully() {
        when(repository.findByOrgIdAndDocumentTypeAndIsDeletedFalse(orgId, "INVOICE"))
                .thenReturn(Optional.empty());

        PdfTemplateSetting saved = PdfTemplateSetting.builder()
                .documentType("INVOICE")
                .templateTheme("MINIMAL")
                .primaryColor("#111827")
                .build();
        saved.setId(UUID.randomUUID());
        saved.setOrgId(orgId);

        when(repository.save(any(PdfTemplateSetting.class))).thenReturn(saved);

        PdfTemplateSettingRequest request = PdfTemplateSettingRequest.builder()
                .documentType("INVOICE")
                .templateTheme("MINIMAL")
                .primaryColor("#111827")
                .build();

        PdfTemplateSettingResponse res = service.saveOrUpdate(request);

        assertThat(res).isNotNull();
        assertThat(res.templateTheme()).isEqualTo("MINIMAL");
        assertThat(res.primaryColor()).isEqualTo("#111827");
        verify(repository).save(any(PdfTemplateSetting.class));
    }
}