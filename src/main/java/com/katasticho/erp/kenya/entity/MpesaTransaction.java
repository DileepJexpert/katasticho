package com.katasticho.erp.kenya.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "mpesa_transaction")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MpesaTransaction extends BaseEntity {

    @Column(name = "mpesa_receipt_number", nullable = false, length = 50)
    private String mpesaReceiptNumber;

    @Column(name = "transaction_type", nullable = false, length = 50)
    @Builder.Default
    private String transactionType = "STK_PUSH_C2B";

    @Column(name = "phone_number", nullable = false, length = 30)
    private String phoneNumber;

    @Column(name = "amount", nullable = false, precision = 15, scale = 4)
    private BigDecimal amount;

    @Column(name = "party_name", length = 150)
    private String partyName;

    @Column(name = "account_reference", length = 100)
    private String accountReference;

    @Column(name = "status", nullable = false, length = 30)
    @Builder.Default
    private String status = "COMPLETED"; // PENDING, COMPLETED, FAILED, RECONCILED

    @Column(name = "matched_invoice_id")
    private UUID matchedInvoiceId;

    @Column(name = "matched_journal_entry_id")
    private UUID matchedJournalEntryId;

    @Column(name = "transaction_time", nullable = false)
    @Builder.Default
    private Instant transactionTime = Instant.now();
}