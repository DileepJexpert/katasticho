-- V37: Seed drug interactions and generic substitutions using salts/drugs
-- that are guaranteed to exist from V28 (salt_master) and V28 (drug_master).
-- Fixes BUG-4 (empty drug_interaction) and BUG-5 (empty generic_substitution).

-- ============================================================
-- DRUG INTERACTIONS (BUG-4)
-- Uses only salts seeded in V28 salt_master.
-- ============================================================

-- Aspirin + Ibuprofen: both NSAIDs, combined use increases GI bleeding risk
INSERT INTO drug_interaction (primary_salt_id, interacting_salt_id, severity, warning, recommendation)
SELECT s1.id, s2.id,
       'MODERATE',
       'Concurrent use of Aspirin and Ibuprofen may reduce the cardioprotective effect of Aspirin and increase risk of gastrointestinal bleeding.',
       'Avoid regular combined use. If both are needed, take Aspirin 30 minutes before Ibuprofen. Advise patient to report GI symptoms.'
FROM salt_master s1, salt_master s2
WHERE LOWER(s1.name) = 'aspirin'
  AND LOWER(s2.name) = 'ibuprofen'
ON CONFLICT (primary_salt_id, interacting_salt_id) DO NOTHING;

-- Metformin HCl + Alcohol (not in salt_master, skip) — use Metformin + Contrast agents proxy
-- Metformin + Furosemide: Furosemide can reduce Metformin excretion, increasing lactic acidosis risk
INSERT INTO drug_interaction (primary_salt_id, interacting_salt_id, severity, warning, recommendation)
SELECT s1.id, s2.id,
       'MODERATE',
       'Furosemide can increase Metformin plasma levels by reducing renal clearance, raising the risk of lactic acidosis.',
       'Monitor renal function when combining. Consider dose adjustment of Metformin. Hold Metformin if eGFR drops below 30.'
FROM salt_master s1, salt_master s2
WHERE LOWER(s1.name) = 'metformin hcl'
  AND LOWER(s2.name) = 'furosemide'
ON CONFLICT (primary_salt_id, interacting_salt_id) DO NOTHING;

-- Metformin + Hydrochlorothiazide: thiazides cause hyperglycemia, antagonising Metformin effect
INSERT INTO drug_interaction (primary_salt_id, interacting_salt_id, severity, warning, recommendation)
SELECT s1.id, s2.id,
       'MODERATE',
       'Hydrochlorothiazide can cause hyperglycemia, reducing the efficacy of Metformin in controlling blood glucose.',
       'Monitor blood glucose closely when initiating or changing thiazide dose. Adjust antidiabetic therapy as needed.'
FROM salt_master s1, salt_master s2
WHERE LOWER(s1.name) = 'metformin hcl'
  AND LOWER(s2.name) = 'hydrochlorothiazide'
ON CONFLICT (primary_salt_id, interacting_salt_id) DO NOTHING;

-- Aspirin + Diclofenac Sodium: dual NSAID risk
INSERT INTO drug_interaction (primary_salt_id, interacting_salt_id, severity, warning, recommendation)
SELECT s1.id, s2.id,
       'HIGH',
       'Combined use of Aspirin and Diclofenac significantly increases the risk of gastrointestinal ulceration and bleeding.',
       'Avoid co-administration unless under specialist supervision. If unavoidable, add a PPI (e.g. Omeprazole) for gastric protection.'
FROM salt_master s1, salt_master s2
WHERE LOWER(s1.name) = 'aspirin'
  AND LOWER(s2.name) = 'diclofenac sodium'
ON CONFLICT (primary_salt_id, interacting_salt_id) DO NOTHING;

-- Atorvastatin + Erythromycin: CYP3A4 inhibition raises statin levels, myopathy risk
INSERT INTO drug_interaction (primary_salt_id, interacting_salt_id, severity, warning, recommendation)
SELECT s1.id, s2.id,
       'HIGH',
       'Erythromycin inhibits CYP3A4, significantly increasing Atorvastatin plasma levels and the risk of myopathy or rhabdomyolysis.',
       'Temporarily suspend Atorvastatin during short Erythromycin courses. If statin therapy cannot be interrupted, consider a non-CYP3A4 metabolised statin (e.g. Rosuvastatin).'
FROM salt_master s1, salt_master s2
WHERE LOWER(s1.name) = 'atorvastatin calcium'
  AND LOWER(s2.name) = 'erythromycin'
ON CONFLICT (primary_salt_id, interacting_salt_id) DO NOTHING;

