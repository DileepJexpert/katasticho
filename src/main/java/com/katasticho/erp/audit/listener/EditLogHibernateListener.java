package com.katasticho.erp.audit.listener;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.common.context.TenantContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.hibernate.action.spi.AfterTransactionCompletionProcess;
import org.hibernate.action.spi.BeforeTransactionCompletionProcess;
import org.hibernate.engine.spi.SessionImplementor;
import org.hibernate.engine.spi.SharedSessionContractImplementor;
import org.hibernate.event.spi.EventSource;
import org.hibernate.event.spi.PostDeleteEvent;
import org.hibernate.event.spi.PostDeleteEventListener;
import org.hibernate.event.spi.PostInsertEvent;
import org.hibernate.event.spi.PostInsertEventListener;
import org.hibernate.event.spi.PostUpdateEvent;
import org.hibernate.event.spi.PostUpdateEventListener;
import org.hibernate.persister.entity.EntityPersister;
import org.springframework.stereotype.Component;

import java.sql.PreparedStatement;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * The edit-log writer: listens to Hibernate post-insert/update/delete events
 * for allowlisted books entities ({@link EditLogPolicy}) and appends audit
 * rows to {@code edit_log}.
 *
 * <p><b>Transactional guarantee:</b> events are collected per session during
 * flush and written in a {@link BeforeTransactionCompletionProcess} over the
 * session's own JDBC connection ({@code session.doWork}) — inside the business
 * transaction. A rollback discards the log rows with the business data; a
 * commit is guaranteed to carry them. No separate transaction, no JPA
 * recursion (raw JDBC insert).
 *
 * <p><b>Failure policy:</b> capture errors never break the business write —
 * they are logged and swallowed. The one exception is a failure of the final
 * JDBC batch itself, which may poison the connection and roll the transaction
 * back; that is acceptable (rare, and fail-open would mean unaudited books).
 */
@Component
@Slf4j
@RequiredArgsConstructor
public class EditLogHibernateListener
        implements PostInsertEventListener, PostUpdateEventListener, PostDeleteEventListener {

    private static final String INSERT_SQL =
            "INSERT INTO edit_log (id, org_id, entity_type, entity_id, action, "
                    + "entity_label, field_changes, changed_by, changed_at) "
                    + "VALUES (?, ?, ?, ?, ?, ?, ?::jsonb, ?, ?)";

    private final ObjectMapper objectMapper;

    /** Rows collected during flush, keyed by the owning session (identity semantics). */
    private final Map<SharedSessionContractImplementor, List<PendingEdit>> pendingBySession =
            new ConcurrentHashMap<>();

    record PendingEdit(UUID orgId, String entityType, UUID entityId, String action,
                       String entityLabel, String fieldChanges, UUID changedBy, Instant changedAt) {
    }

    @Override
    public void onPostInsert(PostInsertEvent event) {
        try {
            String type = EditLogPolicy.AUDITED_ENTITIES.get(event.getPersister().getEntityName());
            if (type == null) {
                return;
            }
            String[] names = event.getPersister().getPropertyNames();
            queue(event.getSession(),
                    buildRow(type, event.getId(), "CREATE", names, event.getState(), null));
        } catch (Exception e) {
            log.warn("edit-log: insert capture failed: {}", e.getMessage());
        }
    }

    @Override
    public void onPostUpdate(PostUpdateEvent event) {
        try {
            String type = EditLogPolicy.AUDITED_ENTITIES.get(event.getPersister().getEntityName());
            if (type == null) {
                return;
            }
            String[] names = event.getPersister().getPropertyNames();
            Map<String, Map<String, Object>> diff = EditLogDiffBuilder.updateDiff(
                    names, event.getOldState(), event.getState(), event.getDirtyProperties());
            String action = EditLogDiffBuilder.resolveUpdateAction(
                    names, event.getOldState(), event.getState());
            if (diff.isEmpty() && "UPDATE".equals(action)) {
                return; // only bookkeeping columns moved — no audit signal
            }
            queue(event.getSession(),
                    buildRow(type, event.getId(), action, names, event.getState(), diff));
        } catch (Exception e) {
            log.warn("edit-log: update capture failed: {}", e.getMessage());
        }
    }

    @Override
    public void onPostDelete(PostDeleteEvent event) {
        // Hard deletes are rare here (the codebase soft-deletes), but a few
        // flows delete drafts outright — those must not vanish silently.
        try {
            String type = EditLogPolicy.AUDITED_ENTITIES.get(event.getPersister().getEntityName());
            if (type == null) {
                return;
            }
            String[] names = event.getPersister().getPropertyNames();
            queue(event.getSession(),
                    buildRow(type, event.getId(), "DELETE", names, event.getDeletedState(), null));
        } catch (Exception e) {
            log.warn("edit-log: delete capture failed: {}", e.getMessage());
        }
    }

    @Override
    public boolean requiresPostCommitHandling(EntityPersister persister) {
        return false;
    }

    private PendingEdit buildRow(String entityType, Object id, String action,
                                 String[] propertyNames, Object[] state,
                                 Map<String, Map<String, Object>> diff) {
        String fieldChanges = null;
        if (diff != null && !diff.isEmpty()) {
            try {
                fieldChanges = objectMapper.writeValueAsString(diff);
            } catch (Exception e) {
                log.warn("edit-log: diff serialization failed: {}", e.getMessage());
            }
        }
        return new PendingEdit(
                EditLogDiffBuilder.orgId(propertyNames, state),
                entityType,
                id instanceof UUID u ? u : null,
                action,
                EditLogDiffBuilder.label(propertyNames, state),
                fieldChanges,
                TenantContext.getCurrentUserId(),
                Instant.now());
    }

    private void queue(EventSource session, PendingEdit edit) {
        if (edit.orgId() == null || edit.entityId() == null) {
            return; // platform-level or unidentifiable row — nothing to scope it to
        }
        pendingBySession.computeIfAbsent(session, s -> {
            registerProcesses(session);
            return Collections.synchronizedList(new ArrayList<>());
        }).add(edit);
    }

    private void registerProcesses(EventSource session) {
        session.getActionQueue().registerProcess(
                (BeforeTransactionCompletionProcess) this::flushPending);
        // Runs on commit AND rollback — the map entry never leaks.
        session.getActionQueue().registerProcess(
                (AfterTransactionCompletionProcess) (success, s) -> pendingBySession.remove(s));
    }

    private void flushPending(SessionImplementor session) {
        List<PendingEdit> pending = pendingBySession.get(session);
        if (pending == null || pending.isEmpty()) {
            return;
        }
        List<PendingEdit> snapshot;
        synchronized (pending) {
            snapshot = new ArrayList<>(pending);
            pending.clear();
        }
        session.doWork(connection -> {
            try (PreparedStatement ps = connection.prepareStatement(INSERT_SQL)) {
                for (PendingEdit edit : snapshot) {
                    ps.setObject(1, UUID.randomUUID());
                    ps.setObject(2, edit.orgId());
                    ps.setString(3, edit.entityType());
                    ps.setObject(4, edit.entityId());
                    ps.setString(5, edit.action());
                    ps.setString(6, edit.entityLabel());
                    ps.setString(7, edit.fieldChanges());
                    ps.setObject(8, edit.changedBy());
                    ps.setTimestamp(9, Timestamp.from(edit.changedAt()));
                    ps.addBatch();
                }
                ps.executeBatch();
            }
        });
    }
}
