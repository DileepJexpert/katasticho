package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.dto.AccountResponse;
import com.katasticho.erp.accounting.dto.CreateAccountRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import com.katasticho.erp.common.service.SeedResult;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class AccountService {

    private final AccountRepository accountRepository;
    private final JdbcTemplate jdbcTemplate;

    public List<AccountResponse> listAccounts(UUID orgId) {
        return accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public AccountResponse createAccount(CreateAccountRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        if (accountRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, request.code())) {
            throw BusinessException.conflict("Account code already exists: " + request.code(), "ACCT_CODE_EXISTS");
        }

        UUID parentId = null;
        int level = 1;
        if (request.parentCode() != null) {
            Account parent = accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, request.parentCode())
                    .orElseThrow(() -> new BusinessException(
                            "Parent account not found: " + request.parentCode(),
                            "ACCT_PARENT_NOT_FOUND", HttpStatus.BAD_REQUEST));
            parentId = parent.getId();
            level = parent.getLevel() + 1;
            if (level > 5) {
                throw new BusinessException("Account hierarchy cannot exceed 5 levels", "ACCT_MAX_LEVEL");
            }
        }

        Account account = Account.builder()
                .code(request.code())
                .name(request.name())
                .type(request.type())
                .subType(request.subType())
                .parentId(parentId)
                .level(level)
                .description(request.description())
                .openingBalance(request.openingBalance() != null ? request.openingBalance() : BigDecimal.ZERO)
                .build();

        account = accountRepository.save(account);
        log.info("Account created: {} - {} ({})", account.getCode(), account.getName(), account.getType());
        return toResponse(account);
    }

    /**
     * Seed accounts from industry template into an org.
     * Called during signup or manual template application.
     */
    @Transactional
    public SeedResult seedFromTemplate(UUID orgId, String industry) {
        String templateIndustry = resolveIndustry(industry);

        // Fetch template rows
        List<Map<String, Object>> templates = jdbcTemplate.queryForList(
                "SELECT code, name, type, sub_type, parent_code, level, is_system FROM coa_template WHERE industry = ? ORDER BY code",
                templateIndustry);

        if (templates.isEmpty()) {
            log.warn("No CoA template found for industry: {}", industry);
            return SeedResult.ALREADY_EXISTS;
        }

        // First pass: create all accounts without parents
        Map<String, UUID> codeToId = new HashMap<>();
        for (Map<String, Object> tmpl : templates) {
            String code = (String) tmpl.get("code");
            if (accountRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, code)) {
                continue;
            }

            Account account = Account.builder()
                    .code(code)
                    .name((String) tmpl.get("name"))
                    .type((String) tmpl.get("type"))
                    .subType((String) tmpl.get("sub_type"))
                    .level((Integer) tmpl.get("level"))
                    .system((Boolean) tmpl.get("is_system"))
                    .build();
            account.setOrgId(orgId);
            account = accountRepository.save(account);
            codeToId.put(code, account.getId());
        }

        // Second pass: link parents
        for (Map<String, Object> tmpl : templates) {
            String parentCode = (String) tmpl.get("parent_code");
            if (parentCode != null) {
                String code = (String) tmpl.get("code");
                UUID accountId = codeToId.get(code);
                UUID parentId = codeToId.get(parentCode);
                if (accountId != null && parentId != null) {
                    accountRepository.findById(accountId).ifPresent(a -> {
                        a.setParentId(parentId);
                        accountRepository.save(a);
                    });
                }
            }
        }

        log.info("Seeded {} accounts from {} template for org {}", codeToId.size(), templateIndustry, orgId);
        if (codeToId.isEmpty()) return SeedResult.ALREADY_EXISTS;
        if (codeToId.size() < templates.size()) return SeedResult.REPAIRED_PARTIAL;
        return SeedResult.CREATED_NEW;
    }

    private String resolveIndustry(String industry) {
        if (industry == null) return "TRADING";
        return switch (industry.toUpperCase()) {
            case "RETAIL" -> "RETAIL";
            case "SERVICES", "SERVICE" -> "SERVICES";
            case "FOOD", "F&B", "F_AND_B", "RESTAURANT" -> "F_AND_B";
            default -> "TRADING";
        };
    }

    public AccountResponse toResponse(Account account) {
        return new AccountResponse(
                account.getId(), account.getCode(), account.getName(),
                account.getType(), account.getSubType(), account.getParentId(),
                account.getLevel(), account.isSystem(), account.getOpeningBalance(),
                account.getCurrency(), account.isActive());
    }
}
