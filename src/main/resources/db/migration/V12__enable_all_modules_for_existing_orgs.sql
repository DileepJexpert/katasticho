-- Module-level access is now granted to every org by default; industry
-- only drives fine-grained UX flags and menu defaults. Bring existing
-- orgs in line with the new policy by enabling every module flag.

UPDATE public.org_feature_flag
SET is_enabled = true,
    updated_at = now()
WHERE feature IN (
    'ACCOUNTING','AR','AP','GST','BANK_RECON','AI_INBOX','REPORTS','COLLECTIONS',
    'PAYMENTS','POS','INVENTORY','PHARMA','MANUFACTURING','RECURRING_BILLING',
    'MULTI_ENTITY','BATCH_EXPIRY'
)
AND is_enabled = false;

-- Insert any missing module rows for existing orgs so the feature list is complete.
INSERT INTO public.org_feature_flag (id, org_id, feature, is_enabled, created_at, updated_at)
SELECT gen_random_uuid(), o.id, m.feature, true, now(), now()
FROM public.organisation o
CROSS JOIN (VALUES
    ('ACCOUNTING'),('AR'),('AP'),('GST'),('BANK_RECON'),('AI_INBOX'),('REPORTS'),
    ('COLLECTIONS'),('PAYMENTS'),('POS'),('INVENTORY'),('PHARMA'),('MANUFACTURING'),
    ('RECURRING_BILLING'),('MULTI_ENTITY'),('BATCH_EXPIRY')
) AS m(feature)
WHERE NOT EXISTS (
    SELECT 1 FROM public.org_feature_flag f
    WHERE f.org_id = o.id AND f.feature = m.feature
);
