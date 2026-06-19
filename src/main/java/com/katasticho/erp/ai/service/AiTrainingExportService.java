package com.katasticho.erp.ai.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.entity.AiTrainingExample;
import com.katasticho.erp.ai.repository.AiTrainingExampleRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

/**
 * Exports the human-reviewed AI Inbox decisions ({@code ai_training_example})
 * as a fine-tuning dataset, so a self-hosted open model can be trained on the
 * org's own accounting behaviour.
 *
 * <p>Every Inbox accept/modify/reject is already captured (input snapshot, the
 * model's output, and the human's corrected output). This turns those rows into
 * <b>chat-format JSONL</b> — one example per line — that any LoRA/SFT toolchain
 * (Unsloth, Axolotl, HF TRL) ingests directly. By default it exports the
 * <b>good</b> labels (ACCEPTED + MODIFIED), where the human output is the
 * ground truth to imitate.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AiTrainingExportService {

    private static final int PAGE = 500;
    private static final Set<String> GOOD_LABELS = Set.of("ACCEPTED", "ACCEPT", "MODIFIED", "MODIFY");

    private final AiTrainingExampleRepository repository;
    private final ObjectMapper objectMapper;

    /** Per-task system prompts so the fine-tune learns the right role per task. */
    private static final Map<String, String> TASK_SYSTEM = Map.of(
            "DRAFT_BILL", "You are an Indian SMB accountant. Draft the purchase bill from the scanned input.",
            "DRAFT_ENTRY", "You are an Indian SMB accountant. Draft the journal entry for the described transaction.",
            "FLUX_ANALYSIS", "You are a senior controller doing month-end flux review. Explain the material P&L movements.",
            "COLLECTIONS_REMINDER", "You are a credit controller. Draft a polite, firm payment reminder.",
            "GSTR2B_ENTRY", "You are a GST practitioner. Reconcile the bill against the GSTR-2B line.");

    /**
     * Build the dataset as JSONL. {@code taskType} null = all tasks.
     * {@code goodOnly} true = only ACCEPTED/MODIFIED (recommended for SFT);
     * false = include REJECTED too (for preference/DPO datasets).
     */
    @Transactional(readOnly = true)
    public String exportJsonl(String taskType, boolean goodOnly) {
        UUID orgId = requireOrgId();
        StringBuilder sb = new StringBuilder();
        int page = 0;
        Page<AiTrainingExample> p;
        do {
            PageRequest pr = PageRequest.of(page, PAGE);
            p = (taskType == null || taskType.isBlank())
                    ? repository.findByOrgIdOrderByCreatedAtAsc(orgId, pr)
                    : repository.findByOrgIdAndTaskTypeOrderByCreatedAtAsc(orgId, taskType.trim(), pr);
            for (AiTrainingExample ex : p.getContent()) {
                if (goodOnly && !isGood(ex)) continue;
                String line = toChatJsonl(ex);
                if (line != null) sb.append(line).append('\n');
            }
            page++;
        } while (p.hasNext());
        return sb.toString();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> summary() {
        UUID orgId = requireOrgId();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("totalExamples", repository.countByOrgId(orgId));
        m.put("note", "Export via /api/v1/ai/training/export?taskType=&goodOnly=true (chat JSONL).");
        return m;
    }

    private boolean isGood(AiTrainingExample ex) {
        String c = ex.getCorrectionType();
        return c != null && GOOD_LABELS.contains(c.toUpperCase());
    }

    /** One SFT example: system + user(input) + assistant(human-approved output). */
    private String toChatJsonl(AiTrainingExample ex) {
        try {
            String system = TASK_SYSTEM.getOrDefault(ex.getTaskType(),
                    "You are an Indian SMB ERP accounting assistant.");
            String user = objectMapper.writeValueAsString(
                    Objects.requireNonNullElse(ex.getInputSnapshot(), Map.of()));
            // The HUMAN output is the label to imitate (their correction/approval).
            String assistant = objectMapper.writeValueAsString(
                    Objects.requireNonNullElse(ex.getHumanOutput(), Map.of()));

            Map<String, Object> row = Map.of("messages", List.of(
                    Map.of("role", "system", "content", system),
                    Map.of("role", "user", "content", user),
                    Map.of("role", "assistant", "content", assistant)));
            return objectMapper.writeValueAsString(row);
        } catch (JsonProcessingException e) {
            log.warn("Skipping un-serializable training example {}: {}", ex.getId(), e.getMessage());
            return null;
        }
    }

    private static UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
