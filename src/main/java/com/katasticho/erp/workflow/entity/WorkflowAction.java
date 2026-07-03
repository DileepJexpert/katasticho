package com.katasticho.erp.workflow.entity;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Map;

/**
 * One action inside a {@link WorkflowRule}'s JSONB actions list.
 *
 * <p>{@code type} ∈ EMAIL | WEBHOOK | AI_SUGGESTION | FIELD_UPDATE. {@code config}
 * carries the per-type parameters:
 * <ul>
 *   <li>EMAIL: {@code to} (address or a {{field}} ref), {@code subject}, {@code body}
 *       (both support {{field}} placeholders).</li>
 *   <li>WEBHOOK: {@code url} (https), {@code secret} (optional HMAC key).</li>
 *   <li>AI_SUGGESTION: {@code message}, {@code priority}.</li>
 *   <li>FIELD_UPDATE: {@code field}, {@code value} — only whitelisted soft fields,
 *       executed by a registered per-entity mutator (never a posting path).</li>
 * </ul>
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class WorkflowAction {
    private String type;
    private Map<String, Object> config;
}
