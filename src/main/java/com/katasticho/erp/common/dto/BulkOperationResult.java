package com.katasticho.erp.common.dto;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

public record BulkOperationResult(
        List<UUID> succeeded,
        List<BulkFailure> failed,
        int successCount,
        int failCount
) {
    public record BulkFailure(UUID id, String reason) {}

    public static Accumulator accumulator() {
        return new Accumulator();
    }

    public static class Accumulator {
        private final List<UUID> succeeded = new ArrayList<>();
        private final List<BulkFailure> failed = new ArrayList<>();

        public void success(UUID id) {
            succeeded.add(id);
        }

        public void failure(UUID id, String reason) {
            failed.add(new BulkFailure(id, reason));
        }

        public BulkOperationResult build() {
            return new BulkOperationResult(succeeded, failed, succeeded.size(), failed.size());
        }
    }
}