-- Atorvastatin + Itraconazole: potent CYP3A4 inhibitor, major rhabdomyolysis risk
INSERT INTO drug_interaction (primary_salt_id, interacting_salt_id, severity, warning, recommendation)
SELECT s1.id, s2.id,
       'CRITICAL',
       'Itraconazole is a potent CYP3A4 inhibitor that can dramatically increase Atorvastatin levels, causing severe myopathy or rhabdomyolysis.',
       'Avoid co-administration. Suspend Atorvastatin during Itraconazole treatment. Use Fluconazole (weaker CYP3A4 effect) as antifungal alternative where possible.'
FROM salt_master s1, salt_master s2
WHERE LOWER(s1.name) = 'atorvastatin calcium'
  AND LOWER(s2.name) = 'itraconazole'
ON CONFLICT (primary_salt_id, interacting_salt_id) DO NOTHING;

-- Ciprofloxacin + Theophylline: fluoroquinolone inhibits CYP1A2, theophylline toxicity
INSERT INTO drug_interaction (primary_salt_id, interacting_salt_id, severity, warning, recommendation)
SELECT s1.id, s2.id,
       'HIGH',
       'Ciprofloxacin inhibits CYP1A2, reducing Theophylline clearance and increasing risk of theophylline toxicity (nausea, tremors, seizures).',
       'Reduce Theophylline dose by 30–50% when starting Ciprofloxacin. Monitor serum theophylline levels and clinical signs of toxicity.'
FROM salt_master s1, salt_master s2
WHERE LOWER(s1.name) = 'ciprofloxacin hcl'
  AND LOWER(s2.name) = 'theophylline'
ON CONFLICT (primary_salt_id, interacting_salt_id) DO NOTHING;

-- Fluconazole + Metronidazole: disulfiram-like reaction risk
INSERT INTO drug_interaction (primary_salt_id, interacting_salt_id, severity, warning, recommendation)
SELECT s1.id, s2.id,
       'MODERATE',
       'Concurrent use of Fluconazole and Metronidazole may potentiate QT prolongation and increase risk of serious cardiac arrhythmias.',
       'Use with caution in patients with cardiac risk factors. Obtain baseline ECG and monitor for QT prolongation.'
FROM salt_master s1, salt_master s2
WHERE LOWER(s1.name) = 'fluconazole'
  AND LOWER(s2.name) = 'metronidazole'
ON CONFLICT (primary_salt_id, interacting_salt_id) DO NOTHING;

-- Diclofenac + Methotrexate proxy: use Diclofenac + Metformin — not ideal, use Ibuprofen + Prednisolone
-- Prednisolone + Ibuprofen: dual GI risk (steroid + NSAID)
INSERT INTO drug_interaction (primary_salt_id, interacting_salt_id, severity, warning, recommendation)
SELECT s1.id, s2.id,
       'HIGH',
       'Prednisolone combined with Ibuprofen substantially increases the risk of gastrointestinal ulceration, bleeding, and perforation.',
       'Avoid combination where possible. If both required, add a PPI (Omeprazole 20mg daily) for gastric protection. Warn patient to report abdominal pain or black stools immediately.'
FROM salt_master s1, salt_master s2
WHERE LOWER(s1.name) = 'prednisolone'
  AND LOWER(s2.name) = 'ibuprofen'
ON CONFLICT (primary_salt_id, interacting_salt_id) DO NOTHING;

-- Sertraline + Tramadol: serotonin syndrome risk
INSERT INTO drug_interaction (primary_salt_id, interacting_salt_id, severity, warning, recommendation)
SELECT s1.id, s2.id,
       'HIGH',
       'Combining Sertraline with Tramadol significantly raises the risk of serotonin syndrome (agitation, hyperthermia, tachycardia, clonus).',
       'Avoid co-administration if possible. If both are prescribed, use the lowest effective Tramadol dose and monitor closely for serotonin syndrome symptoms for 24 hours after initiation.'
FROM salt_master s1, salt_master s2
WHERE LOWER(s1.name) = 'sertraline hcl'
  AND LOWER(s2.name) = 'tramadol hcl'
ON CONFLICT (primary_salt_id, interacting_salt_id) DO NOTHING;

-- Carbamazepine + Erythromycin: CYP3A4 inhibition raises carbamazepine toxicity
INSERT INTO drug_interaction (primary_salt_id, interacting_salt_id, severity, warning, recommendation)
SELECT s1.id, s2.id,
       'HIGH',
       'Erythromycin inhibits the metabolism of Carbamazepine, leading to elevated plasma levels and risk of carbamazepine toxicity (diplopia, ataxia, vomiting).',
       'Avoid combination. If Erythromycin is required in a patient on Carbamazepine, consider an alternative antibiotic such as Azithromycin with less CYP3A4 interaction.'
FROM salt_master s1, salt_master s2
WHERE LOWER(s1.name) = 'carbamazepine'
  AND LOWER(s2.name) = 'erythromycin'
