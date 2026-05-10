package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.entity.FiscalPeriod;
import com.katasticho.erp.accounting.repository.FiscalPeriodRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class FiscalPeriodService {

    private final FiscalPeriodRepository fiscalPeriodRepository;

    @Transactional
    public FiscalPeriod closePeriod(int periodYear, int periodMonth) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        FiscalPeriod period = fiscalPeriodRepository
                .findByOrgIdAndPeriodYearAndPeriodMonth(orgId, periodYear, periodMonth)
                .orElseGet(() -> FiscalPeriod.builder()
                        .orgId(orgId)
                        .periodYear(periodYear)
                        .periodMonth(periodMonth)
                        .status("OPEN")
                        .build());

        if ("LOCKED".equals(period.getStatus())) {
            throw new BusinessException(
                    "Period is locked and cannot be modified",
                    "ACCT_PERIOD_LOCKED", HttpStatus.CONFLICT);
        }

        period.setStatus("CLOSED");
        period.setClosedAt(Instant.now());
        period.setClosedBy(userId);
        period = fiscalPeriodRepository.save(period);

        log.info("Fiscal period {}-{} closed for org {}", periodYear, periodMonth, orgId);
        return period;
    }

    @Transactional
    public FiscalPeriod reopenPeriod(int periodYear, int periodMonth) {
        UUID orgId = TenantContext.getCurrentOrgId();

        FiscalPeriod period = fiscalPeriodRepository
                .findByOrgIdAndPeriodYearAndPeriodMonth(orgId, periodYear, periodMonth)
                .orElseThrow(() -> new BusinessException(
                        "Fiscal period not found",
                        "ACCT_PERIOD_NOT_FOUND", HttpStatus.NOT_FOUND));

        if ("LOCKED".equals(period.getStatus())) {
            throw new BusinessException(
                    "Period is locked and cannot be reopened",
                    "ACCT_PERIOD_LOCKED", HttpStatus.CONFLICT);
        }

        period.setStatus("OPEN");
        period.setClosedAt(null);
        period.setClosedBy(null);
        period = fiscalPeriodRepository.save(period);

        log.info("Fiscal period {}-{} reopened for org {}", periodYear, periodMonth, orgId);
        return period;
    }

    @Transactional
    public FiscalPeriod lockPeriod(int periodYear, int periodMonth) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        FiscalPeriod period = fiscalPeriodRepository
                .findByOrgIdAndPeriodYearAndPeriodMonth(orgId, periodYear, periodMonth)
                .orElseThrow(() -> new BusinessException(
                        "Fiscal period not found",
                        "ACCT_PERIOD_NOT_FOUND", HttpStatus.NOT_FOUND));

        if (!"CLOSED".equals(period.getStatus())) {
            throw new BusinessException(
                    "Only closed periods can be locked. Close the period first.",
                    "ACCT_PERIOD_NOT_CLOSED", HttpStatus.BAD_REQUEST);
        }

        period.setStatus("LOCKED");
        period.setClosedBy(userId);
        period = fiscalPeriodRepository.save(period);

        log.info("Fiscal period {}-{} locked for org {}", periodYear, periodMonth, orgId);
        return period;
    }
}
