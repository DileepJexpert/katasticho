package com.katasticho.erp.common.cache;

import java.util.UUID;

public final class CacheKeys {

    private CacheKeys() {}

    public static final String ITEM_PRICE = "item-price";
    public static final String STOCK_BALANCE = "stock-balance";
    public static final String POS_ITEMS = "pos-items";
    public static final String CUSTOMER_OUTSTANDING = "cust-outstanding";
    public static final String DAILY_SUMMARY = "daily-summary";
    public static final String AR_SUMMARY = "ar-summary";
    public static final String LOW_STOCK = "low-stock";
    public static final String EXPIRING_SOON = "expiring-soon";
    public static final String WARMER_STATUS = "cache-warmer-status";

    public static String itemPrice(UUID orgId, UUID itemId) {
        return ITEM_PRICE + ":" + orgId + ":" + itemId;
    }

    public static String stockBalance(UUID orgId, UUID itemId, UUID warehouseId) {
        return STOCK_BALANCE + ":" + orgId + ":" + itemId + ":" + warehouseId;
    }

    public static String posItems(UUID orgId) {
        return POS_ITEMS + ":" + orgId;
    }

    public static String customerOutstanding(UUID orgId, UUID contactId) {
        return CUSTOMER_OUTSTANDING + ":" + orgId + ":" + contactId;
    }

    public static String dailySummary(UUID orgId) {
        return DAILY_SUMMARY + ":" + orgId;
    }

    public static String arSummary(UUID orgId) {
        return AR_SUMMARY + ":" + orgId;
    }

    public static String lowStock(UUID orgId) {
        return LOW_STOCK + ":" + orgId;
    }

    public static String expiringSoon(UUID orgId) {
        return EXPIRING_SOON + ":" + orgId;
    }

    public static String warmerStatus(UUID orgId) {
        return WARMER_STATUS + ":" + orgId;
    }

    public static String orgPattern(String prefix, UUID orgId) {
        return prefix + ":" + orgId + ":*";
    }
}
