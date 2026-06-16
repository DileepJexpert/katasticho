package com.katasticho.erp.asset.repository;

import com.katasticho.erp.asset.entity.FixedAsset;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface FixedAssetRepository extends JpaRepository<FixedAsset, UUID> {

    Optional<FixedAsset> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<FixedAsset> findByOrgIdAndIsDeletedFalseOrderByAcquisitionDateDesc(UUID orgId);

    List<FixedAsset> findByOrgIdAndStatusAndIsDeletedFalseOrderByAcquisitionDateAsc(
            UUID orgId, String status);

    boolean existsByOrgIdAndAssetCodeAndIsDeletedFalse(UUID orgId, String assetCode);
}
