package com.katasticho.erp.accounting.repository;

import com.katasticho.erp.accounting.entity.BudgetLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BudgetLineRepository extends JpaRepository<BudgetLine, UUID> {

    List<BudgetLine> findByOrgIdAndFiscalYearAndIsDeletedFalseOrderByAccountCode(UUID orgId, int fiscalYear);

    Optional<BudgetLine> findByOrgIdAndFiscalYearAndAccountCodeAndIsDeletedFalse(
            UUID orgId, int fiscalYear, String accountCode);
}
