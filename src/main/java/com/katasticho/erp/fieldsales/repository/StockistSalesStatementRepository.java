package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.StockistSalesStatement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface StockistSalesStatementRepository extends JpaRepository<StockistSalesStatement, UUID> {

    Optional<StockistSalesStatement> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<StockistSalesStatement> findByOrgIdAndStockistContactIdAndPeriodMonthAndIsDeletedFalse(
            UUID orgId, UUID stockistContactId, LocalDate periodMonth);

    List<StockistSalesStatement> findByOrgIdAndStockistContactIdAndIsDeletedFalseOrderByPeriodMonthDesc(
            UUID orgId, UUID stockistContactId);

    List<StockistSalesStatement> findByOrgIdAndPeriodMonthAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, LocalDate periodMonth);

    List<StockistSalesStatement> findByOrgIdAndPeriodMonthBetweenAndIsDeletedFalse(
            UUID orgId, LocalDate from, LocalDate to);
}
