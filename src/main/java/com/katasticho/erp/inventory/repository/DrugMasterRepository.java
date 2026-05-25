package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.DrugMaster;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.UUID;

public interface DrugMasterRepository extends JpaRepository<DrugMaster, UUID> {

    @Query("""
            SELECT d FROM DrugMaster d
            WHERE d.isActive = true
              AND (
                    LOWER(d.brandName) LIKE LOWER(CONCAT('%', :q, '%'))
                 OR LOWER(d.genericName) LIKE LOWER(CONCAT('%', :q, '%'))
                 OR LOWER(d.saltComposition) LIKE LOWER(CONCAT('%', :q, '%'))
              )
            ORDER BY d.brandName
            """)
    Page<DrugMaster> search(@Param("q") String query, Pageable pageable);

    @Query("""
            SELECT d FROM DrugMaster d
            WHERE d.isActive = true
              AND d.salt.id = :saltId
            ORDER BY d.brandName
            """)
    Page<DrugMaster> findBySaltId(@Param("saltId") UUID saltId, Pageable pageable);
}
