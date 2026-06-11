package com.katasticho.erp.auth.repository;

import com.katasticho.erp.auth.entity.ApiKey;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ApiKeyRepository extends JpaRepository<ApiKey, UUID> {

    /** Auth lookup — the hash is globally unique, so no org scoping needed here. */
    Optional<ApiKey> findByKeyHash(String keyHash);

    List<ApiKey> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId);

    Optional<ApiKey> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);
}
