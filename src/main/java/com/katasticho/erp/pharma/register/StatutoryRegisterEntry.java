package com.katasticho.erp.pharma.register;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * One row per sale of a scheduled drug. Auto-populated by
 * {@link StatutoryRegisterService#recordSaleEntries} after a POS receipt's
 * stock movements settle. Retained for {@link RegisterType#retentionYears()}
 * years (3y H1, 2y Schedule X / Narcotics) for drug-inspector audit.
 */
@Entity
@Table(name = "statutory_register_entry")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StatutoryRegisterEntry extends BaseEntity {

    @Enumerated(EnumType.STRING)
    @Column(name = "register_type", nullable = false, length = 20)
    private RegisterType registerType;

    @Column(name = "sale_receipt_id")
    private UUID saleReceiptId;

    @Column(name = "invoice_id")
    private UUID invoiceId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "drug_name", nullable = false, length = 255)
    private String drugName;

    @Column(name = "batch_id")
    private UUID batchId;

    @Column(name = "batch_number", length = 100)
    private String batchNumber;

    @Column(nullable = false, precision = 15, scale = 4)
    private BigDecimal quantity;

    @Column(name = "sale_date", nullable = false)
    private LocalDate saleDate;

    @Column(name = "retention_until", nullable = false)
    private LocalDate retentionUntil;

    @Column(name = "prescriber_name", length = 255)
    private String prescriberName;

    @Column(name = "prescriber_reg_number", length = 100)
    private String prescriberRegNumber;

    @Column(name = "prescriber_address", columnDefinition = "TEXT")
    private String prescriberAddress;

    @Column(name = "patient_name", length = 255)
    private String patientName;

    @Column(name = "patient_address", columnDefinition = "TEXT")
    private String patientAddress;

    @Column(name = "patient_phone", length = 20)
    private String patientPhone;

    @Column(columnDefinition = "TEXT")
    private String notes;
}
