package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.DrugInteraction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface DrugInteractionRepository extends JpaRepository<DrugInteraction, UUID> {

    @Query("""
            SELECT i FROM DrugInteraction i
            WHERE i.active = true
              AND i.primarySaltId IN :saltIds
              AND i.interactingSaltId IN :saltIds
            ORDER BY CASE i.severity
                WHEN 'CRITICAL' THEN 0
                WHEN 'HIGH' THEN 1
                WHEN 'MODERATE' THEN 2
                ELSE 3
            END
            """)
    List<DrugInteraction> findActiveWithinSaltSet(@Param("saltIds") Collection<UUID> saltIds);
}
