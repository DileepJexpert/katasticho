package com.katasticho.erp.pos.dto;

import java.math.BigDecimal;

public record CloseRegisterRequest(BigDecimal actualClosing, String notes) {}
