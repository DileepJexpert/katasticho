package com.katasticho.erp.asset.repository;

import com.katasticho.erp.asset.entity.FixedAssetDepreciation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface FixedAssetDepreciationRepository
        extends JpaRepository<FixedAssetDepreciation, UUID> {

    boolean existsByOrgIdAndFixedAssetIdAndPeriodYearAndPeriodMonth(
            UUID orgId, UUID fixedAssetId, int periodYear, int periodMonth);

    List<FixedAssetDepreciation> findByOrgIdAndFixedAssetIdOrderByPeriodYearAscPeriodMonthAsc(
            UUID orgId, UUID fixedAssetId);
}
