package com.katasticho.erp.inventory.dto;

import lombok.Builder;

@Builder
public record BarcodeLabelResponse(
        String zplCode,
        String eplCode,
        int labelWidthDots,
        int labelHeightDots,
        int copies
) {}