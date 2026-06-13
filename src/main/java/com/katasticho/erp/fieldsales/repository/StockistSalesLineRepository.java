package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.StockistSalesLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

@Repository
public interface StockistSalesLineRepository extends JpaRepository<StockistSalesLine, UUID> {

    List<StockistSalesLine> findByOrgIdAndStatementIdAndIsDeletedFalseOrderByProductNameAsc(
            UUID orgId, UUID statementId);

    List<StockistSalesLine> findByOrgIdAndStatementIdInAndIsDeletedFalse(
            UUID orgId, Collection<UUID> statementIds);

    void deleteByOrgIdAndStatementId(UUID orgId, UUID statementId);
}
