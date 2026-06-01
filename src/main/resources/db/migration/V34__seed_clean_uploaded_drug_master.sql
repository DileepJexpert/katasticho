-- Seed clean factual drug master reference data from uploaded medicine lists.
-- Accepted rows contain only factual fields: brand, salt composition, manufacturer, HSN/GST, dosage form, pack, MRP, prescription flag.
-- Rejected rows with page descriptions, usage text, directions, reviews, storage prose, source-site metadata, or malformed fields.

INSERT INTO salt_master(name, category) VALUES
  ('Eschscholtzia Cali.,Lupulus Q,Passiflora Incarnata Q,ZincumMetallicum 6x,Purified water q.s', NULL),
  ('Ferrum lacticum 1X, Ammonium acetate 1X, Natrum phosphoricum 1X, Kalium phosphoricum 1X, Citric acid 1X, Acid phosphoricum 1X', NULL),
  ('Clotrimazole', NULL),
  ('Potassium iodide,Sodium chloride,Calcium chloride', NULL),
  ('Clotrimazole IP 1% w/w,Talc 52.25 - ,Starch 35.0-50.0,Cabosil 0.15-0.22,Perfume 0.75-1.0', NULL),
  ('Calcium carbonate from an organic source Equivalent to Elemental Calcium , Chloecalciferol IP', NULL),
  ('Elemental Calcium: ,Vitamin D3', NULL),
  ('Sabal Serrulata,Echinacea Purpurea,Passiflora Incarnata,Cantharis,Mercurius Biliodatus,Excipients,Alcohol', NULL),
  ('Calcarea Picrata', NULL),
  ('Lactulose', NULL),
  ('Calcitriol + Calcium Carbonate + Zinc Sulfate', NULL),
  ('Cucumber Demineralised Water', NULL),
  ('Demineralised Water Rose Petals', NULL),
  ('Diclofenac diethylamine Methyl salicylate Menthol', NULL),
  ('Hyoscine butylbromide ,Paracetamol', NULL),
  ('Crab Apple', NULL)
ON CONFLICT (name) DO NOTHING;

