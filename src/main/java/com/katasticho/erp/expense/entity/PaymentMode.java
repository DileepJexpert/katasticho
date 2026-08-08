package com.katasticho.erp.expense.entity;

public enum PaymentMode {
    CASH,
    BANK,
    UPI,
    CREDIT_CARD,
    /** Used only by approved employee claims; cleared when the employee is paid. */
    EMPLOYEE_PAYABLE
}
