package com.katasticho.erp.reporting.service;

import com.katasticho.erp.reporting.dto.*;
import com.katasticho.erp.common.context.TenantContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class InventoryReportService {

    private final JdbcTemplate jdbcTemplate;

    @Transactional(readOnly = true)
    public StockSummaryReport getStockSummary() {
        UUID orgId = TenantContext.getCurrentOrgId();

        String query = """
            SELECT
              i.id,
              i.name,
              i.sku,
              i.unit_of_measure as unit,
              COALESCE(sb.quantity_on_hand, 0) as qty_on_hand,
              i.purchase_price,
              COALESCE(sb.quantity_on_hand, 0) * i.purchase_price as inventory_value,
              COALESCE(i.reorder_level, 0) as reorder_level,
              CASE
                WHEN COALESCE(sb.quantity_on_hand, 0) <= COALESCE(i.reorder_level, 0) THEN 'LOW'
                WHEN COALESCE(sb.quantity_on_hand, 0) = 0 THEN 'OUT_OF_STOCK'
                ELSE 'NORMAL'
              END as status,
              COALESCE(sb.average_cost, i.purchase_price) as average_cost,
              sb.last_movement_at
            FROM item i
            LEFT JOIN stock_balance sb ON i.id = sb.item_id AND i.org_id = sb.org_id
            WHERE i.org_id = ? AND i.is_deleted = false AND i.track_inventory = true
            ORDER BY status DESC, inventory_value DESC
            """;

        List<StockSummaryReport.Item> items = jdbcTemplate.query(query,
            (rs, rowNum) -> new StockSummaryReport.Item(
                rs.getObject("id", UUID.class),
                rs.getString("name"),
                rs.getString("sku"),
                rs.getString("unit"),
                rs.getBigDecimal("qty_on_hand"),
                rs.getBigDecimal("purchase_price"),
                rs.getBigDecimal("inventory_value"),
                rs.getBigDecimal("reorder_level"),
                rs.getString("status"),
                rs.getBigDecimal("average_cost"),
                rs.getTimestamp("last_movement_at") != null ? rs.getTimestamp("last_movement_at").toInstant() : null
            ),
            orgId
        );

        BigDecimal totalValue = items.stream()
            .map(StockSummaryReport.Item::inventoryValue)
            .reduce(BigDecimal.ZERO, BigDecimal::add);

        int lowStockCount = (int) items.stream()
            .filter(i -> "LOW".equals(i.status()))
            .count();

        int outOfStockCount = (int) items.stream()
            .filter(i -> "OUT_OF_STOCK".equals(i.status()))
            .count();

        return new StockSummaryReport(
            LocalDate.now(),
            totalValue,
            items.size(),
            lowStockCount,
            outOfStockCount,
            items
        );
    }

    @Transactional(readOnly = true)
    public StockMovementReport getStockMovement(UUID itemId, LocalDate startDate, LocalDate endDate, int pageNo, int pageSize) {
        UUID orgId = TenantContext.getCurrentOrgId();

        String query = """
            SELECT
              sm.movement_date,
              sm.movement_type,
              i.name as item_name,
              i.sku,
              sm.quantity,
              COALESCE(sm.unit_cost, 0) as unit_cost,
              COALESCE(sm.total_cost, 0) as total_cost,
              sm.reference_type,
              sm.reference_number,
              sm.notes,
              COALESCE(sb.quantity_on_hand, 0) as balance_after
            FROM stock_movement sm
            JOIN item i ON sm.item_id = i.id
            LEFT JOIN stock_balance sb ON sm.item_id = sb.item_id AND sm.warehouse_id = sb.warehouse_id
            WHERE sm.org_id = ? AND sm.movement_date BETWEEN ? AND ?
              AND (? IS NULL OR sm.item_id = ?)
            ORDER BY sm.movement_date DESC, sm.id DESC
            LIMIT ? OFFSET ?
            """;

        List<StockMovementReport.Movement> movements = jdbcTemplate.query(query,
            (rs, rowNum) -> new StockMovementReport.Movement(
                rs.getObject("movement_date", LocalDate.class),
                rs.getString("movement_type"),
                rs.getString("item_name"),
                rs.getString("sku"),
                rs.getBigDecimal("quantity"),
                rs.getBigDecimal("unit_cost"),
                rs.getBigDecimal("total_cost"),
                rs.getString("reference_type"),
                rs.getString("reference_number"),
                rs.getString("notes"),
                rs.getBigDecimal("balance_after")
            ),
            orgId, startDate, endDate, itemId, itemId,
            pageSize, (long) pageNo * pageSize
        );

        return new StockMovementReport(startDate, endDate, itemId, movements);
    }
}
