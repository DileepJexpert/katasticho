-- ============================================================================
-- V6: GST State Code master (platform-level reference, like hsn_gst_master).
--
-- The official GST/TIN state codes (first two digits of every GSTIN). Marg and
-- other Indian ERPs ship this so a first-time user picks a state from a dropdown
-- instead of typing a free-text code, and so the GSTIN prefix can be validated /
-- the place-of-supply resolved for CGST/SGST-vs-IGST determination.
--
-- No org_id, no BaseEntity — universal facts shared across all tenants.
-- Obsolete codes 25 (Daman & Diu, merged into 26) and 28 (Andhra Pradesh, before
-- the Telangana bifurcation; AP now uses 37) are intentionally omitted.
-- ============================================================================

CREATE TABLE public.gst_state_code (
    id                 uuid DEFAULT gen_random_uuid() NOT NULL,
    code               character varying(2)  NOT NULL,
    state_name         character varying(60) NOT NULL,
    alpha_code         character varying(3),
    is_union_territory boolean DEFAULT false NOT NULL,
    is_active          boolean DEFAULT true  NOT NULL,
    created_at         timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT gst_state_code_pkey PRIMARY KEY (id),
    CONSTRAINT gst_state_code_code_key UNIQUE (code)
);

INSERT INTO public.gst_state_code (code, state_name, alpha_code, is_union_territory) VALUES
    ('01', 'Jammu and Kashmir', 'JK', true),
    ('02', 'Himachal Pradesh', 'HP', false),
    ('03', 'Punjab', 'PB', false),
    ('04', 'Chandigarh', 'CH', true),
    ('05', 'Uttarakhand', 'UK', false),
    ('06', 'Haryana', 'HR', false),
    ('07', 'Delhi', 'DL', true),
    ('08', 'Rajasthan', 'RJ', false),
    ('09', 'Uttar Pradesh', 'UP', false),
    ('10', 'Bihar', 'BR', false),
    ('11', 'Sikkim', 'SK', false),
    ('12', 'Arunachal Pradesh', 'AR', false),
    ('13', 'Nagaland', 'NL', false),
    ('14', 'Manipur', 'MN', false),
    ('15', 'Mizoram', 'MZ', false),
    ('16', 'Tripura', 'TR', false),
    ('17', 'Meghalaya', 'ML', false),
    ('18', 'Assam', 'AS', false),
    ('19', 'West Bengal', 'WB', false),
    ('20', 'Jharkhand', 'JH', false),
    ('21', 'Odisha', 'OD', false),
    ('22', 'Chhattisgarh', 'CG', false),
    ('23', 'Madhya Pradesh', 'MP', false),
    ('24', 'Gujarat', 'GJ', false),
    ('26', 'Dadra and Nagar Haveli and Daman and Diu', 'DN', true),
    ('27', 'Maharashtra', 'MH', false),
    ('29', 'Karnataka', 'KA', false),
    ('30', 'Goa', 'GA', false),
    ('31', 'Lakshadweep', 'LD', true),
    ('32', 'Kerala', 'KL', false),
    ('33', 'Tamil Nadu', 'TN', false),
    ('34', 'Puducherry', 'PY', true),
    ('35', 'Andaman and Nicobar Islands', 'AN', true),
    ('36', 'Telangana', 'TS', false),
    ('37', 'Andhra Pradesh', 'AP', false),
    ('38', 'Ladakh', 'LA', true),
    ('97', 'Other Territory', 'OT', false),
    ('99', 'Centre Jurisdiction', 'CJ', false);
