package com.katasticho.erp.audit.listener;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class EditLogDiffBuilderTest {

    private static final String[] NAMES =
            {"orgId", "invoiceNumber", "status", "totalAmount", "updatedAt", "isDeleted"};

    @Test
    void updateDiff_capturesChangedFieldsWithFromAndTo() {
        Object[] oldState = {UUID.randomUUID(), "INV-9", "DRAFT", new BigDecimal("100.00"), null, false};
        Object[] newState = {oldState[0], "INV-9", "POSTED", new BigDecimal("118.00"), null, false};

        Map<String, Map<String, Object>> diff =
                EditLogDiffBuilder.updateDiff(NAMES, oldState, newState, new int[]{2, 3});

        assertThat(diff).containsOnlyKeys("status", "totalAmount");
        assertThat(diff.get("status")).containsEntry("from", "DRAFT").containsEntry("to", "POSTED");
        assertThat(diff.get("totalAmount")).containsEntry("from", "100").containsEntry("to", "118");
    }

    @Test
    void updateDiff_skipsBookkeepingColumnsAndScaleOnlyDecimalChanges() {
        Object[] oldState = {null, null, "DRAFT", new BigDecimal("100.0"), "old-ts", false};
        Object[] newState = {null, null, "DRAFT", new BigDecimal("100.00"), "new-ts", false};

        // updatedAt is dirty (always is) and the amount only changed scale
        Map<String, Map<String, Object>> diff =
                EditLogDiffBuilder.updateDiff(NAMES, oldState, newState, new int[]{3, 4});

        assertThat(diff).isEmpty();
    }

    @Test
    void updateDiff_withoutDirtyIndexes_comparesEveryProperty() {
        Object[] oldState = {null, "INV-9", "DRAFT", BigDecimal.TEN, null, false};
        Object[] newState = {null, "INV-9", "SENT", BigDecimal.TEN, null, false};

        Map<String, Map<String, Object>> diff =
                EditLogDiffBuilder.updateDiff(NAMES, oldState, newState, null);

        assertThat(diff).containsOnlyKeys("status");
    }

    @Test
    void updateDiff_skipsCollectionsAndTruncatesLongStrings() {
        String[] names = {"lines", "notes"};
        String longNote = "x".repeat(600);
        Object[] oldState = {List.of("line"), "short"};
        Object[] newState = {List.of("line", "line2"), longNote};

        Map<String, Map<String, Object>> diff =
                EditLogDiffBuilder.updateDiff(names, oldState, newState, new int[]{0, 1});

        assertThat(diff).containsOnlyKeys("notes");
        String truncated = (String) diff.get("notes").get("to");
        assertThat(truncated).hasSize(EditLogDiffBuilder.MAX_VALUE_LENGTH).endsWith("…");
    }

    @Test
    void resolveUpdateAction_mapsSoftDeleteFlipsToDeleteAndRestore() {
        Object[] live = {null, null, null, null, null, false};
        Object[] deleted = {null, null, null, null, null, true};

        assertThat(EditLogDiffBuilder.resolveUpdateAction(NAMES, live, deleted)).isEqualTo("DELETE");
        assertThat(EditLogDiffBuilder.resolveUpdateAction(NAMES, deleted, live)).isEqualTo("RESTORE");
        assertThat(EditLogDiffBuilder.resolveUpdateAction(NAMES, live, live)).isEqualTo("UPDATE");
        assertThat(EditLogDiffBuilder.resolveUpdateAction(
                new String[]{"status"}, new Object[]{"A"}, new Object[]{"B"})).isEqualTo("UPDATE");
    }

    @Test
    void label_prefersDocumentNumberOverGenericName_andOrgIdIsExtracted() {
        String[] names = {"orgId", "name", "invoiceNumber"};
        UUID orgId = UUID.randomUUID();
        Object[] state = {orgId, "Some display name", "INV-42"};

        assertThat(EditLogDiffBuilder.label(names, state)).isEqualTo("INV-42");
        assertThat(EditLogDiffBuilder.orgId(names, state)).isEqualTo(orgId);
        assertThat(EditLogDiffBuilder.label(new String[]{"name"}, new Object[]{"Acme"})).isEqualTo("Acme");
        assertThat(EditLogDiffBuilder.orgId(new String[]{"name"}, new Object[]{"Acme"})).isNull();
    }
}
