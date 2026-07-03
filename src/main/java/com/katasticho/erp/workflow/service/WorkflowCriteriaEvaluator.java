package com.katasticho.erp.workflow.service;

import com.katasticho.erp.workflow.entity.WorkflowCriterion;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.Collection;
import java.util.List;
import java.util.Map;

/**
 * Evaluates a rule's criteria against a resolved field map. Pure — no
 * dependencies — so it is unit-testable in isolation.
 *
 * <p>Operators: EQ, NE, GT, GTE, LT, LTE, CONTAINS, IN, IS_EMPTY, IS_NOT_EMPTY.
 * Comparisons coerce numerically when BOTH operands look numeric (so
 * {@code totalAmount > "1000"} works whether the snapshot value is a BigDecimal
 * or a String); otherwise they fall back to case-insensitive string comparison.
 */
@Component
public class WorkflowCriteriaEvaluator {

    /** ALL = every criterion must hold; ANY = at least one. Empty criteria = match. */
    public boolean matches(String matchType, List<WorkflowCriterion> criteria, Map<String, Object> fields) {
        if (criteria == null || criteria.isEmpty()) {
            return true;
        }
        boolean any = "ANY".equalsIgnoreCase(matchType);
        for (WorkflowCriterion c : criteria) {
            boolean ok = evaluate(c, fields);
            if (any && ok) return true;
            if (!any && !ok) return false;
        }
        return !any; // ALL: reached end with no failure → true; ANY: none matched → false
    }

    boolean evaluate(WorkflowCriterion c, Map<String, Object> fields) {
        String op = c.getOperator() == null ? "EQ" : c.getOperator().trim().toUpperCase();
        Object actual = fields.get(c.getField());
        Object expected = c.getValue();

        return switch (op) {
            case "IS_EMPTY" -> isEmpty(actual);
            case "IS_NOT_EMPTY" -> !isEmpty(actual);
            case "EQ" -> compare(actual, expected) == 0;
            case "NE" -> compare(actual, expected) != 0;
            case "GT" -> compare(actual, expected) > 0;
            case "GTE" -> compare(actual, expected) >= 0;
            case "LT" -> compare(actual, expected) < 0;
            case "LTE" -> compare(actual, expected) <= 0;
            case "CONTAINS" -> actual != null && expected != null
                    && str(actual).toLowerCase().contains(str(expected).toLowerCase());
            case "IN" -> in(actual, expected);
            default -> false;
        };
    }

    /**
     * Three-way compare with numeric coercion. Returns {@link Integer#MIN_VALUE}
     * when a magnitude comparison is impossible (a null against a value) so that
     * only NE evaluates true — GT/LT/etc. on a null are false, EQ is false.
     */
    private int compare(Object actual, Object expected) {
        if (actual == null && expected == null) return 0;
        if (actual == null || expected == null) return Integer.MIN_VALUE;
        BigDecimal a = num(actual), b = num(expected);
        if (a != null && b != null) {
            return a.compareTo(b);
        }
        // Boolean equality
        if (actual instanceof Boolean || expected instanceof Boolean) {
            return str(actual).equalsIgnoreCase(str(expected)) ? 0 : 1;
        }
        return str(actual).compareToIgnoreCase(str(expected));
    }

    @SuppressWarnings("unchecked")
    private boolean in(Object actual, Object expected) {
        if (actual == null || expected == null) return false;
        Collection<Object> list;
        if (expected instanceof Collection<?> col) {
            list = (Collection<Object>) col;
        } else {
            // comma-separated string form
            list = List.of((Object[]) str(expected).split("\\s*,\\s*"));
        }
        for (Object o : list) {
            if (compare(actual, o) == 0) return true;
        }
        return false;
    }

    private static boolean isEmpty(Object v) {
        return v == null || (v instanceof String s && s.isBlank())
                || (v instanceof Collection<?> c && c.isEmpty());
    }

    private static BigDecimal num(Object o) {
        if (o instanceof BigDecimal b) return b;
        if (o instanceof Number n) return BigDecimal.valueOf(n.doubleValue());
        try {
            return new BigDecimal(o.toString().trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static String str(Object o) {
        return o == null ? "" : o.toString();
    }
}
