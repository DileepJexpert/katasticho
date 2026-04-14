package com.katasticho.erp.common.repository;

import com.katasticho.erp.common.entity.EntityAttachment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface EntityAttachmentRepository extends JpaRepository<EntityAttachment, UUID> {

    List<EntityAttachment> findByOrgIdAndEntityTypeAndEntityIdAndDeletedFalse(
            UUID orgId, String entityType, UUID entityId);

    Optional<EntityAttachment> findByIdAndOrgId(UUID id, UUID orgId);
}
