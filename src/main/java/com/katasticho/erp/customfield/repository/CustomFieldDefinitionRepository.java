package com.katasticho.erp.customfield.repository;

import com.katasticho.erp.customfield.entity.CustomFieldDefinition;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CustomFieldDefinitionRepository extends JpaRepository<CustomFieldDefinition, UUID> {

    List<CustomFieldDefinition> findByOrgIdAndEntityTypeAndIsDeletedFalseOrderBySortOrderAsc(UUID orgId, String entityType);

    List<CustomFieldDefinition> findByOrgIdAndEntityTypeAndIsActiveTrueAndIsDeletedFalseOrderBySortOrderAsc(UUID orgId, String entityType);

    List<CustomFieldDefinition> findByOrgIdAndIsDeletedFalseOrderByEntityTypeAscSortOrderAsc(UUID orgId);

    Optional<CustomFieldDefinition> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<CustomFieldDefinition> findByOrgIdAndEntityTypeAndFieldNameAndIsDeletedFalse(UUID orgId, String entityType, String fieldName);

    boolean existsByOrgIdAndEntityTypeAndFieldNameAndIsDeletedFalse(UUID orgId, String entityType, String fieldName);
}
