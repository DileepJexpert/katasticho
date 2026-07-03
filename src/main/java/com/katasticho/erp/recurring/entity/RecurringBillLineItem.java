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
 * {@link RecurringBill#lineItems}. Defaults to a SERVICE line — recurring
 * bills are usually rent / subscriptions / retainers with no catalog item
 * (a GOODS line requires an itemId at generation time).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class RecurringBillLineItem {

    /** GOODS | SERVICE; defaults to SERVICE on the DTO side. */
    private String lineType;

    /** Required for GOODS lines. */
    private UUID itemId;

    private String description;

    private String hsnCode;

    private BigDecimal quantity;

    private BigDecimal unitPrice;

    /** 0..100. */
    private BigDecimal discountPercent;

    /** GST rate. */
    private BigDecimal gstRate;

    /** GL expense/purchase account code; defaults to the purchase account. */
    private String accountCode;

    private UUID unitUomId;
}
