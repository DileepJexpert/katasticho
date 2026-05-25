package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.SaltMaster;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.UUID;

public interface SaltMasterRepository extends JpaRepository<SaltMaster, UUID> {

    @Query("""
            SELECT s FROM SaltMaster s
            WHERE LOWER(s.name) LIKE LOWER(CONCAT('%', :q, '%'))
               OR LOWER(s.category) LIKE LOWER(CONCAT('%', :q, '%'))
            ORDER BY s.name
            """)
    Page<SaltMaster> search(@Param("q") String query, Pageable pageable);
}
