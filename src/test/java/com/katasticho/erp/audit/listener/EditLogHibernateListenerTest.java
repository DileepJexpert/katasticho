package com.katasticho.erp.audit.listener;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.common.context.TenantContext;
import org.hibernate.action.spi.BeforeTransactionCompletionProcess;
import org.hibernate.engine.spi.ActionQueue;
import org.hibernate.event.spi.EventSource;
import org.hibernate.event.spi.PostInsertEvent;
import org.hibernate.event.spi.PostUpdateEvent;
import org.hibernate.jdbc.Work;
import org.hibernate.persister.entity.EntityPersister;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class EditLogHibernateListenerTest {

    private static final String INVOICE_ENTITY = "com.katasticho.erp.ar.entity.Invoice";
    private static final String[] NAMES = {"orgId", "invoiceNumber", "status", "isDeleted"};

    @Mock
    private EntityPersister persister;
    @Mock
    private EventSource session;
    @Mock
    private ActionQueue actionQueue;
    @Mock
    private Connection connection;
    @Mock
    private PreparedStatement preparedStatement;

    private EditLogHibernateListener listener;
    private final UUID orgId = UUID.randomUUID();
    private final UUID entityId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() throws Exception {
        listener = new EditLogHibernateListener(new ObjectMapper());
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
        when(persister.getEntityName()).thenReturn(INVOICE_ENTITY);
        when(persister.getPropertyNames()).thenReturn(NAMES);
        when(session.getActionQueue()).thenReturn(actionQueue);
        when(connection.prepareStatement(anyString())).thenReturn(preparedStatement);
        doAnswer(invocation -> {
            invocation.getArgument(0, Work.class).execute(connection);
            return null;
        }).when(session).doWork(any(Work.class));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private BeforeTransactionCompletionProcess capturedBeforeProcess() {
        ArgumentCaptor<BeforeTransactionCompletionProcess> captor =
                ArgumentCaptor.forClass(BeforeTransactionCompletionProcess.class);
        verify(actionQueue).registerProcess(captor.capture());
        return captor.getValue();
    }

    @Test
    void postInsert_onAuditedEntity_writesCreateRowOnSameConnectionAtCommit() throws Exception {
        Object[] state = {orgId, "INV-001", "DRAFT", false};
        listener.onPostInsert(new PostInsertEvent(new Object(), entityId, state, persister, session));

        capturedBeforeProcess().doBeforeTransactionCompletion(session);

        verify(preparedStatement).setObject(2, orgId);
        verify(preparedStatement).setString(3, "INVOICE");
        verify(preparedStatement).setObject(4, entityId);
        verify(preparedStatement).setString(5, "CREATE");
        verify(preparedStatement).setString(6, "INV-001");
        verify(preparedStatement).setObject(8, userId);
        verify(preparedStatement).addBatch();
        verify(preparedStatement).executeBatch();
    }

    @Test
    void postUpdate_capturesFieldDiffJson() throws Exception {
        Object[] oldState = {orgId, "INV-001", "DRAFT", false};
        Object[] newState = {orgId, "INV-001", "POSTED", false};
        listener.onPostUpdate(new PostUpdateEvent(
                new Object(), entityId, newState, oldState, new int[]{2}, persister, session));

        capturedBeforeProcess().doBeforeTransactionCompletion(session);

        verify(preparedStatement).setString(5, "UPDATE");
        verify(preparedStatement).setString(eq(7), contains("\"status\""));
        verify(preparedStatement).setString(eq(7), contains("\"from\":\"DRAFT\""));
        verify(preparedStatement).executeBatch();
    }

    @Test
    void postUpdate_softDeleteFlip_isRecordedAsDelete() throws Exception {
        Object[] oldState = {orgId, "INV-001", "DRAFT", false};
        Object[] newState = {orgId, "INV-001", "DRAFT", true};
        listener.onPostUpdate(new PostUpdateEvent(
                new Object(), entityId, newState, oldState, new int[]{3}, persister, session));

        capturedBeforeProcess().doBeforeTransactionCompletion(session);

        verify(preparedStatement).setString(5, "DELETE");
        verify(preparedStatement).executeBatch();
    }

    @Test
    void postUpdate_withOnlyBookkeepingChanges_writesNothing() {
        String[] names = {"orgId", "invoiceNumber", "updatedAt", "isDeleted"};
        when(persister.getPropertyNames()).thenReturn(names);
        Object[] oldState = {orgId, "INV-001", "t1", false};
        Object[] newState = {orgId, "INV-001", "t2", false};

        listener.onPostUpdate(new PostUpdateEvent(
                new Object(), entityId, newState, oldState, new int[]{2}, persister, session));

        verify(session, never()).getActionQueue();
    }

    @Test
    void nonAllowlistedEntity_isIgnoredEntirely() {
        when(persister.getEntityName())
                .thenReturn("com.katasticho.erp.inventory.entity.StockMovement");
        Object[] state = {orgId, "X", "Y", false};

        listener.onPostInsert(new PostInsertEvent(new Object(), entityId, state, persister, session));

        verify(session, never()).getActionQueue();
    }

    @Test
    void captureFailure_neverPropagatesToTheBusinessWrite() {
        when(persister.getPropertyNames()).thenThrow(new IllegalStateException("boom"));
        Object[] state = {orgId, "INV-001", "DRAFT", false};

        // must not throw
        listener.onPostInsert(new PostInsertEvent(new Object(), entityId, state, persister, session));

        verify(session, never()).getActionQueue();
    }

    @Test
    void rowsWithoutOrgId_areNotAudited() {
        Object[] state = {null, "INV-001", "DRAFT", false};

        listener.onPostInsert(new PostInsertEvent(new Object(), entityId, state, persister, session));

        verify(session, never()).getActionQueue();
    }

    @Test
    void multipleEventsInOneTransaction_batchInOneFlush() throws Exception {
        Object[] state1 = {orgId, "INV-001", "DRAFT", false};
        Object[] state2 = {orgId, "INV-002", "DRAFT", false};
        listener.onPostInsert(new PostInsertEvent(new Object(), entityId, state1, persister, session));
        listener.onPostInsert(new PostInsertEvent(new Object(), UUID.randomUUID(), state2, persister, session));

        capturedBeforeProcess().doBeforeTransactionCompletion(session);

        verify(preparedStatement, org.mockito.Mockito.times(2)).addBatch();
        verify(preparedStatement).executeBatch();
        // the second event reused the already-registered process — one connection write
        verify(session).doWork(any(Work.class));
    }
}
