package com.katasticho.erp.procurement.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "debit_note")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DebitNote extends BaseEntity {

    @Column(name = "supplier_id", nullable = false)
    private UUID supplierId;

    @Column(name = "debit_note_number", nullable = false, length = 30)
    private String debitNoteNumber;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "note_date", nullable = false)
    private LocalDate noteDate;

    @Column(name = "return_reason", nullable = false, length = 50)
    private String returnReason;

    @Column(name = "reference_bill_id")
    private UUID referenceBillId;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(nullable = false, precision = 19, scale = 4)
    @Builder.Default
    private BigDecimal subtotal = BigDecimal.ZERO;

    @Column(name = "tax_amount", nullable = false, precision = 19, scale = 4)
    @Builder.Default
    private BigDecimal taxAmount = BigDecimal.ZERO;

    @Column(name = "total_amount", nullable = false, precision = 19, scale = 4)
    @Builder.Default
    private BigDecimal totalAmount = BigDecimal.ZERO;

    @OneToMany(mappedBy = "debitNote", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<DebitNoteLine> lines = new ArrayList<>();
}
