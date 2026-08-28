package com.katasticho.erp.ap.dto;

import jakarta.validation.constraints.NotEmpty;
import java.util.List;
import java.util.UUID;

public record BulkPaymentExportRequest(
        @NotEmpty List<UUID> paymentIds,
        String format // GENERIC_NEFT_RTGS, HDFC_CMS, ICICI_CIB, SBI_CMP
) {}