ON CONFLICT (primary_salt_id, interacting_salt_id) DO NOTHING;

-- Metformin + Dapagliflozin: additive hypoglycemia/volume depletion (informational LOW)
INSERT INTO drug_interaction (primary_salt_id, interacting_salt_id, severity, warning, recommendation)
SELECT s1.id, s2.id,
       'LOW',
       'Combined use of Metformin and Dapagliflozin is a standard antidiabetic regimen but requires monitoring for volume depletion and urinary tract infections.',
       'Ensure adequate hydration. Monitor renal function periodically. Educate patient on signs of dehydration and UTI.'
FROM salt_master s1, salt_master s2
WHERE LOWER(s1.name) = 'metformin hcl'
  AND LOWER(s2.name) = 'dapagliflozin'
ON CONFLICT (primary_salt_id, interacting_salt_id) DO NOTHING;

-- ============================================================
-- GENERIC SUBSTITUTIONS (BUG-5)
-- Uses drug_master rows seeded in V28 (brand_name values confirmed there).
-- Pattern: branded originator <-> generic equivalent with same salt.
-- ============================================================

-- Paracetamol brands: Crocin 500mg <-> Dolo 650 is different strength, use same-strength pairs
-- Crocin 500mg <-> Calpol 500mg (both Paracetamol 500mg, different manufacturers)
INSERT INTO generic_substitution (drug_master_id, substitute_drug_master_id, reason, estimated_savings)
SELECT d1.id, d2.id,
       'Same active ingredient (Paracetamol 500mg). Calpol may be substituted for Crocin at lower cost.',
       2.00
FROM drug_master d1, drug_master d2
WHERE d1.brand_name = 'Crocin 500mg'
  AND d2.brand_name = 'Calpol 500mg'
ON CONFLICT (drug_master_id, substitute_drug_master_id) DO NOTHING;

INSERT INTO generic_substitution (drug_master_id, substitute_drug_master_id, reason, estimated_savings)
SELECT d1.id, d2.id,
       'Same active ingredient (Paracetamol 500mg). Crocin may be substituted for Calpol.',
       2.00
FROM drug_master d1, drug_master d2
WHERE d1.brand_name = 'Calpol 500mg'
  AND d2.brand_name = 'Crocin 500mg'
ON CONFLICT (drug_master_id, substitute_drug_master_id) DO NOTHING;

-- Crocin 500mg <-> Paracip 500 (both Paracetamol 500mg)
INSERT INTO generic_substitution (drug_master_id, substitute_drug_master_id, reason, estimated_savings)
SELECT d1.id, d2.id,
       'Same active ingredient (Paracetamol 500mg). Paracip is a cost-effective alternative.',
       2.00
FROM drug_master d1, drug_master d2
WHERE d1.brand_name = 'Crocin 500mg'
  AND d2.brand_name = 'Paracip 500'
ON CONFLICT (drug_master_id, substitute_drug_master_id) DO NOTHING;

-- Ibuprofen brands: Brufen 400mg <-> Ibugesic 400mg
INSERT INTO generic_substitution (drug_master_id, substitute_drug_master_id, reason, estimated_savings)
SELECT d1.id, d2.id,
       'Same active ingredient (Ibuprofen 400mg). Ibugesic is a lower-cost alternative to Brufen.',
       3.00
FROM drug_master d1, drug_master d2
WHERE d1.brand_name = 'Brufen 400mg'
  AND d2.brand_name = 'Ibugesic 400mg'
ON CONFLICT (drug_master_id, substitute_drug_master_id) DO NOTHING;

INSERT INTO generic_substitution (drug_master_id, substitute_drug_master_id, reason, estimated_savings)
SELECT d1.id, d2.id,
       'Same active ingredient (Ibuprofen 400mg). Brufen may be substituted for Ibugesic.',
       3.00
FROM drug_master d1, drug_master d2
WHERE d1.brand_name = 'Ibugesic 400mg'
  AND d2.brand_name = 'Brufen 400mg'
ON CONFLICT (drug_master_id, substitute_drug_master_id) DO NOTHING;

-- Omeprazole brands: Omez 20 <-> Ocid 20
INSERT INTO generic_substitution (drug_master_id, substitute_drug_master_id, reason, estimated_savings)
SELECT d1.id, d2.id,
       'Same active ingredient (Omeprazole 20mg). Ocid is a lower-cost bioequivalent alternative.',
       4.00
FROM drug_master d1, drug_master d2
WHERE d1.brand_name = 'Omez 20'
  AND d2.brand_name = 'Ocid 20'
ON CONFLICT (drug_master_id, substitute_drug_master_id) DO NOTHING;

INSERT INTO generic_substitution (drug_master_id, substitute_drug_master_id, reason, estimated_savings)
SELECT d1.id, d2.id,
       'Same active ingredient (Omeprazole 20mg). Omez may be substituted for Ocid.',
       4.00
