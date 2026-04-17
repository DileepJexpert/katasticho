package com.katasticho.erp.common.service;

public record StepOutcome(SeedResult result, String error) {

    public boolean succeeded() {
        return error == null;
    }

    public static StepOutcome success(SeedResult result) {
        return new StepOutcome(result, null);
    }

    public static StepOutcome failure(String error) {
        return new StepOutcome(null, error);
    }
}
