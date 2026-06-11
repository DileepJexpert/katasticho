package com.katasticho.erp.notification.whatsapp;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface WhatsAppMessageRepository extends JpaRepository<WhatsAppMessage, UUID> {

    List<WhatsAppMessage> findTop100ByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId);

    List<WhatsAppMessage> findByOrgIdAndDocTypeAndDocIdAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, String docType, UUID docId);
}