WITH seed(brand_name, generic_name, salt_name, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) AS (
  VALUES
  ('Adven D-Stress Drop', 'Eschscholtzia Cali.,Lupulus Q,Passiflora Incarnata Q,ZincumMetallicum 6x,Purified water q.s', 'Eschscholtzia Cali.,Lupulus Q,Passiflora Incarnata Q,ZincumMetallicum 6x,Purified water q.s', 'Eschscholtzia Cali.,Lupulus Q,Passiflora Incarnata Q,ZincumMetallicum 6x,Purified water q.s', 'Adven Biotech Pvt Ltd', '3004', 12.00, 'GENERAL', 'Drop', '1 Bottle of 30 ml', 220.00, FALSE),
  ('Adven Hemotone Iron Tonic', 'Ferrum lacticum 1X, Ammonium acetate 1X, Natrum phosphoricum 1X, Kalium phosphoricum 1X, Citric acid 1X, Acid phosphoricum 1X', 'Ferrum lacticum 1X, Ammonium acetate 1X, Natrum phosphoricum 1X, Kalium phosphoricum 1X, Citric acid 1X, Acid phosphoricum 1X', 'Ferrum lacticum 1X, Ammonium acetate 1X, Natrum phosphoricum 1X, Kalium phosphoricum 1X, Citric acid 1X, Acid phosphoricum 1X', 'Adven Biotech Pvt Ltd', '3004', 12.00, 'GENERAL', 'Syrup', '1 Bottle of 100 ml', 118.00, FALSE),
  ('Alloes Alodust Antifungal Clotrimazole Absorbent Powder (100gm Each)', 'Clotrimazole', 'Clotrimazole', 'Clotrimazole', 'Alloes Pharmaceuticals', '3004', 12.00, 'GENERAL', 'Powder', '100gm', 240.00, FALSE),
  ('Calodin Eye Drop', 'Potassium iodide,Sodium chloride,Calcium chloride', 'Potassium iodide,Sodium chloride,Calcium chloride', 'Potassium iodide,Sodium chloride,Calcium chloride', 'Syntho Pharmaceuticals Pvt Ltd', '3004', 12.00, 'GENERAL', 'Drop', '1 Bottle of 10 ml', 85.31, FALSE),
  ('Canesten Antifungal Dusting Powder', 'Clotrimazole IP 1% w/w,Talc 52.25 - 65.0 w/w,Starch 35.0-50.0,Cabosil 0.15-0.22,Perfume 0.75-1.0', 'Clotrimazole IP 1% w/w,Talc 52.25 - ,Starch 35.0-50.0,Cabosil 0.15-0.22,Perfume 0.75-1.0', 'Clotrimazole IP 1% w/w,Talc 52.25 - 65.0 w/w,Starch 35.0-50.0,Cabosil 0.15-0.22,Perfume 0.75-1.0', 'Bayer Pharmaceuticals Pvt Ltd', '3004', 12.00, 'GENERAL', 'Powder', '1 Box of 50 gm', 75.00, FALSE),
  ('Cipcal 500 Tablet', 'Calcium carbonate from an organic source (Oyester Shell) Equivalent to Elemental Calcium 500mg, Chloecalciferol IP(Vitamin D3)', 'Calcium carbonate from an organic source Equivalent to Elemental Calcium , Chloecalciferol IP', 'Calcium carbonate from an organic source (Oyester Shell) Equivalent to Elemental Calcium 500mg, Chloecalciferol IP(Vitamin D3)', 'Cipla Ltd', '3004', 12.00, 'GENERAL', 'Tablet', NULL, 431.68, FALSE),
  ('Clocip Anti-Fungal Dusting Powder', 'Clotrimazole (1% w/w)', 'Clotrimazole', 'Clotrimazole (1% w/w)', 'Cipla Health Ltd', '3004', 12.00, 'GENERAL', 'Powder', NULL, NULL, FALSE),
  ('Dr Willmar Schwabe India Sabal Pentarkan Drop', 'Sabal Serrulata,Echinacea Purpurea,Passiflora Incarnata,Cantharis,Mercurius Biliodatus,Excipients,Alcohol', 'Sabal Serrulata,Echinacea Purpurea,Passiflora Incarnata,Cantharis,Mercurius Biliodatus,Excipients,Alcohol', 'Sabal Serrulata,Echinacea Purpurea,Passiflora Incarnata,Cantharis,Mercurius Biliodatus,Excipients,Alcohol', 'Dr Willmar Schwabe India Pvt Ltd', '3004', 12.00, 'GENERAL', 'Drop', NULL, 430.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 10M', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '1 Box of 1 Pack', 175.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 10M', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 350.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 12 CH', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '1 Box of 1 Pack', 106.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 12 CH', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 212.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 1M', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '1 Box of 1 Pack', 155.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 1M', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 310.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 200 CH', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 160.31, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 3 CH', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '1 Box of 1 Pack', 106.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 3 CH', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 212.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 30 CH', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 106.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 3X', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '1 Box of 1 Pack', 155.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 3X', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 310.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 50M', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '1 Box of 1 Pack', 195.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 50M', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 390.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 6 CH', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '1 Box of 1 Pack', 106.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 6 CH', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 212.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) CM', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '1 Box of 1 Pack', 215.00, FALSE),
  ('Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) CM', 'Calcarea Picrata', 'Calcarea Picrata', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 430.00, FALSE),
  ('Easylax L Oral Solution Lemon Sugar Free', 'Lactulose (10gm/15ml)', 'Lactulose', 'Lactulose (10gm/15ml)', 'Cipla Ltd', '3004', 12.00, 'GENERAL', 'Oral Solution', '100.0 ml', 129.15, FALSE),
  ('Easylax L Oral Solution Lemon Sugar Free', 'Lactulose (10gm/15ml)', 'Lactulose', 'Lactulose (10gm/15ml)', 'Cipla Ltd', '3004', 12.00, 'GENERAL', 'Oral Solution', '200.0 ml', 258.30, FALSE),
  ('Gemsoline Soft Gelatin Capsule from Medley for Bone, Joint and Muscle Care', 'Calcitriol (0.25mcg) + Calcium Carbonate (500mg) + Zinc Sulfate (7.5mg)', 'Calcitriol + Calcium Carbonate + Zinc Sulfate', 'Calcitriol (0.25mcg) + Calcium Carbonate (500mg) + Zinc Sulfate (7.5mg)', 'Medley Pharmaceuticals', '3004', 12.00, 'GENERAL', 'Softgel', NULL, 276.00, FALSE),
  ('Khadi Pure Herbal Cucumber Water Natural Skin Toner (210ml Each)', 'Cucumber Demineralised Water', 'Cucumber Demineralised Water', 'Cucumber Demineralised Water', 'Khadi Pure Gramodyog', '3004', 12.00, 'GENERAL', 'Other', '210ml', 240.00, FALSE),
  ('Khadi Pure Herbal Rose Water Natural Skin Toner (210ml Each)', 'Demineralised Water Rose Petals', 'Demineralised Water Rose Petals', 'Demineralised Water Rose Petals', 'Khadi Pure Gramodyog', '3004', 12.00, 'GENERAL', 'Other', '210ml', 240.00, FALSE),
  ('Lactolook Oral Solution Sugar Free', 'Lactulose (10gm/15ml)', 'Lactulose', 'Lactulose (10gm/15ml)', 'Knoll Healthcare Pvt Ltd', '3004', 12.00, 'GENERAL', 'Oral Solution', '100.0 ml', 129.00, FALSE),
  ('Meditek Diclotek Super Spray (55gm Each)', 'Diclofenac diethylamine Methyl salicylate Menthol', 'Diclofenac diethylamine Methyl salicylate Menthol', 'Diclofenac diethylamine Methyl salicylate Menthol', 'Meditek Lifesciences Pvt. Ltd', '3004', 12.00, 'GENERAL', 'Spray', '55gm', 206.25, FALSE),
  ('Saridon Woman, Fast Action Against Abdominal, Body Pain and Headaches Tablet', 'Hyoscine butylbromide 10 mg,Paracetamol 500 mg', 'Hyoscine butylbromide ,Paracetamol', 'Hyoscine butylbromide 10 mg,Paracetamol 500 mg', 'Bayer', '3004', 12.00, 'GENERAL', 'Tablet', '1 Strip of 5 tablets', 46.88, FALSE),
  ('St. Georges Bach Flower Crab Apple', 'Crab Apple', 'Crab Apple', 'Crab Apple', 'St. George''s Homoeopathy', '3004', 12.00, 'GENERAL', 'Other', '1 Bottle of 100 ml', 350.00, FALSE),
  ('St. Georges Bach Flower Crab Apple', 'Crab Apple', 'Crab Apple', 'Crab Apple', 'St. George''s Homoeopathy', '3004', 12.00, 'GENERAL', 'Other', '1 Bottle of 30 ml', 185.00, FALSE)
)
INSERT INTO drug_master(brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required)
SELECT s.brand_name, s.generic_name, sm.id, s.salt_composition, s.manufacturer, s.hsn_code, s.gst_rate::NUMERIC(5,2), s.drug_schedule, s.dosage_form, s.pack_size, s.mrp::NUMERIC(15,2), s.prescription_required
FROM seed s
JOIN salt_master sm ON sm.name = s.salt_name
WHERE NOT EXISTS (
  SELECT 1 FROM drug_master dm
  WHERE lower(dm.brand_name) = lower(s.brand_name)
    AND coalesce(lower(dm.manufacturer),'') = coalesce(lower(s.manufacturer),'')
    AND coalesce(dm.pack_size,'') = coalesce(s.pack_size,'')
);
