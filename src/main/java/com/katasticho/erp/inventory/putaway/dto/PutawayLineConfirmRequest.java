package com.katasticho.erp.inventory.putaway.dto;

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
public class PutawayLineConfirmRequest {
    @NotNull(message = "Confirmed rack location ID is required")
    private UUID confirmedRackId;
}