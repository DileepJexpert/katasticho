package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.Van;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface VanRepository extends JpaRepository<Van, UUID> {

    Optional<Van> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<Van> findByOrgIdAndIsDeletedFalse(UUID orgId, Pageable pageable);

    List<Van> findByOrgIdAndIsActiveTrueAndIsDeletedFalse(UUID orgId);

    boolean existsByOrgIdAndCodeAndIsDeletedFalse(UUID orgId, String code);
}
