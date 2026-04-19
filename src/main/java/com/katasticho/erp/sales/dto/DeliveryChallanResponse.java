package com.katasticho.erp.sales.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record DeliveryChallanResponse(
        UUID id,
        String challanNumber,
        UUID salesOrderId,
        String salesOrderNumber,
        UUID contactId,
        String contactName,
        LocalDate challanDate,
        String status,
        LocalDate dispatchDate,
        UUID warehouseId,
        String warehouseName,
        String deliveryMethod,
        String vehicleNumber,
        String trackingNumber,
        String notes,
        String shippingAddress,
        List<DeliveryChallanLineResponse> lines,
        Instant createdAt
) {}
