package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.BudgetLine;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.repository.BudgetLineRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.*;

/**
 * Budgets v1: an annual amount per account per fiscal year, edited as a flat
 * list. Saving replaces the FY's lines (upsert + soft-delete removed ones) so
 * the editor can simply PUT what it shows. Variance lives in
 * {@link OperationalReportService#budgetVariance}.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class BudgetService {

    private final BudgetLineRepository budgetLineRepository;
    private final AccountRepository accountRepository;

    public record BudgetLineDto(String accountCode, String accountName,
                                BigDecimal annualAmount, String notes) {}

    @Transactional(readOnly = true)
    public List<BudgetLineDto> list(int fiscalYear) {
        UUID orgId = requireOrgId();
        Map<String, String> names = accountNames(orgId);
        return budgetLineRepository
                .findByOrgIdAndFiscalYearAndIsDeletedFalseOrderByAccountCode(orgId, fiscalYear)
                .stream()
                .map(b -> new BudgetLineDto(b.getAccountCode(),
                        names.getOrDefault(b.getAccountCode(), b.getAccountCode()),
                        b.getAnnualAmount(), b.getNotes()))
                .toList();
    }

    /** Replace the FY's budget with the given lines (upsert; missing = removed). */
    @Transactional
    public List<BudgetLineDto> save(int fiscalYear, List<BudgetLineDto> lines) {
        UUID orgId = requireOrgId();

        Map<String, BudgetLineDto> wanted = new LinkedHashMap<>();
        for (BudgetLineDto dto : lines == null ? List.<BudgetLineDto>of() : lines) {
            String code = dto.accountCode() == null ? "" : dto.accountCode().trim();
            if (code.isEmpty()) continue;
            if (accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, code).isEmpty()) {
                throw new BusinessException("No account with code " + code,
                        "BUDGET_ACCOUNT_NOT_FOUND", HttpStatus.BAD_REQUEST);
            }
            wanted.put(code, dto);
        }

        List<BudgetLine> existing = budgetLineRepository
                .findByOrgIdAndFiscalYearAndIsDeletedFalseOrderByAccountCode(orgId, fiscalYear);
        for (BudgetLine line : existing) {
            BudgetLineDto dto = wanted.remove(line.getAccountCode());
            if (dto == null) {
                line.setDeleted(true);                     // removed from the editor
            } else {
                line.setAnnualAmount(nz(dto.annualAmount()));
                line.setNotes(trim(dto.notes()));
            }
            budgetLineRepository.save(line);
        }
        for (BudgetLineDto dto : wanted.values()) {        // new lines
            BudgetLine line = BudgetLine.builder()
                    .fiscalYear(fiscalYear)
                    .accountCode(dto.accountCode().trim())
                    .annualAmount(nz(dto.annualAmount()))
                    .notes(trim(dto.notes()))
                    .build();
            line.setOrgId(orgId);
            budgetLineRepository.save(line);
        }

        log.info("Budget FY{} saved: {} line(s)", fiscalYear, lines == null ? 0 : lines.size());
        return list(fiscalYear);
    }

    private Map<String, String> accountNames(UUID orgId) {
        Map<String, String> names = new HashMap<>();
        for (Account a : accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId)) {
            names.put(a.getCode(), a.getName());
        }
        return names;
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    private static String trim(String s) {
        if (s == null) return null;
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
