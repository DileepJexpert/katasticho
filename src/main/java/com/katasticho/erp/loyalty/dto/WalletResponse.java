package com.katasticho.erp.loyalty.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record WalletResponse(
        UUID id,
        UUID contactId,
        BigDecimal balance,
        BigDecimal totalEarned,
        BigDecimal totalRedeemed,
        BigDecimal maxRedeemable  // min(balance, will be calculated per sale)
) {}
