package com.katasticho.erp.recurring.entity;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * A single template line inside the JSONB payload on
 * {@link RecurringInvoice#lineItems}. Hibernate + Jackson can
 * serialise this via {@code @JdbcTypeCode(SqlTypes.JSON)} as long
 * as the shape stays simple and serialisable.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class RecurringLineItem {

    /** Optional catalog reference; free-text lines leave this null. */
    private UUID itemId;

    private String description;

    private String unit;

    private String hsnCode;

    /** Defaults to 1 on the DTO side if omitted. */
    private BigDecimal quantity;

    /** Unit price. */
    private BigDecimal rate;

    /** 0..100. */
    private BigDecimal discountPct;

    /** GST rate, 0..28 in practice. */
    private BigDecimal taxRate;

    /**
     * GL revenue account code to book this line against. Defaults
     * to the system default revenue account if the caller omits it.
     */
    private String accountCode;
}
