package com.katasticho.erp.pos.dto;

import java.math.BigDecimal;

public record OpenRegisterRequest(BigDecimal openingBalance, String notes) {}
