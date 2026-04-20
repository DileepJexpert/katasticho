package com.katasticho.erp.common.service;

import java.util.UUID;

public record BootstrapResult(
        UUID orgId,
        StepOutcome uoms,
        StepOutcome accounts,
        StepOutcome defaultAccounts,
        StepOutcome taxConfig,
        boolean allSucceeded,
        String summary) {

    public StepOutcome features() {
        return StepOutcome.success(SeedResult.ALREADY_EXISTS);
    }
}
