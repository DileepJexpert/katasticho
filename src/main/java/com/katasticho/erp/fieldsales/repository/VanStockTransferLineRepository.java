package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.VanStockTransferLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface VanStockTransferLineRepository extends JpaRepository<VanStockTransferLine, UUID> {

    List<VanStockTransferLine> findByOrgIdAndVanStockTransferId(UUID orgId, UUID vanStockTransferId);
}
