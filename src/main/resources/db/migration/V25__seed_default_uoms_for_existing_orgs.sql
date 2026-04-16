-- V25: Seed default UoMs for any org that is missing them.
-- New orgs get these via AuthService.signup(), but orgs created
-- before that fix need a backfill.

INSERT INTO uom (id, org_id, name, abbreviation, category, is_base, is_active, is_deleted, created_at, updated_at)
SELECT gen_random_uuid(), o.id, v.name, v.abbr, v.cat::varchar, v.is_base, true, false, now(), now()
FROM organisation o
CROSS JOIN (VALUES
  ('Pieces',      'PCS',    'COUNT',     true),
  ('Strip',       'STRIP',  'PACKAGING', false),
  ('Box',         'BOX',    'PACKAGING', true),
  ('Kilogram',    'KG',     'WEIGHT',    true),
  ('Gram',        'GM',     'WEIGHT',    false),
  ('Litre',       'LTR',    'VOLUME',    true),
  ('Millilitre',  'ML',     'VOLUME',    false),
  ('Metre',       'MTR',    'LENGTH',    true)
) AS v(name, abbr, cat, is_base)
WHERE NOT EXISTS (
  SELECT 1 FROM uom u
  WHERE u.org_id = o.id
  AND upper(u.abbreviation) = upper(v.abbr)
  AND u.is_deleted = false
);
