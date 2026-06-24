package com.katasticho.erp.procurement.rfq.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

@Entity
@Table(name = "rfq")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Rfq extends BaseEntity {

    @Column(name = "rfq_number", nullable = false, length = 30)
    private String rfqNumber;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "due_date")
    private LocalDate dueDate;

    @Column(columnDefinition = "TEXT")
    private String notes;
}
