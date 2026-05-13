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
        ('POS'),
        ('INVENTORY'),
        ('PHARMA'),
        ('MANUFACTURING'),
        ('RECURRING_BILLING'),
        ('MULTI_ENTITY'),
        ('PAYMENTS'),
        ('BATCH_EXPIRY')
) AS m(module_code)
ON CONFLICT (org_id, feature) DO NOTHING;
