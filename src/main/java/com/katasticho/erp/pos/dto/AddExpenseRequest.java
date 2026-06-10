package com.katasticho.erp.pos.dto;

import java.math.BigDecimal;

public record AddExpenseRequest(BigDecimal amount, String description) {}
