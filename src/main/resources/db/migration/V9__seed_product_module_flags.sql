-- Seed all module-level feature flags (enabled) for every existing org.
-- Module access is granted to every org by default; industry vertical
-- only drives fine-grained UX flags (BATCH_TRACKING, MRP_PRICING, etc.)
-- which are seeded at signup by FeatureFlagService.seedForSubCategories.

INSERT INTO org_feature_flag (org_id, feature, is_enabled, config)
SELECT o.id, m.module_code, true, '{}'::jsonb
FROM organisation o
CROSS JOIN (
    VALUES
        ('ACCOUNTING'),
        ('AR'),
        ('AP'),
        ('GST'),
        ('BANK_RECON'),
        ('AI_INBOX'),
        ('REPORTS'),
        ('COLLECTIONS'),
        ('PAYMENTS'),
        ('POS'),
        ('INVENTORY'),
        ('PHARMA'),
        ('MANUFACTURING'),
        ('RECURRING_BILLING'),
        ('MULTI_ENTITY'),
        ('BATCH_EXPIRY')
) AS m(module_code)
ON CONFLICT (org_id, feature) DO NOTHING;
