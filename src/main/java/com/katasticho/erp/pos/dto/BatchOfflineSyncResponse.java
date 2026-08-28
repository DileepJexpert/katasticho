package com.katasticho.erp.pos.dto;

import java.util.List;

public record BatchOfflineSyncResponse(
        int totalReceived,
        int syncedCount,
        int duplicateCount,
        int failedCount,
        List<SalesReceiptResponse> syncedReceipts,
        List<SyncError> errors
) {
    public record SyncError(
            String offlineReceiptNumber,
            String errorMessage
    ) {}
}