FROM drug_master d1, drug_master d2
WHERE d1.brand_name = 'Ocid 20'
  AND d2.brand_name = 'Omez 20'
ON CONFLICT (drug_master_id, substitute_drug_master_id) DO NOTHING;

-- Azithromycin brands: Azithral 500 <-> Azee 500 <-> Zady 500
INSERT INTO generic_substitution (drug_master_id, substitute_drug_master_id, reason, estimated_savings)
SELECT d1.id, d2.id,
       'Same active ingredient (Azithromycin 500mg). Azee is a cost-effective alternative to Azithral.',
       4.00
FROM drug_master d1, drug_master d2
WHERE d1.brand_name = 'Azithral 500'
  AND d2.brand_name = 'Azee 500'
ON CONFLICT (drug_master_id, substitute_drug_master_id) DO NOTHING;

INSERT INTO generic_substitution (drug_master_id, substitute_drug_master_id, reason, estimated_savings)
SELECT d1.id, d2.id,
       'Same active ingredient (Azithromycin 500mg). Zady is a cost-effective alternative to Azithral.',
       10.00
FROM drug_master d1, drug_master d2
WHERE d1.brand_name = 'Azithral 500'
  AND d2.brand_name = 'Zady 500'
ON CONFLICT (drug_master_id, substitute_drug_master_id) DO NOTHING;

-- Pantoprazole brands: Pan 40 <-> Pantodac 40
INSERT INTO generic_substitution (drug_master_id, substitute_drug_master_id, reason, estimated_savings)
SELECT d1.id, d2.id,
       'Same active ingredient (Pantoprazole 40mg). Pantodac is a lower-cost alternative to Pan 40.',
       3.00
FROM drug_master d1, drug_master d2
WHERE d1.brand_name = 'Pan 40'
  AND d2.brand_name = 'Pantodac 40'
ON CONFLICT (drug_master_id, substitute_drug_master_id) DO NOTHING;

INSERT INTO generic_substitution (drug_master_id, substitute_drug_master_id, reason, estimated_savings)
SELECT d1.id, d2.id,
       'Same active ingredient (Pantoprazole 40mg). Pan 40 may be substituted for Pantodac 40.',
       3.00
FROM drug_master d1, drug_master d2
WHERE d1.brand_name = 'Pantodac 40'
  AND d2.brand_name = 'Pan 40'
ON CONFLICT (drug_master_id, substitute_drug_master_id) DO NOTHING;

-- Ciprofloxacin brands: Ciplox 500 <-> Cifran 500
INSERT INTO generic_substitution (drug_master_id, substitute_drug_master_id, reason, estimated_savings)
SELECT d1.id, d2.id,
       'Same active ingredient (Ciprofloxacin 500mg). Cifran is a lower-cost alternative to Ciplox.',
       4.00
FROM drug_master d1, drug_master d2
WHERE d1.brand_name = 'Ciplox 500'
  AND d2.brand_name = 'Cifran 500'
ON CONFLICT (drug_master_id, substitute_drug_master_id) DO NOTHING;

INSERT INTO generic_substitution (drug_master_id, substitute_drug_master_id, reason, estimated_savings)
SELECT d1.id, d2.id,
       'Same active ingredient (Ciprofloxacin 500mg). Ciplox may be substituted for Cifran.',
       4.00
FROM drug_master d1, drug_master d2
WHERE d1.brand_name = 'Cifran 500'
  AND d2.brand_name = 'Ciplox 500'
ON CONFLICT (drug_master_id, substitute_drug_master_id) DO NOTHING;

-- Cefixime brands: Taxim-O 200 <-> Cefix 200
INSERT INTO generic_substitution (drug_master_id, substitute_drug_master_id, reason, estimated_savings)
SELECT d1.id, d2.id,
       'Same active ingredient (Cefixime 200mg). Cefix is a significantly cheaper alternative to Taxim-O.',
       20.00
FROM drug_master d1, drug_master d2
WHERE d1.brand_name = 'Taxim-O 200'
  AND d2.brand_name = 'Cefix 200'
ON CONFLICT (drug_master_id, substitute_drug_master_id) DO NOTHING;

INSERT INTO generic_substitution (drug_master_id, substitute_drug_master_id, reason, estimated_savings)
SELECT d1.id, d2.id,
       'Same active ingredient (Cefixime 200mg). Taxim-O may be substituted for Cefix 200.',
       20.00
FROM drug_master d1, drug_master d2
WHERE d1.brand_name = 'Cefix 200'
  AND d2.brand_name = 'Taxim-O 200'
ON CONFLICT (drug_master_id, substitute_drug_master_id) DO NOTHING;
