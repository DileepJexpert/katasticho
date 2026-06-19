-- ============================================================================
-- V26: Transport — Lorry Receipt (consignment note) + freight rate cards.
--
-- Closes the rest of the Transport pillar for the road/GTA case (truck transport
-- via a transporter, as opposed to parcel couriers in V25):
--   freight_rate_card  — per-transporter origin→destination→weight-slab rates,
--                        so an LR can auto-fill the freight amount
--   lorry_receipt      — the LR / consignment note: transporter, vehicle, route,
--                        freight + payment basis (PAID | TO_PAY | TO_BE_BILLED),
--                        GST treatment (RCM | FORWARD | EXEMPT for GTA), and the
--                        link to the draft purchase bill once freight is billed.
--
-- The transporter itself is a Contact (VENDOR) — no separate master, same as the
-- courier-as-vendor model.
-- ============================================================================

CREATE TABLE public.freight_rate_card (
    id                      uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id                  uuid NOT NULL,
    transporter_contact_id  uuid NOT NULL,                    -- a Contact(VENDOR)
    origin                  character varying(120) NOT NULL,  -- city / zone / pincode
    destination             character varying(120) NOT NULL,
    mode                    character varying(10) NOT NULL DEFAULT 'ROAD',  -- ROAD | RAIL | AIR
    -- Weight slab (kg). max NULL = open-ended top slab.
    weight_slab_min_kg      numeric(12, 3) NOT NULL DEFAULT 0,
    weight_slab_max_kg      numeric(12, 3),
    rate_type               character varying(10) NOT NULL DEFAULT 'PER_KG', -- PER_KG | FLAT | PER_UNIT
    rate                    numeric(14, 2) NOT NULL,
    min_charge              numeric(14, 2) NOT NULL DEFAULT 0,  -- floor for PER_KG/PER_UNIT
    effective_from          date,
    effective_to            date,
    active                  boolean NOT NULL DEFAULT true,
    notes                   text,
    is_deleted              boolean NOT NULL DEFAULT false,
    created_by              uuid,
    updated_by              uuid,
    created_at              timestamp with time zone NOT NULL DEFAULT now(),
    updated_at              timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT freight_rate_card_pkey PRIMARY KEY (id)
);

CREATE INDEX idx_freight_rate_card_lookup
    ON public.freight_rate_card (org_id, transporter_contact_id, mode)
    WHERE is_deleted = false AND active = true;


CREATE TABLE public.lorry_receipt (
    id                      uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id                  uuid NOT NULL,
    lr_number               character varying(40) NOT NULL,
    lr_date                 date NOT NULL,
    -- Parties
    transporter_contact_id  uuid NOT NULL,                    -- the GTA / transporter (VENDOR)
    contact_id              uuid,                             -- consignee (customer)
    -- Provenance
    delivery_challan_id     uuid,
    invoice_id              uuid,
    eway_bill_no            character varying(30),
    -- Vehicle / driver
    vehicle_number          character varying(30),
    driver_name             character varying(120),
    driver_phone            character varying(20),
    -- Route
    origin                  character varying(120),
    destination             character varying(120),
    distance_km             numeric(10, 2),
    mode                    character varying(10) NOT NULL DEFAULT 'ROAD',
    -- Goods
    num_packages            integer,
    weight_kg               numeric(12, 3),
    declared_value          numeric(14, 2),
    -- Freight
    freight_amount          numeric(14, 2) NOT NULL DEFAULT 0,
    freight_basis           character varying(15) NOT NULL DEFAULT 'TO_BE_BILLED',
    -- PAID (we paid at booking) | TO_PAY (consignee pays) | TO_BE_BILLED (transporter bills us)
    gst_treatment           character varying(10) NOT NULL DEFAULT 'RCM',
    -- RCM (GTA reverse charge, the common case) | FORWARD | EXEMPT
    freight_gst_rate        numeric(5, 2) NOT NULL DEFAULT 5,
    freight_bill_id         uuid,                             -- the draft purchase bill, once billed
    -- Lifecycle: DRAFT | ISSUED | DELIVERED | CANCELLED
    status                  character varying(20) NOT NULL DEFAULT 'DRAFT',
    notes                   text,
    is_deleted              boolean NOT NULL DEFAULT false,
    created_by              uuid,
    updated_by              uuid,
    created_at              timestamp with time zone NOT NULL DEFAULT now(),
    updated_at              timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT lorry_receipt_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX uq_lorry_receipt_number
    ON public.lorry_receipt (org_id, lr_number)
    WHERE is_deleted = false;

CREATE INDEX idx_lorry_receipt_transporter
    ON public.lorry_receipt (org_id, transporter_contact_id)
    WHERE is_deleted = false;

CREATE INDEX idx_lorry_receipt_status
    ON public.lorry_receipt (org_id, status)
    WHERE is_deleted = false;
