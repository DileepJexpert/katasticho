package com.katasticho.erp.common.currency.repository;

import com.katasticho.erp.common.currency.entity.ExchangeRate;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ExchangeRateRepository extends JpaRepository<ExchangeRate, UUID> {

    /**
     * Find the rate for a specific date, for a given org and currency pair.
     */
    Optional<ExchangeRate> findByOrgIdAndFromCurrencyAndToCurrencyAndEffectiveDateAndIsDeletedFalse(
            UUID orgId, String fromCurrency, String toCurrency, LocalDate effectiveDate);

    /**
     * Find the most recent rate on or before the given date.
     */
    @Query("""
            SELECT er FROM ExchangeRate er
            WHERE er.orgId = :orgId
              AND er.fromCurrency = :from
              AND er.toCurrency   = :to
              AND er.effectiveDate <= :date
              AND er.isDeleted = false
            ORDER BY er.effectiveDate DESC
            LIMIT 1
            """)
    Optional<ExchangeRate> findLatestRate(
            @Param("orgId") UUID orgId,
            @Param("from") String fromCurrency,
            @Param("to") String toCurrency,
            @Param("date") LocalDate date);

    /**
     * All active rates for a base (from) currency for this org.
     */
    @Query("""
            SELECT er FROM ExchangeRate er
            WHERE er.orgId = :orgId
              AND er.fromCurrency = :base
              AND er.isDeleted = false
            ORDER BY er.toCurrency, er.effectiveDate DESC
            """)
    List<ExchangeRate> findAllForBase(
            @Param("orgId") UUID orgId,
            @Param("base") String baseCurrency);
}
