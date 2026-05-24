package com.katasticho.erp.pharma.repository;

import com.katasticho.erp.pharma.entity.DrugLicense;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DrugLicenseRepository extends JpaRepository<DrugLicense, UUID> {

    List<DrugLicense> findByOrgIdAndIsDeletedFalseOrderByExpiryDateAsc(UUID orgId);

    Optional<DrugLicense> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    @Query("""
        SELECT d FROM DrugLicense d
        WHERE d.orgId = :orgId
          AND d.isDeleted = false
          AND d.expiryDate BETWEEN :today AND :threshold
        ORDER BY d.expiryDate ASC
    """)
    List<DrugLicense> findExpiringWithin(
            @Param("orgId") UUID orgId,
            @Param("today") LocalDate today,
            @Param("threshold") LocalDate threshold);
}
