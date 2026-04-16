package com.katasticho.erp.pos.repository;

import com.katasticho.erp.pos.entity.SalesReceiptLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface SalesReceiptLineRepository extends JpaRepository<SalesReceiptLine, UUID> {

    List<SalesReceiptLine> findByReceiptIdOrderByLineNumber(UUID receiptId);
}
