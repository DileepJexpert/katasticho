-- ============================================================================
-- V25: Courier / shipping integration — COD + RTO + multi-courier.
--
-- The Transport pillar's missing piece: track parcels sent via 3rd-party
-- couriers (BlueDart, Delhivery, India Post, DTDC) or an aggregator (Shiprocket),
-- reconcile cash-on-delivery remittances against the invoices the courier
-- collected for, and re-adjust stock + books when a parcel is returned (RTO).
--
-- Tables:
--   courier_shipment        — one row per parcel sent; owns the AWB + lifecycle
--   courier_shipment_event  — append-only status feed from courier webhooks/polls
--   cod_remittance          — one row per remittance file/payout from the courier
--   cod_remittance_line     — per-AWB lines in a remittance, matched to invoices
-- ============================================================================

CREATE TABLE public.courier_shipment (
    id                          uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id                      uuid NOT NULL,
    courier_shipment_number     character varying(30) NOT NULL,   -- CRS-00001
    -- Provenance: where did this parcel come from?
    delivery_challan_id         uuid,
    invoice_id                  uuid,
    contact_id                  uuid NOT NULL,                    -- customer
    -- Courier
    courier_partner             character varying(40) NOT NULL,   -- BLUEDART | DELHIVERY | INDIA_POST | DTDC | SHIPROCKET | OTHER
    courier_service             character varying(60),            -- "Surface", "Express", etc.
    awb_number                  character varying(60),            -- the tracking id; blank until booked
    -- Lifecycle (see CourierShipmentService)
    status                      character varying(30) NOT NULL DEFAULT 'DRAFT',
    -- DRAFT | BOOKED | PICKED_UP | IN_TRANSIT | OUT_FOR_DELIVERY | DELIVERED
    --   | RTO_INITIATED | RTO_DELIVERED | CANCELLED
    -- COD
    is_cod                      boolean NOT NULL DEFAULT false,
    cod_amount                  numeric(14, 2) NOT NULL DEFAULT 0,
    cod_remittance_line_id      uuid,                              -- set when settled
    -- Freight (what we owe the courier)
    freight_amount              numeric(14, 2) NOT NULL DEFAULT 0,
    cod_fee                     numeric(14, 2) NOT NULL DEFAULT 0,
    transporter_contact_id      uuid,                              -- courier-as-vendor (for AP)
    -- Parcel
    weight_kg                   numeric(10, 3),
    declared_value              numeric(14, 2),
    pickup_address              jsonb,
    delivery_address            jsonb,
    -- Timestamps
    booked_at                   timestamp with time zone,
    delivered_at                timestamp with time zone,
    rto_initiated_at            timestamp with time zone,
    rto_delivered_at            timestamp with time zone,
    notes                       text,
    -- BaseEntity bits
    is_deleted                  boolean NOT NULL DEFAULT false,
    created_by                  uuid,
    updated_by                  uuid,
    created_at                  timestamp with time zone NOT NULL DEFAULT now(),
    updated_at                  timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT courier_shipment_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX uq_courier_shipment_number
    ON public.courier_shipment (org_id, courier_shipment_number)
    WHERE is_deleted = false;

-- AWB is globally unique per org per courier (a Shiprocket AWB can collide with a
-- BlueDart one in theory; key on the pair).
CREATE UNIQUE INDEX uq_courier_shipment_awb
    ON public.courier_shipment (org_id, courier_partner, awb_number)
    WHERE awb_number IS NOT NULL AND is_deleted = false;

CREATE INDEX idx_courier_shipment_invoice
    ON public.courier_shipment (org_id, invoice_id)
    WHERE invoice_id IS NOT NULL AND is_deleted = false;

CREATE INDEX idx_courier_shipment_status
    ON public.courier_shipment (org_id, status)
    WHERE is_deleted = false;


CREATE TABLE public.courier_shipment_event (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id              uuid NOT NULL,
    courier_shipment_id uuid NOT NULL,
    -- What status the courier reported and when. Append-only — corrections come
    -- as new events, never as updates.
    event_status        character varying(40) NOT NULL,
    event_at            timestamp with time zone NOT NULL,
    location            character varying(200),
    raw_payload         jsonb,
    source              character varying(20) NOT NULL,    -- WEBHOOK | POLL | MANUAL
    created_at          timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT courier_shipment_event_pkey PRIMARY KEY (id),
    CONSTRAINT fk_courier_shipment_event_shipment
        FOREIGN KEY (courier_shipment_id) REFERENCES public.courier_shipment(id)
);

CREATE INDEX idx_courier_event_shipment
    ON public.courier_shipment_event (org_id, courier_shipment_id, event_at DESC);


CREATE TABLE public.cod_remittance (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id              uuid NOT NULL,
    remittance_number   character varying(40) NOT NULL,    -- CODR-00001
    courier_partner     character varying(40) NOT NULL,
    -- What the courier remitted to our bank
    remittance_date     date NOT NULL,
    bank_account        character varying(80),
    utr                 character varying(60),             -- bank UTR / reference no.
    gross_collected     numeric(14, 2) NOT NULL DEFAULT 0, -- Σ cod_amount across lines
    total_fees          numeric(14, 2) NOT NULL DEFAULT 0, -- Σ cod_fee withheld by courier
    net_remitted        numeric(14, 2) NOT NULL DEFAULT 0, -- what hit our bank
    expected_net        numeric(14, 2) NOT NULL DEFAULT 0, -- gross_collected - total_fees
    variance            numeric(14, 2) NOT NULL DEFAULT 0, -- net_remitted - expected_net
    -- Lifecycle: DRAFT (uploaded) | RECONCILED (settled invoices + variance booked)
    status              character varying(20) NOT NULL DEFAULT 'DRAFT',
    notes               text,
    is_deleted          boolean NOT NULL DEFAULT false,
    created_by          uuid,
    updated_by          uuid,
    created_at          timestamp with time zone NOT NULL DEFAULT now(),
    updated_at          timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT cod_remittance_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX uq_cod_remittance_number
    ON public.cod_remittance (org_id, remittance_number)
    WHERE is_deleted = false;


CREATE TABLE public.cod_remittance_line (
    id                      uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id                  uuid NOT NULL,
    cod_remittance_id       uuid NOT NULL,
    -- One line = one COD parcel the courier collected for
    awb_number              character varying(60) NOT NULL,
    courier_shipment_id     uuid,                          -- matched on ingest if found
    invoice_id              uuid,                          -- copied from the shipment
    cod_amount              numeric(14, 2) NOT NULL,       -- what the customer paid courier
    cod_fee                 numeric(14, 2) NOT NULL DEFAULT 0,
    net_amount              numeric(14, 2) NOT NULL,       -- cod_amount - cod_fee
    -- Outcome of settle:
    --   MATCHED   = AWB+invoice found; payment + fee posted
    --   ORPHAN    = AWB not found in books; line ignored, surfaces in Inbox
    --   AMOUNT_MISMATCH = COD ≠ invoice balance; needs review
    match_status            character varying(20) NOT NULL DEFAULT 'PENDING',
    payment_id              uuid,                          -- set when settled
    notes                   text,
    created_at              timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT cod_remittance_line_pkey PRIMARY KEY (id),
    CONSTRAINT fk_cod_remittance_line_remittance
        FOREIGN KEY (cod_remittance_id) REFERENCES public.cod_remittance(id)
);

CREATE INDEX idx_cod_remittance_line_awb
    ON public.cod_remittance_line (org_id, awb_number);
