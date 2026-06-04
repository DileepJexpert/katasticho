package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.StockCountLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface StockCountLineRepository extends JpaRepository<StockCountLine, UUID> {
}
