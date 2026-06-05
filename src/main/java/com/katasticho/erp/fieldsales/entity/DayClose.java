package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "day_close")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DayClose extends BaseEntity {

    @Column(name = "route_execution_id", nullable = false)
    private UUID routeExecutionId;

    @Column(name = "salesperson_id", nullable = false)
    private UUID salespersonId;

    @Column(name = "van_id")
    private UUID vanId;

    @Column(name = "close_date", nullable = false)
    private LocalDate closeDate;

    @Column(length = 20)
    @Builder.Default
    private String status = "PENDING";

    // --- Cash fields ---

    @Column(name = "opening_cash")
    private BigDecimal openingCash;

    @Column(name = "cash_collections")
    private BigDecimal cashCollections;

    @Column(name = "cash_expenses")
    private BigDecimal cashExpenses;

    @Column(name = "closing_cash")
    private BigDecimal closingCash;

    @Column(name = "cash_deposited")
    private BigDecimal cashDeposited;

    @Column(name = "cash_variance")
    private BigDecimal cashVariance;

    // --- Stock fields ---

    @Column(name = "items_loaded")
    private Integer itemsLoaded;

    @Column(name = "items_sold")
    private Integer itemsSold;

    @Column(name = "items_returned")
    private Integer itemsReturned;

    @Column(name = "items_closing")
    private Integer itemsClosing;

    @Column(name = "stock_variance_count")
    private Integer stockVarianceCount;

    // --- Visit fields ---

    @Column(name = "visits_planned")
    private Integer visitsPlanned;

    @Column(name = "visits_completed")
    private Integer visitsCompleted;

    @Column(name = "visits_productive")
    private Integer visitsProductive;

    // --- Financial fields ---

    @Column(name = "total_orders_value")
    private BigDecimal totalOrdersValue;

    @Column(name = "total_collections")
    private BigDecimal totalCollections;

    @Column(name = "total_returns_value")
    private BigDecimal totalReturnsValue;

    // --- Approval fields ---

    @Column(name = "approved_by")
    private UUID approvedBy;

    @Column(name = "approved_at")
    private Instant approvedAt;

    @Column(name = "rejection_reason")
    private String rejectionReason;

    private String notes;
}
