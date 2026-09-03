package com.katasticho.erp.inventory.putaway.dto;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PutawayTaskRequest {

    private UUID goodsReceiptId;

    @NotNull(message = "Warehouse ID is required")
    private UUID warehouseId;

    @Builder.Default
    private String sourceLocation = "RECEIVING_DOCK";

    private UUID assignedTo;
    private String notes;

    private List<PutawayLineRequest> lines;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PutawayLineRequest {
        @NotNull(message = "Item ID is required")
        private UUID itemId;
        private String batchNumber;
        @NotNull(message = "Quantity is required")
        private BigDecimal quantity;
        private UUID suggestedRackId;
    }
}