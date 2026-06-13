-- ============================================================================
-- V7: HSN/GST directory expansion — common kirana / FMCG / general-retail codes.
--
-- Marg ships the full HSN book preloaded so a first-time grocer/general store
-- can pick an item's HSN and have GST auto-fill. hsn_gst_master previously held
-- only 10 pharma rows (chapter 30 + medical devices). This adds the most common
-- non-pharma codes at their post-GST-2.0 rates.
--
-- Rates per Notification 9/2025-CT(Rate), effective 22 Sept 2025 (the two-slab
-- 5%/18% structure, plus 0% essentials and 40% sin/luxury). Corroborated across
-- CAclubindia/CMAKnowledge HSN schedules and ClearTax. Rates reflect the typical
-- PRE-PACKAGED & LABELLED retail case — loose/unbranded staples may be nil, so
-- override gst_rate per item where needed.
--
-- Deliberately omitted (ambiguous or conflicting): common salt 2501,
-- tea 0902 / coffee 0901 (processed-vs-unprocessed split), and namkeen 2106
-- (that code already exists @ 18% for food supplements — one rate per code).
-- All codes below are new (no collision with the existing 10 rows).
-- ============================================================================

INSERT INTO public.hsn_gst_master (hsn_code, description, category, gst_rate) VALUES
    -- Dairy & eggs
    ('0401', 'Milk and cream, fresh or UHT (not concentrated)', 'DAIRY', 0.00),
    ('0402', 'Milk powder and condensed milk', 'DAIRY', 5.00),
    ('0405', 'Butter and ghee', 'DAIRY', 5.00),
    ('0406', 'Cheese and paneer', 'DAIRY', 5.00),
    ('0407', 'Birds'' eggs, in shell', 'DAIRY', 0.00),
    -- Fresh produce (nil-rated)
    ('0701', 'Potatoes, fresh or chilled', 'PRODUCE', 0.00),
    ('0702', 'Tomatoes, fresh or chilled', 'PRODUCE', 0.00),
    ('0703', 'Onions, garlic and other alliaceous vegetables, fresh', 'PRODUCE', 0.00),
    ('0803', 'Bananas, fresh', 'PRODUCE', 0.00),
    ('0805', 'Citrus fruit, fresh', 'PRODUCE', 0.00),
    ('0808', 'Apples and pears, fresh', 'PRODUCE', 0.00),
    -- Cereals & flours (pre-packaged)
    ('1001', 'Wheat (pre-packaged and labelled)', 'GROCERY', 5.00),
    ('1006', 'Rice (pre-packaged and labelled)', 'GROCERY', 5.00),
    ('1101', 'Wheat flour / atta (pre-packaged and labelled)', 'GROCERY', 5.00),
    ('1102', 'Cereal flours other than wheat (pre-packaged)', 'GROCERY', 5.00),
    ('1103', 'Cereal groats, meal and pellets (suji, dalia)', 'GROCERY', 5.00),
    -- Edible oils
    ('1507', 'Soya-bean oil and its fractions', 'GROCERY', 5.00),
    ('1508', 'Ground-nut oil and its fractions', 'GROCERY', 5.00),
    ('1511', 'Palm oil and its fractions', 'GROCERY', 5.00),
    ('1512', 'Sunflower-seed / safflower oil', 'GROCERY', 5.00),
    ('1514', 'Rapeseed / mustard oil', 'GROCERY', 5.00),
    ('1517', 'Margarine and edible oil mixtures (vanaspati)', 'GROCERY', 5.00),
    -- Sugar
    ('1701', 'Cane or beet sugar, refined', 'GROCERY', 5.00),
    ('1702', 'Other sugars and jaggery (pre-packaged)', 'GROCERY', 5.00),
    -- Bakery & prepared cereals
    ('1904', 'Prepared cereals (poha, murmura, breakfast cereal)', 'GROCERY', 5.00),
    ('1905', 'Biscuits, pastries, cakes and similar bakery wares', 'GROCERY', 5.00),
    -- Beverages
    ('2201', 'Waters, mineral and aerated, unsweetened', 'BEVERAGE', 5.00),
    ('2202', 'Aerated / sweetened carbonated beverages', 'BEVERAGE', 40.00),
    -- Personal care (GST 2.0 cut from 18% to 5%)
    ('3305', 'Hair oil and shampoo', 'PERSONAL_CARE', 5.00),
    ('3306', 'Toothpaste and tooth powder', 'PERSONAL_CARE', 5.00),
    ('3401', 'Toilet soap and soap bars', 'PERSONAL_CARE', 5.00),
    ('9603', 'Tooth brushes, brooms and brushes', 'HOUSEHOLD', 5.00),
    -- Household (detergents stayed at 18% under GST 2.0)
    ('3402', 'Detergents and washing preparations', 'HOUSEHOLD', 18.00),
    -- Stationery (GST 2.0 cut to nil)
    ('4820', 'Exercise books and note books', 'STATIONERY', 0.00),
    -- Footwear (5% for pairs up to Rs.2,500; override for premium)
    ('6402', 'Footwear with rubber / plastic soles (up to Rs.2,500/pair)', 'FOOTWEAR', 5.00),
    ('6403', 'Footwear with leather uppers (up to Rs.2,500/pair)', 'FOOTWEAR', 5.00);
