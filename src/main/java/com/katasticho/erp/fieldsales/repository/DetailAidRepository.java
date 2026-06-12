package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.DetailAid;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DetailAidRepository extends JpaRepository<DetailAid, UUID> {

    Optional<DetailAid> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<DetailAid> findByOrgIdAndIsDeletedFalseOrderByNameAsc(UUID orgId);

    List<DetailAid> findByOrgIdAndIsActiveTrueAndIsDeletedFalseOrderByNameAsc(UUID orgId);
}
