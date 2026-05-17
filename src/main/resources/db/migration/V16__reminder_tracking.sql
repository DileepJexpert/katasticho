-- Credit/Udhar reminder tracking
CREATE TABLE IF NOT EXISTS reminder_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organisation(id),
    contact_id UUID NOT NULL REFERENCES contact(id),
    sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    channel VARCHAR(20) NOT NULL DEFAULT 'WHATSAPP',
    message_preview TEXT,
    sent_by UUID,
    CONSTRAINT fk_reminder_log_org FOREIGN KEY (org_id) REFERENCES organisation(id),
    CONSTRAINT fk_reminder_log_contact FOREIGN KEY (contact_id) REFERENCES contact(id)
);

CREATE INDEX idx_reminder_log_org_contact ON reminder_log(org_id, contact_id);
CREATE INDEX idx_reminder_log_sent_at ON reminder_log(org_id, sent_at DESC);
