-- Core modules: enabled for ALL existing orgs
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
        ('PAYMENTS')
) AS m(module_code)
ON CONFLICT (org_id, feature) DO NOTHING;

-- POS: retail, grocery, electronics, garments, food industries
INSERT INTO org_feature_flag (org_id, feature, is_enabled, config)
SELECT o.id, 'POS', true, '{}'::jsonb
FROM organisation o
WHERE o.industry_code IN (
    'TRADING','KIRANA','OTHER_RETAIL','RETAIL','RETAILER','DISTRIBUTOR',
    'GROCERY','SUPERMARKET','FRUITS_VEG','ORGANIC','KIRANA_STORE',
    'SUPERMARKET_CHAIN','FRUITS_VEGETABLES','ORGANIC_STORE',
    'ELECTRONICS','MOBILE','APPLIANCES','LED','CCTV',
    'COMPUTER_LAPTOP','MOBILE_ACCESSORIES','HOME_APPLIANCES',
    'LED_LIGHTING','CCTV_SECURITY',
    'GARMENTS','FABRIC','FOOTWEAR','JEWELRY','COSMETICS',
    'READYMADE_GARMENTS','FABRIC_STORE','FOOTWEAR_SHOP',
    'JEWELLERY_SHOP','COSMETICS_BEAUTY',
    'FOOD','BAKERY','CATERING','CLOUD_KITCHEN','JUICE',
    'RESTAURANT','BAKERY_CONFECTIONERY','CATERING_SERVICE',
    'CLOUD_KITCHEN_BRAND','JUICE_BEVERAGE'
)
ON CONFLICT (org_id, feature) DO NOTHING;

-- INVENTORY: all retail, grocery, electronics, garments, food, pharma, manufacturing
INSERT INTO org_feature_flag (org_id, feature, is_enabled, config)
SELECT o.id, 'INVENTORY', true, '{}'::jsonb
FROM organisation o
WHERE o.industry_code IN (
    'TRADING','KIRANA','OTHER_RETAIL','RETAIL','RETAILER','DISTRIBUTOR',
    'GROCERY','SUPERMARKET','FRUITS_VEG','ORGANIC','KIRANA_STORE',
    'SUPERMARKET_CHAIN','FRUITS_VEGETABLES','ORGANIC_STORE',
    'ELECTRONICS','MOBILE','APPLIANCES','LED','CCTV',
    'COMPUTER_LAPTOP','MOBILE_ACCESSORIES','HOME_APPLIANCES',
    'LED_LIGHTING','CCTV_SECURITY',
    'GARMENTS','FABRIC','FOOTWEAR','JEWELRY','COSMETICS',
    'READYMADE_GARMENTS','FABRIC_STORE','FOOTWEAR_SHOP',
    'JEWELLERY_SHOP','COSMETICS_BEAUTY',
    'FOOD','BAKERY','CATERING','CLOUD_KITCHEN','JUICE',
    'RESTAURANT','BAKERY_CONFECTIONERY','CATERING_SERVICE',
    'CLOUD_KITCHEN_BRAND','JUICE_BEVERAGE',
    'PHARMACY','AYURVEDIC','ALLOPATHIC_MEDICINE','AYURVEDIC_HERBAL',
    'SINGLE_MEDICAL_STORE','MEDICAL_SHOP_CHAIN',
    'PHARMA_MANUFACTURER','ALLOPATHIC_MANUFACTURER',
    'FOOD_MANUFACTURER','FOOD_PROCESSING',
    'GARMENT_MANUFACTURER','APPAREL_MANUFACTURER',
    'ELECTRONICS_MANUFACTURER','ELECTRONICS_MFG'
)
ON CONFLICT (org_id, feature) DO NOTHING;

-- PHARMA: pharmacy retail and pharma manufacturing
INSERT INTO org_feature_flag (org_id, feature, is_enabled, config)
SELECT o.id, 'PHARMA', true, '{}'::jsonb
FROM organisation o
WHERE o.industry_code IN (
    'PHARMACY','AYURVEDIC','ALLOPATHIC_MEDICINE','AYURVEDIC_HERBAL',
    'SINGLE_MEDICAL_STORE','MEDICAL_SHOP_CHAIN',
    'PHARMA_MANUFACTURER','ALLOPATHIC_MANUFACTURER'
)
ON CONFLICT (org_id, feature) DO NOTHING;

-- BATCH_EXPIRY: pharmacy retail and pharma manufacturing
INSERT INTO org_feature_flag (org_id, feature, is_enabled, config)
SELECT o.id, 'BATCH_EXPIRY', true, '{}'::jsonb
FROM organisation o
WHERE o.industry_code IN (
    'PHARMACY','AYURVEDIC','ALLOPATHIC_MEDICINE','AYURVEDIC_HERBAL',
    'SINGLE_MEDICAL_STORE','MEDICAL_SHOP_CHAIN',
    'PHARMA_MANUFACTURER','ALLOPATHIC_MANUFACTURER'
)
ON CONFLICT (org_id, feature) DO NOTHING;

-- MANUFACTURING: all manufacturing industries
INSERT INTO org_feature_flag (org_id, feature, is_enabled, config)
SELECT o.id, 'MANUFACTURING', true, '{}'::jsonb
FROM organisation o
WHERE o.industry_code IN (
    'PHARMA_MANUFACTURER','ALLOPATHIC_MANUFACTURER',
    'FOOD_MANUFACTURER','FOOD_PROCESSING',
    'GARMENT_MANUFACTURER','APPAREL_MANUFACTURER',
    'ELECTRONICS_MANUFACTURER','ELECTRONICS_MFG'
)
ON CONFLICT (org_id, feature) DO NOTHING;
