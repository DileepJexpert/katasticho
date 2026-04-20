package com.katasticho.erp.expense.repository;

import com.katasticho.erp.expense.entity.Expense;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ExpenseRepository extends JpaRepository<Expense, UUID> {

    Optional<Expense> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<Expense> findByOrgIdAndIsDeletedFalseOrderByExpenseDateDescCreatedAtDesc(
            UUID orgId, Pageable pageable);

    Page<Expense> findByOrgIdAndExpenseDateBetweenAndIsDeletedFalseOrderByExpenseDateDescCreatedAtDesc(
            UUID orgId, LocalDate from, LocalDate to, Pageable pageable);

    Page<Expense> findByOrgIdAndCategoryAndIsDeletedFalseOrderByExpenseDateDescCreatedAtDesc(
            UUID orgId, String category, Pageable pageable);

    Page<Expense> findByOrgIdAndExpenseDateBetweenAndCategoryAndIsDeletedFalseOrderByExpenseDateDescCreatedAtDesc(
            UUID orgId, LocalDate from, LocalDate to, String category, Pageable pageable);

    Page<Expense> findByOrgIdAndContactIdAndIsDeletedFalseOrderByExpenseDateDescCreatedAtDesc(
            UUID orgId, UUID contactId, Pageable pageable);

    @Query("SELECT COALESCE(SUM(e.total), 0) FROM Expense e WHERE e.orgId = :orgId AND e.expenseDate = :date AND e.isDeleted = false")
    BigDecimal sumTotalByOrgAndDate(UUID orgId, LocalDate date);
}
