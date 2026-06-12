package com.katasticho.erp.common.currency.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Org-scoped exchange rate between two currencies on a specific date.
 */
@Entity
@Table(name = "exchange_rate")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ExchangeRate extends BaseEntity {

    @Column(name = "from_currency", length = 3, nullable = false)
    private String fromCurrency;

    @Column(name = "to_currency", length = 3, nullable = false)
    private String toCurrency;

    @Column(nullable = false, precision = 15, scale = 6)
    private BigDecimal rate;

    @Column(name = "effective_date", nullable = false)
    private LocalDate effectiveDate;

    @Column(length = 30, nullable = false)
    @Builder.Default
    private String source = "MANUAL";
}
