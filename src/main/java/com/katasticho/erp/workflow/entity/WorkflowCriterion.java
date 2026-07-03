package com.katasticho.erp.workflow.entity;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * One condition inside a {@link WorkflowRule}'s JSONB criteria list. Evaluated
 * against the resolved document field map.
 *
 * <p>{@code field} is a resolved field key (DTO camelCase, e.g. totalAmount,
 * status, contactId). {@code operator} is one of EQ, NE, GT, GTE, LT, LTE,
 * CONTAINS, IN, IS_EMPTY, IS_NOT_EMPTY. {@code value} is the comparison operand
 * (ignored for the IS_EMPTY/IS_NOT_EMPTY operators).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class WorkflowCriterion {
    private String field;
    private String operator;
    private Object value;
}
