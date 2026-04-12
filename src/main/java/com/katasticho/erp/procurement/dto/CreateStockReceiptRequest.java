package com.katasticho.erp.procurement.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreateStockReceiptRequest(
        @NotNull UUID supplierId,
        UUID warehouseId,                  // optional — defaults to org default
        @NotNull LocalDate receiptDate,
        String supplierInvoiceNo,
        LocalDate supplierInvoiceDate,
        String notes,
        @NotEmpty @Valid List<StockReceiptLineRequest> lines
) {}
