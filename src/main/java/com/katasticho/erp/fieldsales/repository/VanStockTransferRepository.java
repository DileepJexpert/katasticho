package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.VanStockTransfer;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface VanStockTransferRepository extends JpaRepository<VanStockTransfer, UUID> {

    Optional<VanStockTransfer> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<VanStockTransfer> findByOrgIdAndVanIdAndIsDeletedFalse(UUID orgId, UUID vanId, Pageable pageable);

    Page<VanStockTransfer> findByOrgIdAndIsDeletedFalse(UUID orgId, Pageable pageable);
}
