package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.Warehouse;
import org.springframework.data.jpa.repository.JpaRepository;
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
}
