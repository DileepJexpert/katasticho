-- V26: Seed additional UoMs (PACK, BOTTLE, BAG, DOZEN) for existing orgs.
-- V25 covered the basics; this adds the remaining UoMs used by the sample CSV.

INSERT INTO uom (id, org_id, name, abbreviation, category, is_base, is_active, is_deleted, created_at, updated_at)
SELECT gen_random_uuid(), o.id, v.name, v.abbr, v.cat::varchar, v.is_base, true, false, now(), now()
FROM organisation o
CROSS JOIN (VALUES
  ('Pack',    'PACK',   'PACKAGING', false),
  ('Bottle',  'BOTTLE', 'PACKAGING', false),
  ('Bag',     'BAG',    'PACKAGING', false),
  ('Dozen',   'DOZEN',  'COUNT',     false)
) AS v(name, abbr, cat, is_base)
WHERE NOT EXISTS (
  SELECT 1 FROM uom u
  WHERE u.org_id = o.id
  AND upper(u.abbreviation) = upper(v.abbr)
  AND u.is_deleted = false
);
