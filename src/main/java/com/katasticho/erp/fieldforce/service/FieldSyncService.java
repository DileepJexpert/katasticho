package com.katasticho.erp.fieldforce.service;

import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Offline-sync push for the Katasticho Field app: flush a batch of queued
 * actions (check-ins/outs, orders, collections, GPS pings) in one call. Each
 * action is applied independently via {@link FieldSyncActionProcessor} (its own
 * transaction), so one bad action never blocks the rest — the app clears the
 * actions reported APPLIED/DUPLICATE and retries the FAILED ones.
 */
@Service
@RequiredArgsConstructor
public class FieldSyncService {

    private final FieldSyncActionProcessor processor;

    @SuppressWarnings("unchecked")
    public Map<String, Object> push(List<Map<String, Object>> actions) {
        if (actions == null) {
            throw new BusinessException("actions[] is required", "FIELD_SYNC_NO_ACTIONS",
                    HttpStatus.BAD_REQUEST);
        }
        List<Map<String, Object>> results = new ArrayList<>();
        int applied = 0, duplicate = 0, failed = 0;

        for (Map<String, Object> action : actions) {
            String clientId = action.get("clientId") != null ? action.get("clientId").toString() : null;
            String type = (String) action.get("type");
            Map<String, Object> payload = action.get("payload") instanceof Map<?, ?> m
                    ? (Map<String, Object>) m : Map.of();

            if (clientId == null || clientId.isBlank()) {
                results.add(failure(null, type, "Missing clientId"));
                failed++;
                continue;
            }
            try {
                Map<String, Object> r = processor.process(clientId, type, payload);
                results.add(r);
                switch (String.valueOf(r.get("status"))) {
                    case "APPLIED" -> applied++;
                    case "DUPLICATE" -> duplicate++;
                    default -> failed++;
                }
            } catch (BusinessException e) {
                results.add(failure(clientId, type, e.getErrorCode() + ": " + e.getMessage()));
                failed++;
            } catch (Exception e) {
                results.add(failure(clientId, type, e.getMessage()));
                failed++;
            }
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("total", actions.size());
        out.put("applied", applied);
        out.put("duplicate", duplicate);
        out.put("failed", failed);
        out.put("results", results);
        return out;
    }

    private static Map<String, Object> failure(String clientId, String type, String error) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("clientId", clientId);
        m.put("type", type);
        m.put("status", "FAILED");
        m.put("error", error);
        return m;
    }
}
