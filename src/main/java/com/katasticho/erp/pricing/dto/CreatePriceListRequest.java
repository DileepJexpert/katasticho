package com.katasticho.erp.pricing.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreatePriceListRequest(
        @NotBlank(message = "Price list name is required")
        @Size(max = 100, message = "Price list name must be 100 characters or fewer")
        String name,

        String description,

        /** ISO-4217 code. Defaults to INR if null. */
        @Size(min = 3, max = 3, message = "Currency must be a 3-letter ISO code")
        String currency,

        /** When true, this list becomes the org default (the service
         *  flips the previous default off in the same tx). */
        boolean isDefault
) {}
