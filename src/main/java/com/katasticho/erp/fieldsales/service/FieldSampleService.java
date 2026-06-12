package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.fieldsales.entity.FieldSampleTxn;
import com.katasticho.erp.fieldsales.repository.FieldSampleTxnRepository;
import com.katasticho.erp.fieldsales.repository.VisitProductLogRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.*;

/**
 * Sample / promotional material register for field salespeople — works
 * for any vertical (pharma medicine samples, FMCG promo stock / POSM).
 * Issues and returns are explicit transactions; distribution to customers
 * is tallied automatically from the per-visit product logs, so
 * balance = issued − returned − distributed (matched by product name).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FieldSampleService {

    private final FieldSampleTxnRepository sampleTxnRepository;
    private final VisitProductLogRepository visitProductLogRepository;

    @Transactional
    public FieldSampleTxn record(String txnType, UUID salespersonId, UUID itemId,
                                 String productName, int quantity, LocalDate date, String notes) {
        if (productName == null || productName.isBlank()) {
            throw new BusinessException("Product name is required",
                    "FS_SAMPLE_PRODUCT_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        if (quantity <= 0) {
            throw new BusinessException("Quantity must be positive",
                    "FS_SAMPLE_QTY_INVALID", HttpStatus.BAD_REQUEST);
        }
        FieldSampleTxn txn = sampleTxnRepository.save(FieldSampleTxn.builder()
                .orgId(TenantContext.getCurrentOrgId())
                .salespersonId(salespersonId)
                .itemId(itemId)
                .productName(productName.trim())
                .txnType(txnType)
                .quantity(quantity)
                .txnDate(date != null ? date : LocalDate.now())
                .notes(notes)
                .createdBy(TenantContext.getCurrentUserId())
                .build());
        log.info("Sample {} of {} x{} for salesperson {} (org {})",
                txnType, productName, quantity, salespersonId, txn.getOrgId());
        return txn;
    }

    /**
     * Per-product balance for a salesperson:
     * issued − returned (from the register) − distributed (from visit logs).
     */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> balance(UUID salespersonId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        // product (normalized) -> [issued, returned, distributed, display name]
        Map<String, long[]> totals = new LinkedHashMap<>();
        Map<String, String> names = new LinkedHashMap<>();

        for (Object[] row : sampleTxnRepository.sumByProduct(orgId, salespersonId)) {
            String key = normalize((String) row[0]);
            long[] t = totals.computeIfAbsent(key, k -> new long[3]);
            t[0] += ((Number) row[1]).longValue();
            t[1] += ((Number) row[2]).longValue();
            names.putIfAbsent(key, (String) row[0]);
        }
        for (Object[] row : visitProductLogRepository.sumDistributedByProduct(orgId, salespersonId)) {
            String key = normalize((String) row[0]);
            long[] t = totals.computeIfAbsent(key, k -> new long[3]);
            t[2] += ((Number) row[1]).longValue();
            names.putIfAbsent(key, (String) row[0]);
        }

        List<Map<String, Object>> result = new ArrayList<>();
        for (Map.Entry<String, long[]> e : totals.entrySet()) {
            long[] t = e.getValue();
            if (t[0] == 0 && t[1] == 0 && t[2] == 0) continue;
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("productName", names.get(e.getKey()));
            row.put("issued", t[0]);
            row.put("returned", t[1]);
            row.put("distributed", t[2]);
            row.put("balance", t[0] - t[1] - t[2]);
            result.add(row);
        }
        result.sort(Comparator.comparing(r -> r.get("productName").toString().toLowerCase()));
        return result;
    }

    @Transactional(readOnly = true)
    public List<FieldSampleTxn> transactions(UUID salespersonId) {
        return sampleTxnRepository.findByOrgIdAndSalespersonIdOrderByTxnDateDescCreatedAtDesc(
                TenantContext.getCurrentOrgId(), salespersonId);
    }

    private String normalize(String name) {
        return name == null ? "" : name.trim().toLowerCase();
    }
}
