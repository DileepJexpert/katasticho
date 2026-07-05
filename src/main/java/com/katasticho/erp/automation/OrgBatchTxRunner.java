package com.katasticho.erp.automation;

import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Runs one org's slice of a nightly sweep in its OWN transaction. Notification /
 * batch-expiry jobs used to run every org in a single method-level transaction, so
 * one org's failure rolled back every other org's committed work AND aborted the
 * rest of the sweep. The job's run() stays non-transactional and calls
 * {@code runInTx(() -> processOrg(org))} inside a per-org try/catch — because this
 * is a separate bean, Spring's proxy opens a fresh transaction around each body,
 * giving true per-org isolation (mirrors the DepreciationJob pattern).
 */
@Component
public class OrgBatchTxRunner {

    @Transactional
    public void runInTx(Runnable body) {
        body.run();
    }
}
