CREATE TABLE org_bootstrap_status (
    org_id          UUID PRIMARY KEY REFERENCES organisation(id),
    uoms_seeded_at              TIMESTAMPTZ,
    accounts_seeded_at          TIMESTAMPTZ,
    default_accounts_seeded_at  TIMESTAMPTZ,
    tax_config_seeded_at        TIMESTAMPTZ,
    last_bootstrap_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_bootstrap_status       VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    last_error_message          TEXT
);
