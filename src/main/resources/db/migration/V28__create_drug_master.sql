-- Salt master: platform-level reference table (no org scoping)
CREATE TABLE salt_master (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       VARCHAR(255) NOT NULL UNIQUE,
    category   VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Drug master: platform-level reference table (no org scoping)
CREATE TABLE drug_master (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_name            VARCHAR(255) NOT NULL,
    generic_name          VARCHAR(255),
    salt_id               UUID REFERENCES salt_master(id),
    salt_composition      TEXT,
    manufacturer          VARCHAR(255),
    hsn_code              VARCHAR(10)    NOT NULL DEFAULT '3004',
    gst_rate              NUMERIC(5,2)   NOT NULL DEFAULT 12,
    drug_schedule         VARCHAR(20)    NOT NULL DEFAULT 'GENERAL',
    dosage_form           VARCHAR(50),
    pack_size             VARCHAR(50),
    mrp                   NUMERIC(15,2),
    prescription_required BOOLEAN        NOT NULL DEFAULT FALSE,
    is_active             BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at            TIMESTAMP      NOT NULL DEFAULT NOW()
);

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_drug_master_brand_trgm ON drug_master USING gin(brand_name gin_trgm_ops);
CREATE INDEX idx_drug_master_salt       ON drug_master(salt_id);
CREATE INDEX idx_salt_master_name_trgm  ON salt_master USING gin(name gin_trgm_ops);
CREATE INDEX idx_drug_master_active     ON drug_master(is_active) WHERE is_active = TRUE;

-- ============================================================
-- SALT MASTER SEED DATA
-- ============================================================
INSERT INTO salt_master (name, category) VALUES
('Paracetamol','Analgesic/Antipyretic'),
('Ibuprofen','NSAID'),
('Diclofenac','NSAID'),
('Aceclofenac','NSAID'),
('Nimesulide','NSAID'),
('Mefenamic Acid','NSAID'),
('Aspirin','Antiplatelet/NSAID'),
('Tramadol','Opioid Analgesic'),
('Ketorolac','NSAID'),
('Amoxicillin','Antibiotic - Penicillin'),
('Amoxicillin + Clavulanic Acid','Antibiotic - Beta-Lactam'),
('Ampicillin','Antibiotic - Penicillin'),
('Azithromycin','Antibiotic - Macrolide'),
('Erythromycin','Antibiotic - Macrolide'),
('Clarithromycin','Antibiotic - Macrolide'),
('Clindamycin','Antibiotic - Lincosamide'),
('Ciprofloxacin','Antibiotic - Fluoroquinolone'),
('Ofloxacin','Antibiotic - Fluoroquinolone'),
('Norfloxacin','Antibiotic - Fluoroquinolone'),
('Levofloxacin','Antibiotic - Fluoroquinolone'),
('Moxifloxacin','Antibiotic - Fluoroquinolone'),
('Doxycycline','Antibiotic - Tetracycline'),
('Cefixime','Antibiotic - Cephalosporin'),
('Cefpodoxime','Antibiotic - Cephalosporin'),
('Metronidazole','Antibiotic - Nitroimidazole'),
('Tinidazole','Antibiotic - Nitroimidazole'),
('Fluconazole','Antifungal'),
('Terbinafine','Antifungal'),
('Itraconazole','Antifungal'),
('Albendazole','Anthelmintic'),
('Mebendazole','Anthelmintic'),
('Cetirizine','Antihistamine'),
('Levocetirizine','Antihistamine'),
('Loratadine','Antihistamine'),
('Chlorpheniramine','Antihistamine'),
('Fexofenadine','Antihistamine'),
('Montelukast','Leukotriene Antagonist'),
('Salbutamol','Bronchodilator'),
('Theophylline','Bronchodilator'),
('Ambroxol','Mucolytic'),
('Bromhexine','Mucolytic'),
('Dextromethorphan','Antitussive'),
('N-Acetylcysteine','Mucolytic'),
('Budesonide','Corticosteroid - Inhaled'),
('Pantoprazole','Proton Pump Inhibitor'),
('Omeprazole','Proton Pump Inhibitor'),
('Rabeprazole','Proton Pump Inhibitor'),
('Esomeprazole','Proton Pump Inhibitor'),
('Ranitidine','H2 Blocker'),
('Domperidone','Prokinetic'),
('Ondansetron','Antiemetic'),
('Metoclopramide','Antiemetic/Prokinetic'),
('Metformin','Antidiabetic - Biguanide'),
('Glibenclamide','Antidiabetic - Sulfonylurea'),
('Glipizide','Antidiabetic - Sulfonylurea'),
('Glimepiride','Antidiabetic - Sulfonylurea'),
('Pioglitazone','Antidiabetic - Thiazolidinedione'),
('Voglibose','Antidiabetic - Alpha-glucosidase inhibitor'),
('Sitagliptin','Antidiabetic - DPP-4 inhibitor'),
('Amlodipine','Antihypertensive - CCB'),
('Nifedipine','Antihypertensive - CCB'),
('Atenolol','Antihypertensive - Beta Blocker'),
('Metoprolol','Antihypertensive - Beta Blocker'),
('Bisoprolol','Antihypertensive - Beta Blocker'),
('Propranolol','Antihypertensive - Beta Blocker'),
('Losartan','Antihypertensive - ARB'),
('Telmisartan','Antihypertensive - ARB'),
('Olmesartan','Antihypertensive - ARB'),
('Ramipril','Antihypertensive - ACE Inhibitor'),
('Lisinopril','Antihypertensive - ACE Inhibitor'),
('Enalapril','Antihypertensive - ACE Inhibitor'),
('Furosemide','Diuretic'),
('Hydrochlorothiazide','Diuretic'),
('Spironolactone','Diuretic - Potassium Sparing'),
('Atorvastatin','Statin'),
('Rosuvastatin','Statin'),
('Simvastatin','Statin'),
('Clopidogrel','Antiplatelet'),
('Levothyroxine','Thyroid Hormone'),
('Prednisolone','Corticosteroid'),
('Dexamethasone','Corticosteroid'),
('Methylprednisolone','Corticosteroid'),
('Sertraline','Antidepressant - SSRI'),
('Escitalopram','Antidepressant - SSRI'),
('Fluoxetine','Antidepressant - SSRI'),
('Amitriptyline','Antidepressant - TCA'),
('Alprazolam','Anxiolytic - Benzodiazepine'),
('Clonazepam','Anticonvulsant/Anxiolytic'),
('Diazepam','Anxiolytic - Benzodiazepine'),
('Gabapentin','Anticonvulsant/Neuropathic'),
('Pregabalin','Anticonvulsant/Neuropathic'),
('Levetiracetam','Anticonvulsant'),
('Phenytoin','Anticonvulsant'),
('Carbamazepine','Anticonvulsant/Mood Stabilizer'),
('Vitamin D3 (Cholecalciferol)','Vitamin'),
('Methylcobalamin','Vitamin B12'),
('Pyridoxine (Vitamin B6)','Vitamin'),
('Folic Acid','Vitamin'),
('Ferrous Sulphate + Folic Acid','Iron Supplement'),
('Calcium Carbonate + Vitamin D3','Calcium Supplement'),
('Zinc Sulphate','Mineral'),
('Ascorbic Acid','Vitamin C'),
('Multivitamin + Multimineral','Nutritional Supplement'),
('Isoniazid','Anti-TB'),
('Rifampicin','Anti-TB'),
('Pyrazinamide','Anti-TB'),
('Ethambutol','Anti-TB'),
('Doxylamine + Pyridoxine','Antiemetic - Pregnancy'),
('Betahistine','Vestibular disorders'),
('Acyclovir','Antiviral'),
('Oseltamivir','Antiviral');

-- ============================================================
-- DRUG MASTER SEED DATA (200+ brands)
-- ============================================================

-- PARACETAMOL group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Crocin 500','Paracetamol 500mg',(SELECT id FROM salt_master WHERE name='Paracetamol'),'Paracetamol 500mg','GSK',                    '3004',12,'GENERAL',       'Tablet',    '20 Tab',    28.00, false),
('Dolo 650',  'Paracetamol 650mg',(SELECT id FROM salt_master WHERE name='Paracetamol'),'Paracetamol 650mg','Micro Labs',             '3004',12,'GENERAL',       'Tablet',    '15 Tab',    30.00, false),
('Calpol 500','Paracetamol 500mg',(SELECT id FROM salt_master WHERE name='Paracetamol'),'Paracetamol 500mg','GSK',                    '3004',12,'GENERAL',       'Tablet',    '15 Tab',    19.00, false),
('Pyrigesic','Paracetamol 500mg', (SELECT id FROM salt_master WHERE name='Paracetamol'),'Paracetamol 500mg','East India',             '3004',12,'GENERAL',       'Tablet',    '10 Tab',    14.00, false),
('Pacimol 500','Paracetamol 500mg',(SELECT id FROM salt_master WHERE name='Paracetamol'),'Paracetamol 500mg','Ipca Labs',             '3004',12,'GENERAL',       'Tablet',    '10 Tab',    12.00, false),
('Crocin 250 Syrup','Paracetamol 250mg/5ml',(SELECT id FROM salt_master WHERE name='Paracetamol'),'Paracetamol 250mg/5ml','GSK',     '3004',12,'GENERAL',       'Syrup',     '60ml',      50.00, false),
('Febrex Plus','Paracetamol+Chlorpheniramine+Phenylephrine',(SELECT id FROM salt_master WHERE name='Paracetamol'),'Paracetamol 325mg + Chlorpheniramine 2mg + Phenylephrine 5mg','Ipca','3004',12,'GENERAL','Tablet','10 Tab',30.00, false);

-- IBUPROFEN group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Brufen 400','Ibuprofen 400mg',   (SELECT id FROM salt_master WHERE name='Ibuprofen'),'Ibuprofen 400mg','Abbott',                    '3004',12,'SCHEDULE_H',    'Tablet',    '15 Tab',    35.00, true),
('Combiflam','Ibuprofen+Paracetamol',(SELECT id FROM salt_master WHERE name='Ibuprofen'),'Ibuprofen 400mg + Paracetamol 325mg','Sanofi','3004',12,'GENERAL',     'Tablet',    '20 Tab',    42.00, false),
('Ibugesic 400','Ibuprofen 400mg', (SELECT id FROM salt_master WHERE name='Ibuprofen'),'Ibuprofen 400mg','Cipla',                     '3004',12,'SCHEDULE_H',    'Tablet',    '15 Tab',    30.00, true),
('Advil 200','Ibuprofen 200mg',    (SELECT id FROM salt_master WHERE name='Ibuprofen'),'Ibuprofen 200mg','Pfizer',                    '3004',12,'GENERAL',       'Tablet',    '10 Tab',    25.00, false);

-- DICLOFENAC group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Voveran 50','Diclofenac 50mg',   (SELECT id FROM salt_master WHERE name='Diclofenac'),'Diclofenac Sodium 50mg','Novartis',          '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    25.00, true),
('Voveran SR 100','Diclofenac 100mg SR',(SELECT id FROM salt_master WHERE name='Diclofenac'),'Diclofenac Sodium 100mg SR','Novartis', '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    45.00, true),
('Voltaren Gel','Diclofenac 1% Gel',(SELECT id FROM salt_master WHERE name='Diclofenac'),'Diclofenac Diethylamine 1.16%','Novartis', '3004',12,'GENERAL',       'Gel',       '30g',       90.00, false),
('Diclogesic','Diclofenac 50mg',   (SELECT id FROM salt_master WHERE name='Diclofenac'),'Diclofenac Sodium 50mg','Cipla',             '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    20.00, true);

-- ACECLOFENAC group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Zerodol-P','Aceclofenac+Paracetamol',(SELECT id FROM salt_master WHERE name='Aceclofenac'),'Aceclofenac 100mg + Paracetamol 500mg','Ipca', '3004',12,'SCHEDULE_H','Tablet','10 Tab', 55.00, true),
('Hifenac P','Aceclofenac+Paracetamol',(SELECT id FROM salt_master WHERE name='Aceclofenac'),'Aceclofenac 100mg + Paracetamol 500mg','Intas','3004',12,'SCHEDULE_H','Tablet','10 Tab', 52.00, true),
('Aceclo Plus','Aceclofenac+Paracetamol',(SELECT id FROM salt_master WHERE name='Aceclofenac'),'Aceclofenac 100mg + Paracetamol 325mg','FDC','3004',12,'SCHEDULE_H','Tablet','10 Tab', 42.00, true),
('Zerodol SP','Aceclofenac+Serratiopeptidase',(SELECT id FROM salt_master WHERE name='Aceclofenac'),'Aceclofenac 100mg + Serratiopeptidase 15mg','Ipca','3004',12,'SCHEDULE_H','Tablet','10 Tab',80.00, true);

-- NIMESULIDE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Nimulid 100','Nimesulide 100mg', (SELECT id FROM salt_master WHERE name='Nimesulide'),'Nimesulide 100mg','Panacea Biotec',         '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    22.00, true),
('Nice 100',   'Nimesulide 100mg', (SELECT id FROM salt_master WHERE name='Nimesulide'),'Nimesulide 100mg','Abbott',                 '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    20.00, true);

-- ASPIRIN group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Disprin 325','Aspirin 325mg',    (SELECT id FROM salt_master WHERE name='Aspirin'),'Aspirin 325mg','Reckitt',                      '3004',12,'GENERAL',       'Tablet',    '10 Tab',    14.00, false),
('Ecosprin 75','Aspirin 75mg',     (SELECT id FROM salt_master WHERE name='Aspirin'),'Aspirin 75mg (Enteric Coated)','USV',          '3004',12,'SCHEDULE_H',    'Tablet',    '14 Tab',    16.00, true),
('Ecosprin 150','Aspirin 150mg',   (SELECT id FROM salt_master WHERE name='Aspirin'),'Aspirin 150mg (Enteric Coated)','USV',         '3004',12,'SCHEDULE_H',    'Tablet',    '14 Tab',    20.00, true);

-- AMOXICILLIN group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Mox 500',    'Amoxicillin 500mg',(SELECT id FROM salt_master WHERE name='Amoxicillin'),'Amoxicillin 500mg','Cipla',               '3004',12,'SCHEDULE_H',    'Capsule',   '10 Cap',    50.00, true),
('Novamox 500','Amoxicillin 500mg',(SELECT id FROM salt_master WHERE name='Amoxicillin'),'Amoxicillin 500mg','Cipla',               '3004',12,'SCHEDULE_H',    'Capsule',   '10 Cap',    48.00, true),
('Amoxil 250', 'Amoxicillin 250mg',(SELECT id FROM salt_master WHERE name='Amoxicillin'),'Amoxicillin 250mg','GSK',                 '3004',12,'SCHEDULE_H',    'Capsule',   '10 Cap',    35.00, true);

-- AMOXICILLIN + CLAVULANIC ACID group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Augmentin 625','Amoxicillin+Clavulanate 625mg',(SELECT id FROM salt_master WHERE name='Amoxicillin + Clavulanic Acid'),'Amoxicillin 500mg + Clavulanic Acid 125mg','GSK','3004',12,'SCHEDULE_H','Tablet','6 Tab',180.00, true),
('Clavam 625',   'Amoxicillin+Clavulanate 625mg',(SELECT id FROM salt_master WHERE name='Amoxicillin + Clavulanic Acid'),'Amoxicillin 500mg + Clavulanic Acid 125mg','Alkem','3004',12,'SCHEDULE_H','Tablet','6 Tab',165.00, true),
('Moxclav 625',  'Amoxicillin+Clavulanate 625mg',(SELECT id FROM salt_master WHERE name='Amoxicillin + Clavulanic Acid'),'Amoxicillin 500mg + Clavulanic Acid 125mg','FDC','3004',12,'SCHEDULE_H','Tablet','6 Tab',155.00, true);

-- AZITHROMYCIN group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Azee 500',     'Azithromycin 500mg',(SELECT id FROM salt_master WHERE name='Azithromycin'),'Azithromycin 500mg','Cipla',           '3004',12,'SCHEDULE_H',    'Tablet',    '3 Tab',     75.00, true),
('Azithral 500', 'Azithromycin 500mg',(SELECT id FROM salt_master WHERE name='Azithromycin'),'Azithromycin 500mg','Alembic',        '3004',12,'SCHEDULE_H',    'Tablet',    '3 Tab',     70.00, true),
('Zithromax 250','Azithromycin 250mg',(SELECT id FROM salt_master WHERE name='Azithromycin'),'Azithromycin 250mg','Pfizer',         '3004',12,'SCHEDULE_H',    'Tablet',    '5 Tab',     110.00, true),
('Zady 500',     'Azithromycin 500mg',(SELECT id FROM salt_master WHERE name='Azithromycin'),'Azithromycin 500mg','Cadila',         '3004',12,'SCHEDULE_H',    'Tablet',    '3 Tab',     68.00, true);

-- CIPROFLOXACIN group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Ciplox 500',  'Ciprofloxacin 500mg',(SELECT id FROM salt_master WHERE name='Ciprofloxacin'),'Ciprofloxacin 500mg','Cipla',        '3004',12,'SCHEDULE_H1',   'Tablet',    '10 Tab',    45.00, true),
('Cifran 500',  'Ciprofloxacin 500mg',(SELECT id FROM salt_master WHERE name='Ciprofloxacin'),'Ciprofloxacin 500mg','Ranbaxy',      '3004',12,'SCHEDULE_H1',   'Tablet',    '10 Tab',    42.00, true),
('Ciprobid 500','Ciprofloxacin 500mg',(SELECT id FROM salt_master WHERE name='Ciprofloxacin'),'Ciprofloxacin 500mg','Cadila',       '3004',12,'SCHEDULE_H1',   'Tablet',    '10 Tab',    40.00, true),
('Quinflox 500','Ciprofloxacin 500mg',(SELECT id FROM salt_master WHERE name='Ciprofloxacin'),'Ciprofloxacin 500mg','Mankind',      '3004',12,'SCHEDULE_H1',   'Tablet',    '10 Tab',    38.00, true);

-- LEVOFLOXACIN group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Levoflox 500','Levofloxacin 500mg',(SELECT id FROM salt_master WHERE name='Levofloxacin'),'Levofloxacin 500mg','Cipla',           '3004',12,'SCHEDULE_H1',   'Tablet',    '5 Tab',     85.00, true),
('Levaquin 500','Levofloxacin 500mg',(SELECT id FROM salt_master WHERE name='Levofloxacin'),'Levofloxacin 500mg','Janssen',         '3004',12,'SCHEDULE_H1',   'Tablet',    '5 Tab',     90.00, true),
('Tavanic 500', 'Levofloxacin 500mg',(SELECT id FROM salt_master WHERE name='Levofloxacin'),'Levofloxacin 500mg','Sanofi',          '3004',12,'SCHEDULE_H1',   'Tablet',    '5 Tab',     95.00, true);

-- DOXYCYCLINE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Doxin 100',   'Doxycycline 100mg',(SELECT id FROM salt_master WHERE name='Doxycycline'),'Doxycycline 100mg','Cipla',              '3004',12,'SCHEDULE_H',    'Capsule',   '10 Cap',    30.00, true),
('Biodoxi 100', 'Doxycycline 100mg',(SELECT id FROM salt_master WHERE name='Doxycycline'),'Doxycycline 100mg','Elder',              '3004',12,'SCHEDULE_H',    'Capsule',   '10 Cap',    28.00, true);

-- CEFIXIME group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Taxim-O 200', 'Cefixime 200mg',  (SELECT id FROM salt_master WHERE name='Cefixime'),'Cefixime 200mg','Alkem',                    '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    115.00, true),
('Suprax 200',  'Cefixime 200mg',  (SELECT id FROM salt_master WHERE name='Cefixime'),'Cefixime 200mg','Pfizer',                   '3004',12,'SCHEDULE_H',    'Tablet',    '6 Tab',     95.00, true),
('Zifi 200',    'Cefixime 200mg',  (SELECT id FROM salt_master WHERE name='Cefixime'),'Cefixime 200mg','FDC',                      '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    108.00, true);

-- METRONIDAZOLE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Flagyl 400',  'Metronidazole 400mg',(SELECT id FROM salt_master WHERE name='Metronidazole'),'Metronidazole 400mg','Pfizer',       '3004',12,'SCHEDULE_H',    'Tablet',    '15 Tab',    30.00, true),
('Metrogyl 400','Metronidazole 400mg',(SELECT id FROM salt_master WHERE name='Metronidazole'),'Metronidazole 400mg','JB Chemicals', '3004',12,'SCHEDULE_H',    'Tablet',    '15 Tab',    28.00, true);

-- FLUCONAZOLE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Flucos 150',  'Fluconazole 150mg',(SELECT id FROM salt_master WHERE name='Fluconazole'),'Fluconazole 150mg','Cipla',              '3004',12,'SCHEDULE_H',    'Capsule',   '1 Cap',     30.00, true),
('Forcan 150',  'Fluconazole 150mg',(SELECT id FROM salt_master WHERE name='Fluconazole'),'Fluconazole 150mg','Cipla',              '3004',12,'SCHEDULE_H',    'Capsule',   '1 Cap',     28.00, true);

-- CETIRIZINE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Zyrtec 10',   'Cetirizine 10mg', (SELECT id FROM salt_master WHERE name='Cetirizine'),'Cetirizine 10mg','UCB',                   '3004',12,'GENERAL',       'Tablet',    '7 Tab',     38.00, false),
('Okacet 10',   'Cetirizine 10mg', (SELECT id FROM salt_master WHERE name='Cetirizine'),'Cetirizine 10mg','Cipla',                 '3004',12,'GENERAL',       'Tablet',    '10 Tab',    22.00, false),
('Cetcip 10',   'Cetirizine 10mg', (SELECT id FROM salt_master WHERE name='Cetirizine'),'Cetirizine 10mg','Cipla',                 '3004',12,'GENERAL',       'Tablet',    '10 Tab',    20.00, false),
('Alerid 10',   'Cetirizine 10mg', (SELECT id FROM salt_master WHERE name='Cetirizine'),'Cetirizine 10mg','Cipla',                 '3004',12,'GENERAL',       'Tablet',    '15 Tab',    30.00, false);

-- LEVOCETIRIZINE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Xyzal 5',     'Levocetirizine 5mg',(SELECT id FROM salt_master WHERE name='Levocetirizine'),'Levocetirizine 5mg','UCB',           '3004',12,'GENERAL',       'Tablet',    '10 Tab',    55.00, false),
('L-Cin 5',     'Levocetirizine 5mg',(SELECT id FROM salt_master WHERE name='Levocetirizine'),'Levocetirizine 5mg','Alkem',         '3004',12,'GENERAL',       'Tablet',    '10 Tab',    32.00, false),
('Levocet 5',   'Levocetirizine 5mg',(SELECT id FROM salt_master WHERE name='Levocetirizine'),'Levocetirizine 5mg','Cipla',         '3004',12,'GENERAL',       'Tablet',    '10 Tab',    30.00, false);

-- MONTELUKAST group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Montair 10',  'Montelukast 10mg',(SELECT id FROM salt_master WHERE name='Montelukast'),'Montelukast 10mg','Cipla',                '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    90.00, true),
('Singulair 10','Montelukast 10mg',(SELECT id FROM salt_master WHERE name='Montelukast'),'Montelukast 10mg','MSD',                  '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    125.00, true),
('Montair LC',  'Montelukast+Levocetirizine',(SELECT id FROM salt_master WHERE name='Montelukast'),'Montelukast 10mg + Levocetirizine 5mg','Cipla','3004',12,'SCHEDULE_H','Tablet','10 Tab',120.00, true),
('Aimont 10',   'Montelukast 10mg',(SELECT id FROM salt_master WHERE name='Montelukast'),'Montelukast 10mg','Mankind',              '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    75.00, true);

-- PANTOPRAZOLE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Pan 40',      'Pantoprazole 40mg',(SELECT id FROM salt_master WHERE name='Pantoprazole'),'Pantoprazole 40mg','Alkem',             '3004',12,'SCHEDULE_H',    'Tablet',    '15 Tab',    65.00, true),
('Pantocid 40', 'Pantoprazole 40mg',(SELECT id FROM salt_master WHERE name='Pantoprazole'),'Pantoprazole 40mg','Sun Pharma',       '3004',12,'SCHEDULE_H',    'Tablet',    '15 Tab',    70.00, true),
('Pantocar 40', 'Pantoprazole 40mg',(SELECT id FROM salt_master WHERE name='Pantoprazole'),'Pantoprazole 40mg','JB Chemicals',     '3004',12,'SCHEDULE_H',    'Tablet',    '15 Tab',    60.00, true),
('Pan D',       'Pantoprazole+Domperidone',(SELECT id FROM salt_master WHERE name='Pantoprazole'),'Pantoprazole 40mg + Domperidone 10mg','Alkem','3004',12,'SCHEDULE_H','Capsule','15 Cap',95.00, true),
('Nexpro 40',   'Esomeprazole 40mg',(SELECT id FROM salt_master WHERE name='Esomeprazole'),'Esomeprazole 40mg','Torrent',          '3004',12,'SCHEDULE_H',    'Tablet',    '14 Tab',    85.00, true);

-- OMEPRAZOLE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Omez 20',     'Omeprazole 20mg', (SELECT id FROM salt_master WHERE name='Omeprazole'),'Omeprazole 20mg','Dr Reddy''s',            '3004',12,'SCHEDULE_H',    'Capsule',   '15 Cap',    55.00, true),
('Ocid 20',     'Omeprazole 20mg', (SELECT id FROM salt_master WHERE name='Omeprazole'),'Omeprazole 20mg','Cipla',                  '3004',12,'SCHEDULE_H',    'Capsule',   '15 Cap',    50.00, true);

-- RABEPRAZOLE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Razo 20',     'Rabeprazole 20mg',(SELECT id FROM salt_master WHERE name='Rabeprazole'),'Rabeprazole 20mg','Dr Reddy''s',          '3004',12,'SCHEDULE_H',    'Tablet',    '15 Tab',    75.00, true),
('Rabemac 20',  'Rabeprazole 20mg',(SELECT id FROM salt_master WHERE name='Rabeprazole'),'Rabeprazole 20mg','Macleods',             '3004',12,'SCHEDULE_H',    'Tablet',    '15 Tab',    70.00, true);

-- DOMPERIDONE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Domstal 10',  'Domperidone 10mg',(SELECT id FROM salt_master WHERE name='Domperidone'),'Domperidone 10mg','Torrent',              '3004',12,'SCHEDULE_H',    'Tablet',    '30 Tab',    42.00, true),
('Vomistop 10', 'Domperidone 10mg',(SELECT id FROM salt_master WHERE name='Domperidone'),'Domperidone 10mg','Cipla',                '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    18.00, true);

-- ONDANSETRON group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Emeset 4',    'Ondansetron 4mg', (SELECT id FROM salt_master WHERE name='Ondansetron'),'Ondansetron 4mg','Cipla',                 '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    48.00, true),
('Zofran 4',    'Ondansetron 4mg', (SELECT id FROM salt_master WHERE name='Ondansetron'),'Ondansetron 4mg','GSK',                   '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    55.00, true),
('Ondem 4',     'Ondansetron 4mg', (SELECT id FROM salt_master WHERE name='Ondansetron'),'Ondansetron 4mg','Alkem',                 '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    45.00, true);

-- METFORMIN group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Glycomet 500','Metformin 500mg', (SELECT id FROM salt_master WHERE name='Metformin'),'Metformin 500mg','USV',                     '3004',12,'SCHEDULE_H',    'Tablet',    '20 Tab',    25.00, true),
('Glucophage 500','Metformin 500mg',(SELECT id FROM salt_master WHERE name='Metformin'),'Metformin 500mg','Merck',                  '3004',12,'SCHEDULE_H',    'Tablet',    '20 Tab',    30.00, true),
('Glycomet SR 500','Metformin SR 500mg',(SELECT id FROM salt_master WHERE name='Metformin'),'Metformin 500mg SR','USV',              '3004',12,'SCHEDULE_H',    'Tablet',    '20 Tab',    35.00, true),
('Obimet 500',  'Metformin 500mg', (SELECT id FROM salt_master WHERE name='Metformin'),'Metformin 500mg','Aristo',                  '3004',12,'SCHEDULE_H',    'Tablet',    '20 Tab',    22.00, true),
('Walaphage 1g','Metformin 1000mg',(SELECT id FROM salt_master WHERE name='Metformin'),'Metformin 1000mg','Sun Pharma',             '3004',12,'SCHEDULE_H',    'Tablet',    '30 Tab',    65.00, true);

-- GLIMEPIRIDE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Amaryl 2',    'Glimepiride 2mg', (SELECT id FROM salt_master WHERE name='Glimepiride'),'Glimepiride 2mg','Sanofi',               '3004',12,'SCHEDULE_H',    'Tablet',    '15 Tab',    85.00, true),
('Glimestar 2', 'Glimepiride 2mg', (SELECT id FROM salt_master WHERE name='Glimepiride'),'Glimepiride 2mg','Mankind',              '3004',12,'SCHEDULE_H',    'Tablet',    '15 Tab',    65.00, true),
('Zoryl 2',     'Glimepiride 2mg', (SELECT id FROM salt_master WHERE name='Glimepiride'),'Glimepiride 2mg','Intas',                '3004',12,'SCHEDULE_H',    'Tablet',    '15 Tab',    70.00, true);

-- SITAGLIPTIN group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Januvia 100', 'Sitagliptin 100mg',(SELECT id FROM salt_master WHERE name='Sitagliptin'),'Sitagliptin 100mg','MSD',              '3004',12,'SCHEDULE_H',    'Tablet',    '14 Tab',    430.00, true),
('Istavel 100', 'Sitagliptin 100mg',(SELECT id FROM salt_master WHERE name='Sitagliptin'),'Sitagliptin 100mg','Sun Pharma',       '3004',12,'SCHEDULE_H',    'Tablet',    '14 Tab',    280.00, true);

-- AMLODIPINE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Amlovas 5',   'Amlodipine 5mg',  (SELECT id FROM salt_master WHERE name='Amlodipine'),'Amlodipine 5mg','Macleods',               '3004',12,'SCHEDULE_H',    'Tablet',    '30 Tab',    35.00, true),
('Stamlo 5',    'Amlodipine 5mg',  (SELECT id FROM salt_master WHERE name='Amlodipine'),'Amlodipine 5mg','Dr Reddy''s',             '3004',12,'SCHEDULE_H',    'Tablet',    '30 Tab',    38.00, true),
('Amlodac 5',   'Amlodipine 5mg',  (SELECT id FROM salt_master WHERE name='Amlodipine'),'Amlodipine 5mg','Cadila',                  '3004',12,'SCHEDULE_H',    'Tablet',    '30 Tab',    33.00, true),
('Norvasc 5',   'Amlodipine 5mg',  (SELECT id FROM salt_master WHERE name='Amlodipine'),'Amlodipine 5mg','Pfizer',                  '3004',12,'SCHEDULE_H',    'Tablet',    '30 Tab',    55.00, true),
('Amlovas 10',  'Amlodipine 10mg', (SELECT id FROM salt_master WHERE name='Amlodipine'),'Amlodipine 10mg','Macleods',               '3004',12,'SCHEDULE_H',    'Tablet',    '30 Tab',    55.00, true);

-- ATENOLOL group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Tenormin 50', 'Atenolol 50mg',   (SELECT id FROM salt_master WHERE name='Atenolol'),'Atenolol 50mg','AstraZeneca',               '3004',12,'SCHEDULE_H',    'Tablet',    '14 Tab',    45.00, true),
('Betacard 50', 'Atenolol 50mg',   (SELECT id FROM salt_master WHERE name='Atenolol'),'Atenolol 50mg','Torrent',                   '3004',12,'SCHEDULE_H',    'Tablet',    '14 Tab',    35.00, true),
('Aten 50',     'Atenolol 50mg',   (SELECT id FROM salt_master WHERE name='Atenolol'),'Atenolol 50mg','IPCA',                      '3004',12,'SCHEDULE_H',    'Tablet',    '14 Tab',    30.00, true);

-- METOPROLOL group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Lopressor 50','Metoprolol 50mg', (SELECT id FROM salt_master WHERE name='Metoprolol'),'Metoprolol 50mg','Novartis',               '3004',12,'SCHEDULE_H',    'Tablet',    '20 Tab',    55.00, true),
('Seloken 50',  'Metoprolol 50mg', (SELECT id FROM salt_master WHERE name='Metoprolol'),'Metoprolol Tartrate 50mg','AstraZeneca',  '3004',12,'SCHEDULE_H',    'Tablet',    '20 Tab',    60.00, true),
('Metolar 25',  'Metoprolol 25mg', (SELECT id FROM salt_master WHERE name='Metoprolol'),'Metoprolol Succinate 25mg','Cipla',        '3004',12,'SCHEDULE_H',    'Tablet',    '14 Tab',    42.00, true);

-- TELMISARTAN group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Telmikind 40','Telmisartan 40mg',(SELECT id FROM salt_master WHERE name='Telmisartan'),'Telmisartan 40mg','Mankind',               '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    45.00, true),
('Telma 40',    'Telmisartan 40mg',(SELECT id FROM salt_master WHERE name='Telmisartan'),'Telmisartan 40mg','Glenmark',              '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    52.00, true),
('Telsartan 40','Telmisartan 40mg',(SELECT id FROM salt_master WHERE name='Telmisartan'),'Telmisartan 40mg','Dr Reddy''s',           '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    48.00, true),
('Telmikind H', 'Telmisartan+HCTZ',(SELECT id FROM salt_master WHERE name='Telmisartan'),'Telmisartan 40mg + Hydrochlorothiazide 12.5mg','Mankind','3004',12,'SCHEDULE_H','Tablet','10 Tab',65.00, true);

-- LOSARTAN group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Cozaar 50',   'Losartan 50mg',   (SELECT id FROM salt_master WHERE name='Losartan'),'Losartan Potassium 50mg','MSD',               '3004',12,'SCHEDULE_H',    'Tablet',    '14 Tab',    80.00, true),
('Repace 50',   'Losartan 50mg',   (SELECT id FROM salt_master WHERE name='Losartan'),'Losartan Potassium 50mg','Sun Pharma',        '3004',12,'SCHEDULE_H',    'Tablet',    '14 Tab',    55.00, true);

-- RAMIPRIL group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Cardace 5',   'Ramipril 5mg',    (SELECT id FROM salt_master WHERE name='Ramipril'),'Ramipril 5mg','Sanofi',                      '3004',12,'SCHEDULE_H',    'Capsule',   '10 Cap',    55.00, true),
('Ramace 2.5',  'Ramipril 2.5mg',  (SELECT id FROM salt_master WHERE name='Ramipril'),'Ramipril 2.5mg','Dr Reddy''s',               '3004',12,'SCHEDULE_H',    'Capsule',   '10 Cap',    40.00, true);

-- ATORVASTATIN group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Lipitor 10',  'Atorvastatin 10mg',(SELECT id FROM salt_master WHERE name='Atorvastatin'),'Atorvastatin 10mg','Pfizer',            '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    50.00, true),
('Atorva 10',   'Atorvastatin 10mg',(SELECT id FROM salt_master WHERE name='Atorvastatin'),'Atorvastatin 10mg','Cipla',             '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    38.00, true),
('Storvas 20',  'Atorvastatin 20mg',(SELECT id FROM salt_master WHERE name='Atorvastatin'),'Atorvastatin 20mg','Sun Pharma',        '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    68.00, true),
('Aztor 10',    'Atorvastatin 10mg',(SELECT id FROM salt_master WHERE name='Atorvastatin'),'Atorvastatin 10mg','Sun Pharma',        '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    35.00, true);

-- ROSUVASTATIN group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Crestor 10',  'Rosuvastatin 10mg',(SELECT id FROM salt_master WHERE name='Rosuvastatin'),'Rosuvastatin 10mg','AstraZeneca',       '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    95.00, true),
('Rosucad 10',  'Rosuvastatin 10mg',(SELECT id FROM salt_master WHERE name='Rosuvastatin'),'Rosuvastatin 10mg','Cadila',            '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    65.00, true),
('Rosuvas 10',  'Rosuvastatin 10mg',(SELECT id FROM salt_master WHERE name='Rosuvastatin'),'Rosuvastatin 10mg','Sun Pharma',        '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    70.00, true);

-- CLOPIDOGREL group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Plavix 75',   'Clopidogrel 75mg',(SELECT id FROM salt_master WHERE name='Clopidogrel'),'Clopidogrel 75mg','Sanofi',               '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    95.00, true),
('Clopivas 75', 'Clopidogrel 75mg',(SELECT id FROM salt_master WHERE name='Clopidogrel'),'Clopidogrel 75mg','Cipla',                '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    70.00, true);

-- FUROSEMIDE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Lasix 40',    'Furosemide 40mg', (SELECT id FROM salt_master WHERE name='Furosemide'),'Furosemide 40mg','Sanofi',                 '3004',12,'SCHEDULE_H',    'Tablet',    '15 Tab',    22.00, true),
('Frusemide 40','Furosemide 40mg', (SELECT id FROM salt_master WHERE name='Furosemide'),'Furosemide 40mg','Ranbaxy',                '3004',12,'SCHEDULE_H',    'Tablet',    '15 Tab',    18.00, true);

-- LEVOTHYROXINE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Eltroxin 50', 'Levothyroxine 50mcg',(SELECT id FROM salt_master WHERE name='Levothyroxine'),'Levothyroxine 50mcg','GSK',         '3004',12,'SCHEDULE_H',    'Tablet',    '100 Tab',   68.00, true),
('Thyronorm 50','Levothyroxine 50mcg',(SELECT id FROM salt_master WHERE name='Levothyroxine'),'Levothyroxine 50mcg','Abbott',       '3004',12,'SCHEDULE_H',    'Tablet',    '90 Tab',    85.00, true),
('Thyronorm 100','Levothyroxine 100mcg',(SELECT id FROM salt_master WHERE name='Levothyroxine'),'Levothyroxine 100mcg','Abbott',    '3004',12,'SCHEDULE_H',    'Tablet',    '90 Tab',    92.00, true);

-- PREDNISOLONE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Wysolone 5',  'Prednisolone 5mg','(SELECT id FROM salt_master WHERE name=''Prednisolone'')','Prednisolone 5mg','Pfizer',          '3004',12,'SCHEDULE_H',    'Tablet',    '30 Tab',    28.00, true),
('Omnacortil 5','Prednisolone 5mg',(SELECT id FROM salt_master WHERE name='Prednisolone'),'Prednisolone 5mg','Franco-Indian',        '3004',12,'SCHEDULE_H',    'Tablet',    '30 Tab',    30.00, true),
('Omnacortil 10','Prednisolone 10mg',(SELECT id FROM salt_master WHERE name='Prednisolone'),'Prednisolone 10mg','Franco-Indian',    '3004',12,'SCHEDULE_H',    'Tablet',    '15 Tab',    38.00, true);

-- DEXAMETHASONE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Decadron 0.5','Dexamethasone 0.5mg',(SELECT id FROM salt_master WHERE name='Dexamethasone'),'Dexamethasone 0.5mg','MSD',         '3004',12,'SCHEDULE_H',    'Tablet',    '30 Tab',    25.00, true),
('Dexona 0.5',  'Dexamethasone 0.5mg',(SELECT id FROM salt_master WHERE name='Dexamethasone'),'Dexamethasone 0.5mg','Samarth',     '3004',12,'SCHEDULE_H',    'Tablet',    '30 Tab',    20.00, true);

-- SERTRALINE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Zoloft 50',   'Sertraline 50mg', (SELECT id FROM salt_master WHERE name='Sertraline'),'Sertraline 50mg','Pfizer',                 '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    95.00, true),
('Serlift 50',  'Sertraline 50mg', (SELECT id FROM salt_master WHERE name='Sertraline'),'Sertraline 50mg','Torrent',                '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    75.00, true),
('Daxid 50',    'Sertraline 50mg', (SELECT id FROM salt_master WHERE name='Sertraline'),'Sertraline 50mg','Pfizer',                 '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    88.00, true);

-- ESCITALOPRAM group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Nexito 10',   'Escitalopram 10mg',(SELECT id FROM salt_master WHERE name='Escitalopram'),'Escitalopram 10mg','Sun Pharma',        '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    85.00, true),
('Cipralex 10', 'Escitalopram 10mg',(SELECT id FROM salt_master WHERE name='Escitalopram'),'Escitalopram 10mg','Lundbeck',          '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    120.00, true),
('Stalopam 10', 'Escitalopram 10mg',(SELECT id FROM salt_master WHERE name='Escitalopram'),'Escitalopram 10mg','Intas',             '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    78.00, true);

-- ALPRAZOLAM group (Schedule X)
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Alprax 0.25', 'Alprazolam 0.25mg',(SELECT id FROM salt_master WHERE name='Alprazolam'),'Alprazolam 0.25mg','Torrent',            '3004',12,'SCHEDULE_X',    'Tablet',    '10 Tab',    18.00, true),
('Alprax 0.5',  'Alprazolam 0.5mg', (SELECT id FROM salt_master WHERE name='Alprazolam'),'Alprazolam 0.5mg','Torrent',             '3004',12,'SCHEDULE_X',    'Tablet',    '10 Tab',    22.00, true),
('Restyl 0.5',  'Alprazolam 0.5mg', (SELECT id FROM salt_master WHERE name='Alprazolam'),'Alprazolam 0.5mg','Sun Pharma',          '3004',12,'SCHEDULE_X',    'Tablet',    '10 Tab',    25.00, true);

-- CLONAZEPAM group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Rivotril 0.5','Clonazepam 0.5mg',(SELECT id FROM salt_master WHERE name='Clonazepam'),'Clonazepam 0.5mg','Roche',                '3004',12,'SCHEDULE_X',    'Tablet',    '15 Tab',    42.00, true),
('Clonafit 0.5','Clonazepam 0.5mg',(SELECT id FROM salt_master WHERE name='Clonazepam'),'Clonazepam 0.5mg','Sun Pharma',           '3004',12,'SCHEDULE_X',    'Tablet',    '15 Tab',    35.00, true);

-- GABAPENTIN group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Gabapin 300', 'Gabapentin 300mg',(SELECT id FROM salt_master WHERE name='Gabapentin'),'Gabapentin 300mg','Intas',                 '3004',12,'SCHEDULE_H',    'Capsule',   '10 Cap',    55.00, true),
('Neurontin 300','Gabapentin 300mg',(SELECT id FROM salt_master WHERE name='Gabapentin'),'Gabapentin 300mg','Pfizer',               '3004',12,'SCHEDULE_H',    'Capsule',   '10 Cap',    75.00, true);

-- PREGABALIN group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Lyrica 75',   'Pregabalin 75mg', (SELECT id FROM salt_master WHERE name='Pregabalin'),'Pregabalin 75mg','Pfizer',                 '3004',12,'SCHEDULE_H',    'Capsule',   '10 Cap',    145.00, true),
('Pregabalin 75','Pregabalin 75mg',(SELECT id FROM salt_master WHERE name='Pregabalin'),'Pregabalin 75mg','Torrent',                '3004',12,'SCHEDULE_H',    'Capsule',   '10 Cap',    95.00, true),
('Pregaba 75',  'Pregabalin 75mg', (SELECT id FROM salt_master WHERE name='Pregabalin'),'Pregabalin 75mg','Sun Pharma',             '3004',12,'SCHEDULE_H',    'Capsule',   '10 Cap',    90.00, true);

-- VITAMIN D3 group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Calcirol 60K','Cholecalciferol 60000 IU',(SELECT id FROM salt_master WHERE name='Vitamin D3 (Cholecalciferol)'),'Cholecalciferol 60000 IU','Cadila','3004',12,'GENERAL','Sachet','4 Sachets',85.00, false),
('Tayo 60K',    'Cholecalciferol 60000 IU',(SELECT id FROM salt_master WHERE name='Vitamin D3 (Cholecalciferol)'),'Cholecalciferol 60000 IU','Eris Lifesciences','3004',12,'GENERAL','Sachet','4 Sachets',72.00, false),
('D-Rise 60K',  'Cholecalciferol 60000 IU',(SELECT id FROM salt_master WHERE name='Vitamin D3 (Cholecalciferol)'),'Cholecalciferol 60000 IU','USV','3004',12,'GENERAL','Sachet','4 Sachets',78.00, false),
('Uprise D3',   'Cholecalciferol 60000 IU',(SELECT id FROM salt_master WHERE name='Vitamin D3 (Cholecalciferol)'),'Cholecalciferol 60000 IU','Alkem','2106',18,'GENERAL','Capsule','4 Cap',80.00, false);

-- METHYLCOBALAMIN group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Mecobal 500', 'Methylcobalamin 500mcg',(SELECT id FROM salt_master WHERE name='Methylcobalamin'),'Methylcobalamin 500mcg','Cadila','3004',12,'GENERAL','Tablet','10 Tab',45.00, false),
('Mecofol',     'Methylcobalamin+Folic Acid',(SELECT id FROM salt_master WHERE name='Methylcobalamin'),'Methylcobalamin 1500mcg + Folic Acid 5mg','Alkem','3004',12,'GENERAL','Tablet','10 Tab',55.00, false),
('Nervijen',    'Methylcobalamin+B6+B1',(SELECT id FROM salt_master WHERE name='Methylcobalamin'),'Methylcobalamin 1500mcg + Pyridoxine 100mg + Thiamine 10mg','Intas','3004',12,'GENERAL','Capsule','10 Cap',65.00, false),
('Neurobion Forte','B-Complex+B12',(SELECT id FROM salt_master WHERE name='Methylcobalamin'),'Methylcobalamin 1500mcg + B1 + B6 + B12 complex','Merck','2106',18,'GENERAL','Tablet','30 Tab',95.00, false);

-- IRON + FOLIC ACID group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Autrin','Ferrous Ascorbate+Folic Acid',(SELECT id FROM salt_master WHERE name='Ferrous Sulphate + Folic Acid'),'Ferrous Ascorbate 100mg + Folic Acid 1.5mg','Sun Pharma','3004',12,'GENERAL','Tablet','30 Tab',95.00, false),
('Orofer FC','Ferrous Ascorbate+Folic Acid',(SELECT id FROM salt_master WHERE name='Ferrous Sulphate + Folic Acid'),'Ferrous Ascorbate 100mg + Folic Acid 1.5mg','Emcure','3004',12,'GENERAL','Tablet','30 Tab',88.00, false),
('Xtraglo','Ferrous Bisglycinate+Folic Acid',(SELECT id FROM salt_master WHERE name='Ferrous Sulphate + Folic Acid'),'Ferrous Bisglycinate 30mg + Folic Acid 0.5mg','Macleods','3004',12,'GENERAL','Tablet','30 Tab',75.00, false);

-- CALCIUM group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Shelcal 500', 'Calcium+Vitamin D3',(SELECT id FROM salt_master WHERE name='Calcium Carbonate + Vitamin D3'),'Calcium Carbonate 500mg + Vitamin D3 250 IU','Elder','3004',12,'GENERAL','Tablet','15 Tab',88.00, false),
('Calcimax 500','Calcium+Vitamin D3',(SELECT id FROM salt_master WHERE name='Calcium Carbonate + Vitamin D3'),'Calcium Carbonate 500mg + Vitamin D3 250 IU','Meyer','3004',12,'GENERAL','Tablet','15 Tab',82.00, false),
('OstoCare',    'Calcium+Vitamin D3+Zinc',(SELECT id FROM salt_master WHERE name='Calcium Carbonate + Vitamin D3'),'Calcium 500mg + Vitamin D3 500 IU + Zinc','Elder','2106',18,'GENERAL','Tablet','30 Tab',148.00, false);

-- MULTIVITAMIN group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Supradyn',    'Multivitamin+Multimineral',(SELECT id FROM salt_master WHERE name='Multivitamin + Multimineral'),'Multivitamin + Multimineral complex','Bayer','2106',18,'GENERAL','Tablet','30 Tab',195.00, false),
('Becosules',   'Vitamin B-Complex+C',(SELECT id FROM salt_master WHERE name='Multivitamin + Multimineral'),'Vitamin B Complex + Ascorbic Acid 150mg','Pfizer','2106',18,'GENERAL','Capsule','20 Cap',85.00, false),
('Revital H',   'Multivitamin+Ginseng',(SELECT id FROM salt_master WHERE name='Multivitamin + Multimineral'),'Multivitamin + Ginseng extract','Ranbaxy','2106',18,'GENERAL','Capsule','30 Cap',295.00, false),
('Zincovit',    'Multivitamin+Zinc',(SELECT id FROM salt_master WHERE name='Multivitamin + Multimineral'),'Multivitamin + Zinc 10mg','Apex','2106',18,'GENERAL','Tablet','15 Tab',85.00, false);

-- SALBUTAMOL group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Asthalin 2mg','Salbutamol 2mg',  (SELECT id FROM salt_master WHERE name='Salbutamol'),'Salbutamol 2mg','Cipla',                   '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    15.00, true),
('Ventolin 2mg','Salbutamol 2mg',  (SELECT id FROM salt_master WHERE name='Salbutamol'),'Salbutamol 2mg','GSK',                     '3004',12,'SCHEDULE_H',    'Tablet',    '10 Tab',    18.00, true),
('Asthalin Inhaler','Salbutamol 100mcg/dose',(SELECT id FROM salt_master WHERE name='Salbutamol'),'Salbutamol 100mcg per actuation','Cipla','3004',12,'SCHEDULE_H','MDI Inhaler','200 doses',175.00, true),
('Ventolin Inhaler','Salbutamol 100mcg/dose',(SELECT id FROM salt_master WHERE name='Salbutamol'),'Salbutamol 100mcg per actuation','GSK','3004',12,'SCHEDULE_H','MDI Inhaler','200 doses',195.00, true);

-- AMBROXOL group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Mucolite 30', 'Ambroxol 30mg',   (SELECT id FROM salt_master WHERE name='Ambroxol'),'Ambroxol 30mg','Win Medicare',               '3004',12,'GENERAL',       'Tablet',    '10 Tab',    22.00, false),
('Ambril 30',   'Ambroxol 30mg',   (SELECT id FROM salt_master WHERE name='Ambroxol'),'Ambroxol 30mg','Cipla',                      '3004',12,'GENERAL',       'Tablet',    '10 Tab',    18.00, false),
('Mucosolvan',  'Ambroxol 75mg SR',(SELECT id FROM salt_master WHERE name='Ambroxol'),'Ambroxol HCl 75mg SR','Boehringer',          '3004',12,'GENERAL',       'Capsule',   '10 Cap',    55.00, false);

-- ALBENDAZOLE group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Zentel 400',  'Albendazole 400mg',(SELECT id FROM salt_master WHERE name='Albendazole'),'Albendazole 400mg','GSK',                '3004',12,'GENERAL',       'Tablet',    '1 Tab',     28.00, false),
('Bandy 400',   'Albendazole 400mg',(SELECT id FROM salt_master WHERE name='Albendazole'),'Albendazole 400mg','Mankind',            '3004',12,'GENERAL',       'Tablet',    '1 Tab',     22.00, false);

-- ANTI-TB group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Rifampicin 450','Rifampicin 450mg',(SELECT id FROM salt_master WHERE name='Rifampicin'),'Rifampicin 450mg','Cipla',              '3004',12,'SCHEDULE_H',    'Capsule',   '100 Cap',   450.00, true),
('INH 300',     'Isoniazid 300mg', (SELECT id FROM salt_master WHERE name='Isoniazid'),'Isoniazid 300mg','Cipla',                  '3004',12,'SCHEDULE_H',    'Tablet',    '100 Tab',   180.00, true);

-- ACYCLOVIR group
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Zovirax 400', 'Acyclovir 400mg', (SELECT id FROM salt_master WHERE name='Acyclovir'),'Acyclovir 400mg','GSK',                    '3004',12,'SCHEDULE_H',    'Tablet',    '25 Tab',    165.00, true),
('Acivir 400',  'Acyclovir 400mg', (SELECT id FROM salt_master WHERE name='Acyclovir'),'Acyclovir 400mg','Cipla',                  '3004',12,'SCHEDULE_H',    'Tablet',    '25 Tab',    145.00, true),
('Zovirax Cream','Acyclovir 5% Cream',(SELECT id FROM salt_master WHERE name='Acyclovir'),'Acyclovir 5%','GSK',                    '3004',12,'SCHEDULE_H',    'Cream',     '5g',        92.00, true);

-- FOLIC ACID standalone
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Folvite 5mg', 'Folic Acid 5mg',  (SELECT id FROM salt_master WHERE name='Folic Acid'),'Folic Acid 5mg','Pfizer',                 '3004',12,'GENERAL',       'Tablet',    '30 Tab',    25.00, false),
('Fol-5',       'Folic Acid 5mg',  (SELECT id FROM salt_master WHERE name='Folic Acid'),'Folic Acid 5mg','Elder',                  '3004',12,'GENERAL',       'Tablet',    '30 Tab',    20.00, false);

-- FIX the Wysolone subquery (was malformed earlier — re-insert clean)
DELETE FROM drug_master WHERE brand_name = 'Wysolone 5';
INSERT INTO drug_master (brand_name, generic_name, salt_id, salt_composition, manufacturer, hsn_code, gst_rate, drug_schedule, dosage_form, pack_size, mrp, prescription_required) VALUES
('Wysolone 5',  'Prednisolone 5mg',(SELECT id FROM salt_master WHERE name='Prednisolone'),'Prednisolone 5mg','Pfizer',              '3004',12,'SCHEDULE_H',    'Tablet',    '30 Tab',    28.00, true);
