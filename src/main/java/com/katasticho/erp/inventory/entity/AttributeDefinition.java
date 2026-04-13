package com.katasticho.erp.inventory.entity;

import java.util.List;

/**
 * One attribute key (e.g. "size") plus the closed list of values its
 * variants are allowed to use (e.g. ["S","M","L","XL"]).
 *
 * <p>Stored as a JSONB element inside {@link ItemGroup#getAttributeDefinitions()}.
 * Hibernate 6 + Jackson serialise this record directly when the field
 * is annotated with {@code @JdbcTypeCode(SqlTypes.JSON)}, so there is
 * no manual marshalling.
 *
 * <p>The closed list is the entire point of F5: without it, free-text
 * variant attributes degenerate into a "Color/colour/COLOR" typo zoo.
 * {@code ItemGroupService} validates every variant-create against this
 * list before persisting an item so the picker and reports stay clean.
 */
public record AttributeDefinition(
        String key,
        List<String> values
) {}
