package com.katasticho.erp.sales.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "sales_order")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SalesOrder extends BaseEntity {

    @Column(name = "branch_id")
    private UUID branchId;

    @Column(name = "salesorder_number", nullable = false, length = 30)
    private String salesorderNumber;

    @Column(name = "reference_number", length = 50)
    private String referenceNumber;

    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    @Column(name = "estimate_id")
    private UUID estimateId;

    @Column(name = "order_date", nullable = false)
    private LocalDate orderDate;

    @Column(name = "expected_shipment_date")
    private LocalDate expectedShipmentDate;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "shipped_status", nullable = false, length = 20)
    @Builder.Default
    private String shippedStatus = "NOT_SHIPPED";

    @Column(name = "invoiced_status", nullable = false, length = 20)
    @Builder.Default
    private String invoicedStatus = "NOT_INVOICED";

    @Column(name = "discount_type", nullable = false, length = 20)
    @Builder.Default
    private String discountType = "ITEM_LEVEL";

    @Column(name = "discount_amount")
    @Builder.Default
    private BigDecimal discountAmount = BigDecimal.ZERO;

    @Builder.Default
    private BigDecimal subtotal = BigDecimal.ZERO;

    @Column(name = "tax_amount")
    @Builder.Default
    private BigDecimal taxAmount = BigDecimal.ZERO;

    @Column(name = "shipping_charge")
    @Builder.Default
    private BigDecimal shippingCharge = BigDecimal.ZERO;

    @Builder.Default
    private BigDecimal adjustment = BigDecimal.ZERO;

    @Column(name = "adjustment_description")
    private String adjustmentDescription;

    @Builder.Default
    private BigDecimal total = BigDecimal.ZERO;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "billing_address", columnDefinition = "jsonb")
    private String billingAddress;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "shipping_address", columnDefinition = "jsonb")
    private String shippingAddress;

    @Column(name = "payment_mode", length = 30)
    private String paymentMode;

    @Column(name = "delivery_method", length = 50)
    private String deliveryMethod;

    @Column(nullable = false, length = 3)
    @Builder.Default
    private String currency = "INR";

    @Column(name = "place_of_supply", length = 50)
    private String placeOfSupply;

    private String notes;

    private String terms;

    @OneToMany(mappedBy = "salesOrder", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<SalesOrderLine> lines = new ArrayList<>();

    public void addLine(SalesOrderLine line) {
        lines.add(line);
        line.setSalesOrder(this);
    }
}
