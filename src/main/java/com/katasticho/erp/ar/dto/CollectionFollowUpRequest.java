package com.katasticho.erp.ar.dto;

import java.time.LocalDate;

public record CollectionFollowUpRequest(
        String status,
        LocalDate promiseToPayDate,
        String note
) {
}
