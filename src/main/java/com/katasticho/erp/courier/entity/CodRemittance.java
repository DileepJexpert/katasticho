package com.katasticho.erp.courier.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/**
 * One COD remittance file/payout from a courier — the courier collected cash
 * from N customers, withheld their fees, and deposited the net to our bank in a
 * single transfer. This row carries those totals plus per-AWB lines; on reconcile
 * it auto-settles the matched invoices and books the fees + any variance.
 *
 * <p>{@code DRAFT} → {@code RECONCILED} once {@code CodReconciliationService} has
 * walked the lines and posted payments.
 */
@Entity
@Table(name = "cod_remittance")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CodRemittance extends BaseEntity {

    @Column(name = "remittance_number", nullable = false, length = 40)
    private String remittanceNumber;

    @Column(name = "courier_partner", nullable = false, length = 40)
    private String courierPartner;

    @Column(name = "remittance_date", nullable = false)
    private LocalDate remittanceDate;

    @Column(name = "bank_account", length = 80)
    private String bankAccount;

    @Column(length = 60)
    private String utr;

    @Column(name = "gross_collected", nullable = false)
    @Builder.Default
    private BigDecimal grossCollected = BigDecimal.ZERO;

    @Column(name = "total_fees", nullable = false)
    @Builder.Default
    private BigDecimal totalFees = BigDecimal.ZERO;

    @Column(name = "net_remitted", nullable = false)
    @Builder.Default
    private BigDecimal netRemitted = BigDecimal.ZERO;

    @Column(name = "expected_net", nullable = false)
    @Builder.Default
    private BigDecimal expectedNet = BigDecimal.ZERO;

    /** {@code net_remitted - expected_net}: positive = courier paid us more than expected. */
    @Column(nullable = false)
    @Builder.Default
    private BigDecimal variance = BigDecimal.ZERO;

    /** DRAFT | RECONCILED */
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT";

    private String notes;

    @OneToMany(mappedBy = "remittance", cascade = CascadeType.ALL, orphanRemoval = true,
            fetch = FetchType.LAZY)
    @Builder.Default
    private List<CodRemittanceLine> lines = new ArrayList<>();
}
