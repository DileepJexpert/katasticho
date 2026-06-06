package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.Beat;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BeatRepository extends JpaRepository<Beat, UUID> {

    Optional<Beat> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<Beat> findByOrgIdAndIsDeletedFalse(UUID orgId, Pageable pageable);

    List<Beat> findByOrgIdAndIsActiveTrueAndIsDeletedFalse(UUID orgId);

    boolean existsByOrgIdAndCodeAndIsDeletedFalse(UUID orgId, String code);
}
