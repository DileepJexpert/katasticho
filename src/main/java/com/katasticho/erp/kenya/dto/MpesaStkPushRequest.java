package com.katasticho.erp.kenya.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MpesaStkPushRequest {

    @NotBlank(message = "Phone number is required (e.g. 254712345678)")
    private String phoneNumber;

    @NotNull(message = "Amount is required")
    @DecimalMin(value = "1.00", message = "Amount must be at least KSh 1.00")
    private BigDecimal amount;

    private String accountReference;
    private String customerName;
    private UUID invoiceId;
}