package com.katasticho.erp.customfield.repository;

import com.katasticho.erp.customfield.entity.CustomFieldValue;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CustomFieldValueRepository extends JpaRepository<CustomFieldValue, UUID> {

    List<CustomFieldValue> findByOrgIdAndEntityTypeAndEntityIdAndIsDeletedFalse(UUID orgId, String entityType, UUID entityId);

    List<CustomFieldValue> findByOrgIdAndEntityTypeAndEntityIdInAndIsDeletedFalse(UUID orgId, String entityType, Collection<UUID> entityIds);

    Optional<CustomFieldValue> findByOrgIdAndFieldDefinitionIdAndEntityIdAndIsDeletedFalse(UUID orgId, UUID fieldDefinitionId, UUID entityId);

    List<CustomFieldValue> findByOrgIdAndFieldDefinitionIdAndIsDeletedFalse(UUID orgId, UUID fieldDefinitionId);
}
