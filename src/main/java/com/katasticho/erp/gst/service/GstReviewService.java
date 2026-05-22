package com.katasticho.erp.gst.service;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.gst.dto.GstReviewIssueResponse;
import com.katasticho.erp.gst.dto.GstReviewSummaryResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class GstReviewService {

    private static final Set<String> GST_SUGGESTION_TYPES = Set.of(
            "GST_AMOUNT_MISMATCH",
            "MISSING_HSN",
            "INVALID_GSTIN",
            "INVALID_GST_RATE",
            "B2B_INVOICE_WITHOUT_GSTIN",
            "DUPLICATE_INVOICE",
            "MISSING_TAX_ACCOUNT_MAPPING",
            "HSN_GST_SUGGESTION"
    );

    private final AiSuggestionRepository aiSuggestionRepository;

    @Transactional(readOnly = true)
    public GstReviewSummaryResponse reviewCenter(String status) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<AiSuggestion> suggestions = (status == null || status.isBlank())
                ? aiSuggestionRepository.findByOrgIdAndSuggestionTypeInOrderByPriorityScoreDescCreatedAtDesc(
                        orgId, GST_SUGGESTION_TYPES)
                : aiSuggestionRepository.findByOrgIdAndSuggestionTypeInAndStatusOrderByPriorityScoreDescCreatedAtDesc(
                        orgId, GST_SUGGESTION_TYPES, status);

        Map<String, Long> byCategory = suggestions.stream()
                .collect(Collectors.groupingBy(
                        AiSuggestion::getSuggestionType,
                        LinkedHashMap::new,
                        Collectors.counting()));

        long pending = suggestions.stream().filter(s -> "PENDING".equals(s.getStatus())).count();
        long critical = suggestions.stream().filter(s -> "CRITICAL".equals(s.getPriority())).count();
        long high = suggestions.stream().filter(s -> "HIGH".equals(s.getPriority())).count();
        long reviewed = suggestions.size() - pending;

        return new GstReviewSummaryResponse(
                suggestions.size(),
                pending,
                critical,
                high,
                reviewed,
                byCategory,
                suggestions.stream().map(GstReviewIssueResponse::from).toList()
        );
    }
}
