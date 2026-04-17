package com.katasticho.erp.accounting.defaults.dto;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;

import java.util.UUID;

/**
 * One row in the Settings → Accounting → Default Accounts screen.
 *
 * - {@code purpose}, {@code label}: enum identity (label is human-readable).
 * - {@code accountId}, {@code accountCode}, {@code accountName}: currently
 *   bound CoA row. Bound row is either the user override or the seeded default.
 * - {@code overridden}: TRUE if the org has explicitly set a row for this
 *   purpose; FALSE if the API resolved it via the enum's default code.
 */
public record DefaultAccountResponse(
        DefaultAccountPurpose purpose,
        String label,
        String defaultCode,
        UUID accountId,
        String accountCode,
        String accountName,
        boolean overridden
) {}
