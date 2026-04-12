package com.katasticho.erp.inventory.entity;

/**
 * Source-document tag on a stock movement. Lets reports trace any movement
 * back to the business event that produced it.
 */
public enum ReferenceType {
    INVOICE,
    CREDIT_NOTE,
    BILL,
    DEBIT_NOTE,
    STOCK_ADJUSTMENT,
    STOCK_TRANSFER,
    STOCK_COUNT,
    OPENING_BALANCE
}
