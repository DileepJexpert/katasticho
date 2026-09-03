package com.katasticho.erp.franchise.dto;

import lombok.Data;
import java.util.List;
import java.util.UUID;

@Data
public class CatalogSyncPushRequest {
    private List<UUID> targetNodeIds; // null or empty for all active nodes
    private List<UUID> itemIds; // null or empty for all active items
    private String syncScope; // ALL, NEW_ONLY, PRICE_UPDATES_ONLY
}