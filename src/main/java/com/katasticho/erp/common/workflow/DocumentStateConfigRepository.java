package com.katasticho.erp.common.workflow;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DocumentStateConfigRepository extends JpaRepository<DocumentStateConfig, UUID> {

    boolean existsByOrgIdAndDocumentTypeAndFromStateAndToStateAndIsDeletedFalse(
            UUID orgId, String documentType, String fromState, String toState);

    Optional<DocumentStateConfig> findByOrgIdAndDocumentTypeAndFromStateAndToStateAndActiveTrueAndIsDeletedFalse(
            UUID orgId, String documentType, String fromState, String toState);

    List<DocumentStateConfig> findByOrgIdAndIsDeletedFalseOrderByDocumentTypeAscFromStateAscToStateAsc(UUID orgId);
}
