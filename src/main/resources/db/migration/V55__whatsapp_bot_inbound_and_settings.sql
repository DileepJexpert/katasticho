-- V55: WhatsApp bot inbound messaging and body storage
ALTER TABLE public.whatsapp_message
    ADD COLUMN IF NOT EXISTS direction VARCHAR(10) DEFAULT 'OUTBOUND',
    ADD COLUMN IF NOT EXISTS body TEXT;

CREATE INDEX IF NOT EXISTS idx_whatsapp_message_direction
    ON public.whatsapp_message (org_id, direction, created_at DESC);
