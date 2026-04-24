package com.katasticho.erp.common.cache.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record CachedCustomerOutstanding(
        UUID contactId,
        String displayName,
        BigDecimal outstandingAr,
        BigDecimal creditLimit,
        int openInvoiceCount
) {}
