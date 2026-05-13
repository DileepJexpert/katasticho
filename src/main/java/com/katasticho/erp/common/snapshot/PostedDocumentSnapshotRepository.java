package com.katasticho.erp.common.snapshot;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface PostedDocumentSnapshotRepository extends JpaRepository<PostedDocumentSnapshot, UUID> {

    Optional<PostedDocumentSnapshot> findByOrgIdAndDocumentTypeAndDocumentId(
            UUID orgId, String documentType, UUID documentId);
}
