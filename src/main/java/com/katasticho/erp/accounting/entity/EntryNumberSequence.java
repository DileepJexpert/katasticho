package com.katasticho.erp.accounting.entity;

import jakarta.persistence.*;
import lombok.*;

import java.io.Serializable;
import java.util.UUID;

@Entity
@Table(name = "entry_number_sequence")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EntryNumberSequence {

    @EmbeddedId
    private EntryNumberSequenceId id;

    @Column(name = "next_value", nullable = false)
    @Builder.Default
    private Long nextValue = 1L;

    @Embeddable
    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    @EqualsAndHashCode
    public static class EntryNumberSequenceId implements Serializable {

        @Column(name = "org_id", nullable = false)
        private UUID orgId;

        @Column(name = "year", nullable = false)
        private Integer year;
    }
}
