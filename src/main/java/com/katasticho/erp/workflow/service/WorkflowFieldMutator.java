package com.katasticho.erp.workflow.service;

import java.util.Set;
import java.util.UUID;

/**
 * Per-entity mutator SPI for the FIELD_UPDATE action — the deliberately narrow,
 * safe surface through which a workflow rule may write a document field. Each
 * mutator declares an explicit allowlist of soft columns it will touch and
 * writes ONLY through the plain repository (never a posting / void / lifecycle
 * service), so a rule can never corrupt the ledger. Spring collects all
 * implementations; a FIELD_UPDATE for an entity with no registered mutator, or
 * a field outside the allowlist, is refused.
 */
public interface WorkflowFieldMutator {

    boolean supports(String entityType);

    /** The soft columns this mutator is allowed to set — everything else is refused. */
    Set<String> allowedFields();

    /** Set an allowlisted field on the entity (org-scoped) and persist via the plain repo. */
    void apply(UUID entityId, String field, Object value);
}
