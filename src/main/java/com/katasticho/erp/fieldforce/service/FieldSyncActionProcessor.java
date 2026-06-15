package com.katasticho.erp.fieldforce.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.fieldforce.entity.FieldSyncEntry;
import com.katasticho.erp.fieldforce.repository.FieldSyncEntryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Applies ONE offline-synced field action in its own transaction
 * ({@code REQUIRES_NEW}) so a failure rolls back only that action — the batch
 * loop in {@link FieldSyncService} continues. Successful actions are recorded in
 * the idempotency ledger (same transaction), so a replay of the same client_id
 * returns DUPLICATE instead of re-applying; failures leave no ledger row and
 * stay retryable.
 */
@Service
@RequiredArgsConstructor
public class FieldSyncActionProcessor {

    private final FieldFacadeService facade;
    private final FieldSyncEntryRepository syncRepository;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public Map<String, Object> process(String clientId, String type, Map<String, Object> payload) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID salesperson = TenantContext.getCurrentUserId();

        Optional<FieldSyncEntry> prior =
                syncRepository.findByOrgIdAndSalespersonIdAndClientId(orgId, salesperson, clientId);
        if (prior.isPresent()) {
            return result(clientId, type, "DUPLICATE", "Already processed: " + prior.get().getStatus(), null);
        }

        Object res = dispatch(type, payload);

        syncRepository.save(FieldSyncEntry.builder()
                .orgId(orgId).salespersonId(salesperson)
                .clientId(clientId).actionType(type).status("APPLIED")
                .resultSummary(String.valueOf(res))
                .build());
        return result(clientId, type, "APPLIED", null, res);
    }

    private Object dispatch(String type, Map<String, Object> p) {
        String t = type == null ? "" : type.trim().toUpperCase();
        return switch (t) {
            case "CHECK_IN" -> facade.checkIn(
                    FieldPayloadParser.uuid(p.get("visitId")),
                    FieldPayloadParser.num(p.get("latitude")),
                    FieldPayloadParser.num(p.get("longitude")));
            case "CHECK_OUT" -> facade.checkOut(
                    FieldPayloadParser.uuid(p.get("visitId")),
                    FieldPayloadParser.num(p.get("latitude")),
                    FieldPayloadParser.num(p.get("longitude")),
                    (String) p.get("notes"));
            case "ORDER" -> facade.createOrder(
                    FieldPayloadParser.uuid(p.get("dealerId")),
                    FieldPayloadParser.parseLines(p.get("lines")),
                    (String) p.get("notes"),
                    FieldPayloadParser.uuid(p.get("visitId")));
            case "COLLECTION" -> facade.recordCollection(
                    FieldPayloadParser.uuid(p.get("dealerId")),
                    FieldPayloadParser.num(p.get("amount")),
                    (String) p.get("paymentMethod"),
                    FieldPayloadParser.uuid(p.get("visitId")));
            case "LOCATION_PINGS" -> Map.of("saved",
                    facade.recordPings(FieldPayloadParser.parsePings(p.get("pings"))));
            default -> throw new BusinessException("Unknown action type: " + type,
                    "FIELD_SYNC_UNKNOWN_TYPE", HttpStatus.BAD_REQUEST);
        };
    }

    private static Map<String, Object> result(String clientId, String type, String status,
                                              String note, Object data) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("clientId", clientId);
        m.put("type", type);
        m.put("status", status);
        if (note != null) m.put("note", note);
        if (data != null) m.put("result", data);
        return m;
    }
}
