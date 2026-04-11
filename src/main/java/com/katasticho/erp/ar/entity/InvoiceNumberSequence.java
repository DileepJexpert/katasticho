package com.katasticho.erp.ar.entity;

import jakarta.persistence.*;
import lombok.*;

import java.io.Serializable;
import java.util.UUID;

@Entity
@Table(name = "invoice_number_sequence")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class InvoiceNumberSequence {

    @EmbeddedId
    private InvoiceNumberSequenceId id;

    @Column(name = "next_value", nullable = false)
    @Builder.Default
    private Long nextValue = 1L;

    @Embeddable
    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    @EqualsAndHashCode
    public static class InvoiceNumberSequenceId implements Serializable {
        @Column(name = "org_id")
        private UUID orgId;

        @Column(length = 10)
        private String prefix;

        private int year;
    }
}
