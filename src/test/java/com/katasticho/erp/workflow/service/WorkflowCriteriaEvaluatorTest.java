package com.katasticho.erp.workflow.service;

import com.katasticho.erp.workflow.entity.WorkflowCriterion;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class WorkflowCriteriaEvaluatorTest {

    private final WorkflowCriteriaEvaluator ev = new WorkflowCriteriaEvaluator();

    private WorkflowCriterion c(String field, String op, Object value) {
        return WorkflowCriterion.builder().field(field).operator(op).value(value).build();
    }

    private final Map<String, Object> fields = Map.of(
            "status", "OVERDUE",
            "totalAmount", new BigDecimal("150000.00"),
            "contactName", "Acme Traders");

    @Test
    void numeric_comparison_coerces_string_operand() {
        // BigDecimal field vs String value → numeric compare, not lexical
        assertThat(ev.matches("ALL", List.of(c("totalAmount", "GT", "100000")), fields)).isTrue();
        assertThat(ev.matches("ALL", List.of(c("totalAmount", "GT", "200000")), fields)).isFalse();
        assertThat(ev.matches("ALL", List.of(c("totalAmount", "GTE", "150000")), fields)).isTrue();
    }

    @Test
    void eq_ne_and_contains() {
        assertThat(ev.matches("ALL", List.of(c("status", "EQ", "OVERDUE")), fields)).isTrue();
        assertThat(ev.matches("ALL", List.of(c("status", "NE", "PAID")), fields)).isTrue();
        assertThat(ev.matches("ALL", List.of(c("contactName", "CONTAINS", "acme")), fields)).isTrue();
        assertThat(ev.matches("ALL", List.of(c("contactName", "CONTAINS", "xyz")), fields)).isFalse();
    }

    @Test
    void in_operator_matches_a_comma_list() {
        assertThat(ev.matches("ALL", List.of(c("status", "IN", "SENT,OVERDUE,PARTIALLY_PAID")), fields)).isTrue();
        assertThat(ev.matches("ALL", List.of(c("status", "IN", "PAID,VOID")), fields)).isFalse();
    }

    @Test
    void is_empty_and_not_empty() {
        Map<String, Object> f = Map.of("notes", "", "status", "OVERDUE");
        assertThat(ev.matches("ALL", List.of(c("notes", "IS_EMPTY", null)), f)).isTrue();
        assertThat(ev.matches("ALL", List.of(c("status", "IS_NOT_EMPTY", null)), f)).isTrue();
        assertThat(ev.matches("ALL", List.of(c("missing", "IS_EMPTY", null)), f)).isTrue();
    }

    @Test
    void all_vs_any_semantics() {
        var overdue = c("status", "EQ", "OVERDUE");
        var big = c("totalAmount", "GT", "200000"); // false
        // ALL: one false → no match
        assertThat(ev.matches("ALL", List.of(overdue, big), fields)).isFalse();
        // ANY: one true → match
        assertThat(ev.matches("ANY", List.of(overdue, big), fields)).isTrue();
    }

    @Test
    void empty_criteria_matches() {
        assertThat(ev.matches("ALL", List.of(), fields)).isTrue();
    }
}
