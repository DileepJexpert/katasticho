package com.katasticho.erp.franchise.dto;

import lombok.Builder;
import lombok.Data;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Data
@Builder
public class CatalogSyncResultResponse {
    private int nodesTargeted;
    private int itemsSynced;
    private int itemsCreated;
    private int itemsUpdated;
    private List<String> nodeNames;
    private OffsetDateTime syncedAt;
}