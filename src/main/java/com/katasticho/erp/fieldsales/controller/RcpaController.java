package com.katasticho.erp.fieldsales.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.fieldsales.entity.RcpaAudit;
import com.katasticho.erp.fieldsales.service.RcpaService;
import com.katasticho.erp.fieldsales.service.RcpaService.LineInput;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

/** Retail Chemist Prescription Audit (RCPA): own-vs-competitor brand share. */
@RestController
@RequestMapping("/api/v1/mr/rcpa")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.FIELD_SALES)
@PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
public class RcpaController {

    private final RcpaService service;

    @PostMapping
    public ResponseEntity<ApiResponse<Map<String, Object>>> record(@RequestBody Map<String, Object> body) {
        UUID auditId = body.get("auditId") != null ? UUID.fromString(body.get("auditId").toString()) : null;
        UUID chemistId = UUID.fromString(body.get("chemistContactId").toString());
        LocalDate date = LocalDate.parse(body.get("auditDate").toString());
        UUID visitId = body.get("fieldVisitId") != null
                ? UUID.fromString(body.get("fieldVisitId").toString()) : null;
        String remarks = (String) body.get("remarks");
        return ResponseEntity.ok(ApiResponse.ok(
                service.record(auditId, chemistId, date, visitId, remarks, parseLines(body.get("lines"))),
                "RCPA saved"));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getAudit(id)));
    }

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<List<RcpaAudit>>> myAudits() {
        return ResponseEntity.ok(ApiResponse.ok(service.myAudits()));
    }

    @GetMapping("/by-chemist/{chemistId}")
    public ResponseEntity<ApiResponse<List<RcpaAudit>>> byChemist(@PathVariable UUID chemistId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listByChemist(chemistId)));
    }

    @GetMapping("/reports/share")
    public ResponseEntity<ApiResponse<Map<String, Object>>> share(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(ApiResponse.ok(service.shareReport(from, to)));
    }

    @GetMapping("/reports/competitors")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> competitors(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(ApiResponse.ok(service.competitorBrands(from, to)));
    }

    @SuppressWarnings("unchecked")
    private List<LineInput> parseLines(Object raw) {
        List<LineInput> lines = new ArrayList<>();
        if (!(raw instanceof List<?> list)) return lines;
        for (Object o : list) {
            Map<String, Object> m = (Map<String, Object>) o;
            lines.add(new LineInput(
                    (String) m.get("productName"),
                    (String) m.get("brandType"),
                    (String) m.get("competitorName"),
                    m.get("ourItemId") != null ? UUID.fromString(m.get("ourItemId").toString()) : null,
                    num(m.get("quantity")), num(m.get("value"))));
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
