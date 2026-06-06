package com.katasticho.erp.partnernetwork.dto;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record ConfirmNetworkOrderRequest(
    String sellerNotes,
    List<LineConfirmation> lines
) {
    public record LineConfirmation(
        UUID lineId,
        BigDecimal confirmedQty,
        UUID sellerItemId,
        String sellerNotes
    ) {}
}
