package com.katasticho.erp.indent.dto;

public record IndentSummary(
        long pending,
        long ordered,
        long arrived
) {}
