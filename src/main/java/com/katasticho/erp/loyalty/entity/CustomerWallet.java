package com.katasticho.erp.loyalty.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "customer_wallet")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CustomerWallet extends BaseEntity {

    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    @Column(name = "balance", nullable = false)
    @Builder.Default
    private BigDecimal balance = BigDecimal.ZERO;

    @Column(name = "total_earned", nullable = false)
    @Builder.Default
    private BigDecimal totalEarned = BigDecimal.ZERO;

    @Column(name = "total_redeemed", nullable = false)
    @Builder.Default
    private BigDecimal totalRedeemed = BigDecimal.ZERO;
}
