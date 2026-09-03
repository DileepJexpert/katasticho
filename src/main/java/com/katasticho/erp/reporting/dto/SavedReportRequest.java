package com.katasticho.erp.reporting.dto;

import lombok.Data;

import java.util.List;

@Data
public class SavedReportRequest {

    /** Display name of the saved report */
    private String name;

    /** Optional human-readable description */
    private String description;

    /** Key identifying the base report type (e.g. "sales_register") */
    private String baseReportKey;

    /** Ordered list of column keys to include in the report */
    private List<String> columnKeys;

    /**
     * Free-form filter criteria. Serialized to JSON text before persistence.
     * E.g. {"dateRange":"THIS_MONTH","customerId":"uuid-..."}
     */
    private Object filters;

    /** Optional classification tags */
    private List<String> tags;

    /** Whether this report is visible to all org members */
    private boolean isPublic;
}
