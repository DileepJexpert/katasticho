package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.DrugMaster;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface DrugMasterRepository extends JpaRepository<DrugMaster, UUID> {

    List<DrugMaster> findByBrandNameContainingIgnoreCaseAndActiveTrueOrderByBrandNameAsc(
            String query, Pageable pageable);

    List<DrugMaster> findBySaltIdAndActiveTrueOrderByBrandNameAsc(UUID saltId, Pageable pageable);

    @Query("SELECT d FROM DrugMaster d WHERE d.active = true AND " +
           "(LOWER(d.brandName) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(d.genericName) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(d.saltComposition) LIKE LOWER(CONCAT('%', :q, '%'))) " +
           "ORDER BY d.brandName")
    List<DrugMaster> search(@Param("q") String q, Pageable pageable);
}
