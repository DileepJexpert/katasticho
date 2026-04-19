package com.katasticho.erp.sales.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "delivery_challan")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DeliveryChallan extends BaseEntity {

    @Column(name = "branch_id")
    private UUID branchId;

    @Column(name = "challan_number", nullable = false, length = 30)
    private String challanNumber;

    @Column(name = "sales_order_id", nullable = false)
    private UUID salesOrderId;

    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    @Column(name = "challan_date", nullable = false)
    private LocalDate challanDate;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "dispatch_date")
    private LocalDate dispatchDate;

    @Column(name = "warehouse_id")
    private UUID warehouseId;

    @Column(name = "delivery_method", length = 50)
    private String deliveryMethod;

    @Column(name = "vehicle_number", length = 30)
    private String vehicleNumber;

    @Column(name = "tracking_number", length = 100)
    private String trackingNumber;

    private String notes;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "shipping_address", columnDefinition = "jsonb")
    private String shippingAddress;

    @OneToMany(mappedBy = "deliveryChallan", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<DeliveryChallanLine> lines = new ArrayList<>();

    public void addLine(DeliveryChallanLine line) {
        lines.add(line);
        line.setDeliveryChallan(this);
    }
}
