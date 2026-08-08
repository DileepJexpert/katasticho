package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.Warehouse;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface WarehouseRepository extends JpaRepository<Warehouse, UUID> {

    Optional<Warehouse> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<Warehouse> findByOrgIdAndCodeAndIsDeletedFalse(UUID orgId, String code);

    Optional<Warehouse> findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(UUID orgId);

    List<Warehouse> findByOrgIdAndIsDeletedFalseOrderByName(UUID orgId);

    boolean existsByOrgIdAndCodeAndIsDeletedFalse(UUID orgId, String code);

    /** Clear the current default before inserting or promoting another one. */
    @Modifying
    @Query(value = """
            UPDATE warehouse
               SET is_default = FALSE
             WHERE org_id = :orgId
               AND is_default = TRUE
               AND is_deleted = FALSE
            """, nativeQuery = true)
    int clearDefault(@Param("orgId") UUID orgId);

    /** Clear the current default without changing the selected warehouse. */
    @Modifying
    @Query(value = """
            UPDATE warehouse
               SET is_default = FALSE
             WHERE org_id = :orgId
               AND id <> :warehouseId
               AND is_default = TRUE
               AND is_deleted = FALSE
            """, nativeQuery = true)
    int clearDefaultExcept(@Param("orgId") UUID orgId,
                           @Param("warehouseId") UUID warehouseId);
}
