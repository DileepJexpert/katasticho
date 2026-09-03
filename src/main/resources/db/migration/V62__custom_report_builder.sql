-- V62: Custom Report Builder + Scheduled Email Dispatch
-- saved_report: user-defined report templates (base report + column selection + filters + tags)
-- report_schedule: email dispatch schedule per saved report

CREATE TABLE saved_report (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID         NOT NULL,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    base_report_key VARCHAR(100) NOT NULL,
    column_keys     TEXT         NOT NULL,
    filters         TEXT,
    tags            VARCHAR(500),
    is_public       BOOLEAN      NOT NULL DEFAULT FALSE,
    created_by      UUID         NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    is_deleted      BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_saved_report_org  ON saved_report(org_id) WHERE NOT is_deleted;
CREATE INDEX idx_saved_report_user ON saved_report(created_by) WHERE NOT is_deleted;

CREATE TABLE report_schedule (
    id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id           UUID         NOT NULL,
    saved_report_id  UUID         NOT NULL REFERENCES saved_report(id),
    frequency        VARCHAR(20)  NOT NULL CHECK (frequency IN ('DAILY','WEEKLY','MONTHLY')),
    day_of_week      SMALLINT,
    day_of_month     SMALLINT,
    send_time        VARCHAR(5)   NOT NULL DEFAULT '08:00',
    recipient_emails TEXT         NOT NULL,
    subject_template VARCHAR(500),
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE,
    last_sent_at     TIMESTAMPTZ,
    next_run_at      TIMESTAMPTZ,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_report_schedule_report ON report_schedule(saved_report_id);
CREATE INDEX idx_report_schedule_next   ON report_schedule(next_run_at) WHERE is_active;
