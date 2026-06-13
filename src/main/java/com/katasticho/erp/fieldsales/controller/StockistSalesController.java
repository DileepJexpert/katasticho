package com.katasticho.erp.fieldsales.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.fieldsales.entity.StockistSalesStatement;
import com.katasticho.erp.fieldsales.service.StockistSalesService;
import com.katasticho.erp.fieldsales.service.StockistSalesService.LineInput;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

/** Stockist secondary sales / Stock &amp; Sales Statement (SSS). */
@RestController
@RequestMapping("/api/v1/field-sales/secondary-sales")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.FIELD_SALES)
@PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
public class StockistSalesController {

    private final StockistSalesService service;

    @PostMapping("/statements")
    public ResponseEntity<ApiResponse<Map<String, Object>>> save(@RequestBody Map<String, Object> body) {
        UUID stockistId = UUID.fromString(body.get("stockistContactId").toString());
        LocalDate month = LocalDate.parse(body.get("periodMonth").toString());
        String notes = (String) body.get("notes");
        List<LineInput> lines = parseLines(body.get("lines"));
        return ResponseEntity.ok(ApiResponse.ok(
                service.saveStatement(stockistId, month, notes, lines), "Statement saved"));
    }

    @PostMapping("/statements/{id}/submit")
    public ResponseEntity<ApiResponse<StockistSalesStatement>> submit(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.submit(id), "Statement submitted"));
    }

    @GetMapping("/statements/{id}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getStatement(id)));
    }

    @GetMapping("/statements")
    public ResponseEntity<ApiResponse<List<StockistSalesStatement>>> list(
            @RequestParam(required = false) UUID stockistId,
            @RequestParam(required = false)
            @org.springframework.format.annotation.DateTimeFormat(iso =
                    org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate month) {
        if (stockistId != null) {
            return ResponseEntity.ok(ApiResponse.ok(service.listByStockist(stockistId)));
        }
        if (month != null) {
            return ResponseEntity.ok(ApiResponse.ok(service.listByPeriod(month)));
        }
        return ResponseEntity.ok(ApiResponse.ok(List.of()));
    }

    @GetMapping("/reports/secondary-sales")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> secondarySales(
            @RequestParam @org.springframework.format.annotation.DateTimeFormat(iso =
                    org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @org.springframework.format.annotation.DateTimeFormat(iso =
                    org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(ApiResponse.ok(service.secondarySalesReport(from, to)));
    }

    @GetMapping("/reports/stock-on-hand")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> stockOnHand(
            @RequestParam @org.springframework.format.annotation.DateTimeFormat(iso =
                    org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate month) {
        return ResponseEntity.ok(ApiResponse.ok(service.stockOnHand(month)));
    }

    @SuppressWarnings("unchecked")
    private List<LineInput> parseLines(Object raw) {
        List<LineInput> lines = new ArrayList<>();
        if (!(raw instanceof List<?> list)) return lines;
        for (Object o : list) {
            Map<String, Object> m = (Map<String, Object>) o;
            lines.add(new LineInput(
                    m.get("itemId") != null ? UUID.fromString(m.get("itemId").toString()) : null,
                    (String) m.get("productName"),
                    num(m.get("openingQty")), num(m.get("purchaseQty")),
                    num(m.get("salesQty")), num(m.get("returnQty")),
                    num(m.get("salesValue"))));
        }
        return lines;
    }

    private static BigDecimal num(Object o) {
        if (o == null) return null;
        if (o instanceof Number n) return new BigDecimal(n.toString());
        try {
            return new BigDecimal(o.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
