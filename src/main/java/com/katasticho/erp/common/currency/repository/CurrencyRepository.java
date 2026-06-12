package com.katasticho.erp.common.currency.repository;

import com.katasticho.erp.common.currency.entity.Currency;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CurrencyRepository extends JpaRepository<Currency, UUID> {

    List<Currency> findByIsActiveTrue();

    Optional<Currency> findByCode(String code);
}
