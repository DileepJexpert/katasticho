package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.HsnGstMaster;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface HsnGstMasterRepository extends JpaRepository<HsnGstMaster, UUID> {
    Optional<HsnGstMaster> findByHsnCodeAndActiveTrue(String hsnCode);

    @Query("""
            SELECT h FROM HsnGstMaster h
            WHERE h.active = true
              AND (LOWER(h.hsnCode) LIKE LOWER(CONCAT('%', :q, '%'))
                   OR LOWER(h.description) LIKE LOWER(CONCAT('%', :q, '%')))
            ORDER BY h.hsnCode ASC
            """)
    List<HsnGstMaster> search(@Param("q") String query, Pageable pageable);
}
