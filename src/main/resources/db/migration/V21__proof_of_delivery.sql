-- ============================================================================
-- V21: Proof of Delivery.
--
-- One POD row per recorded delivery acknowledgement. Links to a delivery
-- challan and/or an invoice — both nullable so a POD can be captured for
-- either flow (DC-only dispatches, or direct invoices). Recipient + GPS
-- + timestamp captured at delivery. Signature + photo attachments reuse
-- the shared AttachmentService via entity_type = 'POD'.
-- ============================================================================

CREATE TABLE public.proof_of_delivery (
    id                    uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id                uuid NOT NULL,
    delivery_challan_id   uuid,
    invoice_id            uuid,
    contact_id            uuid,
    recipient_name        varchar(150) NOT NULL,
    recipient_phone       varchar(30),
    recipient_relation    varchar(50),                -- "Self" / "Receptionist" / "Watchman" etc.
    delivered_at          timestamp with time zone NOT NULL,
    geo_latitude          numeric(10,7),
    geo_longitude         numeric(10,7),
    notes                 text,
    recorded_by           uuid,
    is_deleted            boolean DEFAULT false NOT NULL,
    created_at            timestamp with time zone DEFAULT now() NOT NULL,
    updated_at            timestamp with time zone DEFAULT now() NOT NULL,
    created_by            uuid,
    CONSTRAINT proof_of_delivery_pkey PRIMARY KEY (id),
    CONSTRAINT proof_of_delivery_link_check
        CHECK (delivery_challan_id IS NOT NULL OR invoice_id IS NOT NULL)
);
CREATE INDEX idx_pod_org_dc       ON public.proof_of_delivery (org_id, delivery_challan_id)
    WHERE delivery_challan_id IS NOT NULL;
CREATE INDEX idx_pod_org_invoice  ON public.proof_of_delivery (org_id, invoice_id)
    WHERE invoice_id IS NOT NULL;
CREATE INDEX idx_pod_org_contact  ON public.proof_of_delivery (org_id, contact_id)
    WHERE contact_id IS NOT NULL;
CREATE INDEX idx_pod_org_date     ON public.proof_of_delivery (org_id, delivered_at);
