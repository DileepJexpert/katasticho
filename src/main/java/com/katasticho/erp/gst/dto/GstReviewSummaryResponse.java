package com.katasticho.erp.gst.dto;

import java.util.List;
import java.util.Map;

public record GstReviewSummaryResponse(
        long totalIssues,
        long pendingIssues,
        long criticalIssues,
        long highIssues,
        long reviewedIssues,
        Map<String, Long> byCategory,
        List<GstReviewIssueResponse> issues
) {
}
