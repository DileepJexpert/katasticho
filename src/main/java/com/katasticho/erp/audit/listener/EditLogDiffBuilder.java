package com.katasticho.erp.audit.listener;

import java.math.BigDecimal;
import java.time.temporal.Temporal;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

/**
 * Pure functions that turn Hibernate event state arrays into edit-log rows:
 * field-level before/after diffs, soft-delete action resolution, label and
 * org extraction. State-array based (not reflection on the entity) because
 * several books entities declare their own columns instead of extending
 * {@code BaseEntity} — the persister's property arrays are the one shape
 * every entity shares.
 */
final class EditLogDiffBuilder {

    static final int MAX_VALUE_LENGTH = 500;

    /** Sentinel for values the log deliberately does not record (collections, associations). */
    private static final Object SKIP = new Object();

    private EditLogDiffBuilder() {
    }

    /**
     * Field diff for an UPDATE: {field: {"from": old, "to": new}} for every
     * dirty property that is not ignored, not skipped, and actually differs
     * after rendering (a BigDecimal scale-only change is not a change).
     * When Hibernate cannot supply the dirty index set (detached merge),
     * every property is compared.
     */
    static Map<String, Map<String, Object>> updateDiff(String[] propertyNames,
                                                       Object[] oldState,
                                                       Object[] newState,
                                                       int[] dirtyProperties) {
        Map<String, Map<String, Object>> diff = new LinkedHashMap<>();
        int[] indexes = dirtyProperties != null ? dirtyProperties : allIndexes(propertyNames.length);
        for (int i : indexes) {
            if (i < 0 || i >= propertyNames.length) {
                continue;
            }
            String name = propertyNames[i];
            if (EditLogPolicy.IGNORED_PROPERTIES.contains(name)) {
                continue;
            }
            Object from = render(oldState == null ? null : oldState[i]);
            Object to = render(newState == null ? null : newState[i]);
            if (from == SKIP || to == SKIP || Objects.equals(from, to)) {
                continue;
            }
            Map<String, Object> change = new LinkedHashMap<>();
            change.put("from", from);
            change.put("to", to);
            diff.put(name, change);
        }
        return diff;
    }

    /**
     * The codebase soft-deletes (is_deleted flip) instead of issuing SQL
     * DELETEs, so semantically a delete/restore arrives as an UPDATE event.
     * Surface it under its real name in the trail.
     */
    static String resolveUpdateAction(String[] propertyNames, Object[] oldState, Object[] newState) {
        int i = indexOf(propertyNames, "isDeleted");
        if (i < 0 || oldState == null || newState == null) {
            return "UPDATE";
        }
        boolean before = Boolean.TRUE.equals(oldState[i]);
        boolean after = Boolean.TRUE.equals(newState[i]);
        if (!before && after) {
            return "DELETE";
        }
        if (before && !after) {
            return "RESTORE";
        }
        return "UPDATE";
    }

    /** First present, non-blank label property (document number / display name). */
    static String label(String[] propertyNames, Object[] state) {
        if (state == null) {
            return null;
        }
        for (String candidate : EditLogPolicy.LABEL_PROPERTIES) {
            int i = indexOf(propertyNames, candidate);
            if (i >= 0 && state[i] instanceof String s && !s.isBlank()) {
                return truncate(s, 255);
            }
        }
        return null;
    }

    static UUID orgId(String[] propertyNames, Object[] state) {
        int i = indexOf(propertyNames, "orgId");
        return (i >= 0 && state != null && state[i] instanceof UUID u) ? u : null;
    }

    /**
     * JSON-friendly rendering of a single property value. Collections (line
     * items) and unknown object graphs return {@code SKIP} — line-level edits
     * surface indirectly through the header totals they change.
     */
    static Object render(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof String s) {
            return truncate(s, MAX_VALUE_LENGTH);
        }
        if (value instanceof BigDecimal bd) {
            return bd.stripTrailingZeros().toPlainString();
        }
        if (value instanceof Number || value instanceof Boolean) {
            return value;
        }
        if (value instanceof Enum<?> e) {
            return e.name();
        }
        if (value instanceof UUID || value instanceof Temporal || value instanceof java.util.Date) {
            return value.toString();
        }
        if (value instanceof Collection<?> || value instanceof Map<?, ?>) {
            return SKIP;
        }
        return SKIP;
    }

    static boolean isSkip(Object rendered) {
        return rendered == SKIP;
    }

    private static int[] allIndexes(int length) {
        int[] indexes = new int[length];
        for (int i = 0; i < length; i++) {
            indexes[i] = i;
        }
        return indexes;
    }

    private static int indexOf(String[] propertyNames, String name) {
        for (int i = 0; i < propertyNames.length; i++) {
            if (name.equals(propertyNames[i])) {
                return i;
            }
        }
        return -1;
    }

    private static String truncate(String value, int max) {
        return value.length() <= max ? value : value.substring(0, max - 1) + "…";
    }
}
