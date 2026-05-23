package com.katasticho.erp.sales.entity;

public enum SalesOrderStatus {
    DRAFT,
    CONFIRMED,
    BACKORDER,
    PARTIALLY_SHIPPED,
    SHIPPED,
    PARTIALLY_INVOICED,
    INVOICED,
    COMPLETED,
    CANCELLED,
    VOID
}
