package com.katasticho.erp.kenya.dto;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class KraEtimsSubmitRequest {
    @NotNull(message = "Invoice ID is required")
    private UUID invoiceId;
}