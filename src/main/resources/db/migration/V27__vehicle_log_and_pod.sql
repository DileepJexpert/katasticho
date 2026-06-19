-- ============================================================================
-- V27: Own-fleet TCO (vehicle log) + Proof of Delivery — the last two TMS gaps.
--
--   vehicle_log         — per-vehicle fuel / service / repair / insurance / etc.
--                         entries; powers the running-cost (₹/km) + mileage view.
--   proof_of_delivery   — recipient + signature/photo (via AttachmentService) +
--                         GPS captured against a delivery challan / courier parcel.
-- ============================================================================

CREATE TABLE public.vehicle_log (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id              uuid NOT NULL,
    -- A vehicle is identified by its number; van_id links to the field-sales Van
    -- master when there is one (optional).
    vehicle_number      character varying(30) NOT NULL,
    van_id              uuid,
    log_type            character varying(20) NOT NULL,
    -- FUEL | SERVICE | REPAIR | INSURANCE | FITNESS | PERMIT | TYRE | OTHER
    log_date            date NOT NULL,
    odometer_km         numeric(12, 2),
    quantity            numeric(12, 3),          -- litres for FUEL
    amount              numeric(14, 2) NOT NULL DEFAULT 0,
    vendor_contact_id   uuid,                    -- garage / fuel station (optional)
    reference_no        character varying(60),
    notes               text,
    is_deleted          boolean NOT NULL DEFAULT false,
    created_by          uuid,
    updated_by          uuid,
    created_at          timestamp with time zone NOT NULL DEFAULT now(),
    updated_at          timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT vehicle_log_pkey PRIMARY KEY (id)
);

CREATE INDEX idx_vehicle_log_vehicle
    ON public.vehicle_log (org_id, vehicle_number, log_date DESC)
    WHERE is_deleted = false;


CREATE TABLE public.proof_of_delivery (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id              uuid NOT NULL,
    -- Flexible linkage — at least one of these points at what was delivered.
    delivery_challan_id uuid,
    courier_shipment_id uuid,
    invoice_id          uuid,
    contact_id          uuid,                    -- consignee
    recipient_name      character varying(120),
    recipient_phone     character varying(20),
    delivered_at        timestamp with time zone NOT NULL DEFAULT now(),
    geo_latitude        numeric(10, 7),
    geo_longitude       numeric(10, 7),
    notes               text,
    -- Signature + photos are stored via AttachmentService (entity_type='POD',
    -- entity_id = this row's id).
    is_deleted          boolean NOT NULL DEFAULT false,
    created_by          uuid,
    updated_by          uuid,
    created_at          timestamp with time zone NOT NULL DEFAULT now(),
    updated_at          timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT proof_of_delivery_pkey PRIMARY KEY (id)
);

CREATE INDEX idx_pod_challan
    ON public.proof_of_delivery (org_id, delivery_challan_id)
    WHERE delivery_challan_id IS NOT NULL AND is_deleted = false;
