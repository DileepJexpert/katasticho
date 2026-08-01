-- V43 - Common grocery HSN coverage for pulses and dal.
-- HSN lookup remains a shared statutory reference; the description is searchable
-- so users can type "dal" instead of remembering the numeric code.

INSERT INTO hsn_gst_master (id, hsn_code, description, category, gst_rate, is_active, created_at)
VALUES (
    'd4b0f5f9-22fc-4c6e-9d3b-9ab9f7d3b1c1',
    '0713',
    'Dried leguminous vegetables (pulses, dal and lentils)',
    'GROCERY',
    5.00,
    true,
    now()
)
ON CONFLICT (hsn_code) DO NOTHING;