package com.katasticho.erp.settings.pdf.repository;

import com.katasticho.erp.settings.pdf.entity.PdfTemplateSetting;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PdfTemplateSettingRepository extends JpaRepository<PdfTemplateSetting, UUID> {

    Optional<PdfTemplateSetting> findByOrgIdAndDocumentTypeAndIsDeletedFalse(UUID orgId, String documentType);

    List<PdfTemplateSetting> findByOrgIdAndIsDeletedFalse(UUID orgId);
}