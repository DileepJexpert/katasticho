package com.katasticho.erp.automation;

import org.junit.jupiter.api.Test;
import org.springframework.transaction.annotation.Transactional;

import java.lang.reflect.Method;

import static org.junit.jupiter.api.Assertions.assertFalse;

/**
 * Regression guard for the "notifications silently dropped" bug: the notification
 * sweep jobs must NOT run their scheduled {@code run()} under
 * {@code @Transactional(readOnly = true)}. A readOnly transaction sets
 * {@code FlushMode.MANUAL}, so a {@code Notification} persisted inside it (UUID
 * {@code @GeneratedValue} → in-memory id → INSERT deferred to a flush that never
 * happens on a readOnly commit) is silently never written. This can only surface in
 * a running app (mock-based unit tests never flush), so this structural check stands
 * in for it: read-write {@code @Transactional} (or none) is fine; readOnly is not.
 */
class NotificationJobTransactionTest {

    @Test
    void notificationSweepJobsRunAreNotReadOnly() throws Exception {
        for (Class<?> job : new Class<?>[]{
                DailySalesSummaryJob.class, OverdueBillJob.class, LowStockAlertJob.class}) {
            Method run = job.getDeclaredMethod("run");
            Transactional tx = run.getAnnotation(Transactional.class);
            assertFalse(tx != null && tx.readOnly(),
                    job.getSimpleName() + ".run() must not be @Transactional(readOnly=true) — "
                            + "notificationService.send() persists a Notification whose INSERT "
                            + "would never flush under a readOnly transaction.");
        }
    }
}
