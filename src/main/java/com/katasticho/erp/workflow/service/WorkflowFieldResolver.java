package com.katasticho.erp.workflow.service;

import com.katasticho.erp.common.event.DomainEvent;
import com.katasticho.erp.common.snapshot.DocumentSnapshotService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Resolves the flat field map a rule's criteria + action placeholders evaluate
 * against. Layers, lowest to highest precedence:
 * <ol>
 *   <li>the domain event's own payload (always present — the fields the
 *       publisher chose to include, e.g. invoiceNumber/status/totalAmount);</li>
 *   <li>the full posted-document snapshot when one exists (the complete Response
 *       DTO for the 10 money documents — gives every field for free).</li>
 * </ol>
 * The snapshot overlays the payload so its richer values win. Missing snapshot
 * (non-posted-doc event, or one not snapshotted) simply falls back to the payload.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class WorkflowFieldResolver {

    private final DocumentSnapshotService documentSnapshotService;

    public Map<String, Object> resolve(DomainEvent event) {
        return resolve(event.getEntityType(), event.getEntityId(), event.getPayload());
    }

    public Map<String, Object> resolve(String entityType, java.util.UUID entityId, Map<String, Object> payload) {
        Map<String, Object> fields = new LinkedHashMap<>();
        if (payload != null) {
            fields.putAll(payload);
        }
        if (entityType != null && entityId != null) {
            try {
                var snap = documentSnapshotService.getSnapshot(entityType, entityId);
                if (snap != null && snap.getSnapshotJson() != null) {
                    fields.putAll(snap.getSnapshotJson());
                }
            } catch (Exception e) {
                // No snapshot for this entity — criteria fall back to the payload.
                log.debug("No snapshot for {} {} — using event payload only", entityType, entityId);
            }
        }
        return fields;
    }
}
