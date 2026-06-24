-- V9: Schedule H prescription-required overlay.
--
-- Drugs and Cosmetics Rules Schedule H (~500 substances, prescription-only)
-- is broader than H1 (46 substances, doubly tracked). V2 seeds H1 inline;
-- this migration flags ~50-80 common Schedule H generics by salt-composition
-- match. H1 rows are NOT touched — H1 is a strict subset and its stricter
-- regime (statutory register entry under Rule 65(11)(h) D&C Rules) must win.
--
-- POS impact: `prescription_required=true` triggers the Flutter pharmacy
-- prescription-number dialog (`pos_screen.dart` line ~233) before the item
-- can be added to the cart. The backend `StatutoryRegisterService.classify()`
-- only treats H1 / SCHEDULE_X / NARCOTICS as register-trackable schedules,
-- so plain "H" entries here will NOT generate a statutory register row or
-- trigger `RX_PRESCRIPTION_REQUIRED` strict mode — that's by design (Sch H
-- is Rx-only, not register-bound; only H1 needs the 3-year retention sheet).
--
-- Source: well-known generics every Indian pharma distributor handles.
-- Not exhaustive — extend per category as new substances enter the catalogue.
-- Idempotent: the WHERE-NULL-OR-GENERAL guard makes re-running safe.
-- H1 salts explicitly NOT included here (already flagged in V2 seed):
--   Tramadol, Alprazolam, Diazepam, Clonazepam, Nitrazepam, Midazolam,
--   Zolpidem, Chlordiazepoxide, Codeine, Buprenorphine, Pentazocine,
--   Diphenoxylate, Atropine, Ibuprofen, Paracetamol, Diclofenac, Aceclofenac,
--   Bromfenac, Ketorolac, Chlorzoxazone, Mebeverine, Pantoprazole,
--   Amitriptyline, Imipramine, Melatonin, Clidinium, Chlorpheniramine,
--   Loteprednol, Hydroxypropylmethylcellulose, Amikacin, Tobramycin,
--   Azithromycin, Cefdinir, Cefditoren, Cefepime, Cefetamet, Cefixime,
--   Cefoperazone, Cefotaxime, Cefpirome, Cefpodoxime, Ceftazidime,
--   Ceftibuten, Ceftizoxime, Ceftriaxone, Doripenem, Ertapenem, Faropenem,
--   Imipenem, Meropenem, Balofloxacin, Gemifloxacin, Levofloxacin,
--   Moxifloxacin, Prulifloxacin, Sparfloxacin, Capreomycin, Clofazimine,
--   Cycloserine, Ethambutol, Ethionamide, Fluconazole, Isoniazid,
--   Pyrazinamide, Rifabutin, Rifampicin, Sodium aminosalicylate.

-- Anti-infectives — penicillins, additional cephalosporins, macrolides
-- (most fluoroquinolones, all carbapenems, several cephalosporins already H1)
UPDATE drug_master
SET drug_schedule = 'H', prescription_required = true
WHERE (drug_schedule IS NULL OR drug_schedule = 'GENERAL')
  AND (LOWER(salt_composition) LIKE '%amoxicillin%'
       OR LOWER(salt_composition) LIKE '%ampicillin%'
       OR LOWER(salt_composition) LIKE '%cloxacillin%'
       OR LOWER(salt_composition) LIKE '%piperacillin%'
       OR LOWER(salt_composition) LIKE '%tazobactam%'
       OR LOWER(salt_composition) LIKE '%clavulan%'
       OR LOWER(salt_composition) LIKE '%sulbactam%'
       OR LOWER(salt_composition) LIKE '%cephalexin%'
       OR LOWER(salt_composition) LIKE '%cefadroxil%'
       OR LOWER(salt_composition) LIKE '%cefuroxime%'
       OR LOWER(salt_composition) LIKE '%cefaclor%'
       OR LOWER(salt_composition) LIKE '%ciprofloxacin%'
       OR LOWER(salt_composition) LIKE '%ofloxacin%'
       OR LOWER(salt_composition) LIKE '%norfloxacin%'
       OR LOWER(salt_composition) LIKE '%clarithromycin%'
       OR LOWER(salt_composition) LIKE '%erythromycin%'
       OR LOWER(salt_composition) LIKE '%roxithromycin%'
       OR LOWER(salt_composition) LIKE '%doxycycline%'
       OR LOWER(salt_composition) LIKE '%minocycline%'
       OR LOWER(salt_composition) LIKE '%tetracycline%'
       OR LOWER(salt_composition) LIKE '%gentamicin%'
       OR LOWER(salt_composition) LIKE '%neomycin%'
       OR LOWER(salt_composition) LIKE '%clindamycin%'
       OR LOWER(salt_composition) LIKE '%linezolid%'
       OR LOWER(salt_composition) LIKE '%vancomycin%'
       OR LOWER(salt_composition) LIKE '%metronidazole%'
       OR LOWER(salt_composition) LIKE '%tinidazole%'
       OR LOWER(salt_composition) LIKE '%nitrofurantoin%'
       OR LOWER(salt_composition) LIKE '%cotrimoxazole%'
       OR LOWER(salt_composition) LIKE '%trimethoprim%'
       OR LOWER(salt_composition) LIKE '%sulfamethoxazole%');

-- Antifungals (Fluconazole is H1 — skip; others are Sch H)
UPDATE drug_master
SET drug_schedule = 'H', prescription_required = true
WHERE (drug_schedule IS NULL OR drug_schedule = 'GENERAL')
  AND (LOWER(salt_composition) LIKE '%itraconazole%'
       OR LOWER(salt_composition) LIKE '%ketoconazole%'
       OR LOWER(salt_composition) LIKE '%voriconazole%'
       OR LOWER(salt_composition) LIKE '%terbinafine%'
       OR LOWER(salt_composition) LIKE '%griseofulvin%');

-- Antivirals
UPDATE drug_master
SET drug_schedule = 'H', prescription_required = true
WHERE (drug_schedule IS NULL OR drug_schedule = 'GENERAL')
  AND (LOWER(salt_composition) LIKE '%acyclovir%'
       OR LOWER(salt_composition) LIKE '%valacyclovir%'
       OR LOWER(salt_composition) LIKE '%oseltamivir%'
       OR LOWER(salt_composition) LIKE '%tenofovir%'
       OR LOWER(salt_composition) LIKE '%lamivudine%'
       OR LOWER(salt_composition) LIKE '%efavirenz%');

-- Antidiabetics — orals + insulin-sensitisers
UPDATE drug_master
SET drug_schedule = 'H', prescription_required = true
WHERE (drug_schedule IS NULL OR drug_schedule = 'GENERAL')
  AND (LOWER(salt_composition) LIKE '%metformin%'
       OR LOWER(salt_composition) LIKE '%glimepiride%'
       OR LOWER(salt_composition) LIKE '%glipizide%'
       OR LOWER(salt_composition) LIKE '%gliclazide%'
       OR LOWER(salt_composition) LIKE '%glibenclamide%'
       OR LOWER(salt_composition) LIKE '%pioglitazone%'
       OR LOWER(salt_composition) LIKE '%sitagliptin%'
       OR LOWER(salt_composition) LIKE '%vildagliptin%'
       OR LOWER(salt_composition) LIKE '%linagliptin%'
       OR LOWER(salt_composition) LIKE '%teneligliptin%'
       OR LOWER(salt_composition) LIKE '%empagliflozin%'
       OR LOWER(salt_composition) LIKE '%dapagliflozin%'
       OR LOWER(salt_composition) LIKE '%canagliflozin%'
       OR LOWER(salt_composition) LIKE '%voglibose%'
       OR LOWER(salt_composition) LIKE '%acarbose%'
       OR LOWER(salt_composition) LIKE '%repaglinide%'
       OR LOWER(salt_composition) LIKE '%insulin%');

-- Cardiac — antihypertensives, statins, antiplatelets
UPDATE drug_master
SET drug_schedule = 'H', prescription_required = true
WHERE (drug_schedule IS NULL OR drug_schedule = 'GENERAL')
  AND (LOWER(salt_composition) LIKE '%telmisartan%'
       OR LOWER(salt_composition) LIKE '%losartan%'
       OR LOWER(salt_composition) LIKE '%valsartan%'
       OR LOWER(salt_composition) LIKE '%olmesartan%'
       OR LOWER(salt_composition) LIKE '%irbesartan%'
       OR LOWER(salt_composition) LIKE '%amlodipine%'
       OR LOWER(salt_composition) LIKE '%nifedipine%'
       OR LOWER(salt_composition) LIKE '%cilnidipine%'
       OR LOWER(salt_composition) LIKE '%nebivolol%'
       OR LOWER(salt_composition) LIKE '%metoprolol%'
       OR LOWER(salt_composition) LIKE '%atenolol%'
       OR LOWER(salt_composition) LIKE '%bisoprolol%'
       OR LOWER(salt_composition) LIKE '%carvedilol%'
       OR LOWER(salt_composition) LIKE '%propranolol%'
       OR LOWER(salt_composition) LIKE '%ramipril%'
       OR LOWER(salt_composition) LIKE '%enalapril%'
       OR LOWER(salt_composition) LIKE '%lisinopril%'
       OR LOWER(salt_composition) LIKE '%perindopril%'
       OR LOWER(salt_composition) LIKE '%hydrochlorothiazide%'
       OR LOWER(salt_composition) LIKE '%torsemide%'
       OR LOWER(salt_composition) LIKE '%furosemide%'
       OR LOWER(salt_composition) LIKE '%spironolactone%'
       OR LOWER(salt_composition) LIKE '%atorvastatin%'
       OR LOWER(salt_composition) LIKE '%rosuvastatin%'
       OR LOWER(salt_composition) LIKE '%simvastatin%'
       OR LOWER(salt_composition) LIKE '%fenofibrate%'
       OR LOWER(salt_composition) LIKE '%ezetimibe%'
       OR LOWER(salt_composition) LIKE '%nitroglycerin%'
       OR LOWER(salt_composition) LIKE '%isosorbide%'
       OR LOWER(salt_composition) LIKE '%digoxin%'
       OR LOWER(salt_composition) LIKE '%amiodarone%');

-- Anticoagulants / antiplatelets
UPDATE drug_master
SET drug_schedule = 'H', prescription_required = true
WHERE (drug_schedule IS NULL OR drug_schedule = 'GENERAL')
  AND (LOWER(salt_composition) LIKE '%warfarin%'
       OR LOWER(salt_composition) LIKE '%acenocoumarol%'
       OR LOWER(salt_composition) LIKE '%clopidogrel%'
       OR LOWER(salt_composition) LIKE '%prasugrel%'
       OR LOWER(salt_composition) LIKE '%ticagrelor%'
       OR LOWER(salt_composition) LIKE '%heparin%'
       OR LOWER(salt_composition) LIKE '%enoxaparin%'
       OR LOWER(salt_composition) LIKE '%rivaroxaban%'
       OR LOWER(salt_composition) LIKE '%apixaban%'
       OR LOWER(salt_composition) LIKE '%dabigatran%');

-- Gastric — PPIs (Pantoprazole is H1 — skip), H2 blockers, prokinetics
UPDATE drug_master
SET drug_schedule = 'H', prescription_required = true
WHERE (drug_schedule IS NULL OR drug_schedule = 'GENERAL')
  AND (LOWER(salt_composition) LIKE '%omeprazole%'
       OR LOWER(salt_composition) LIKE '%esomeprazole%'
       OR LOWER(salt_composition) LIKE '%rabeprazole%'
       OR LOWER(salt_composition) LIKE '%lansoprazole%'
       OR LOWER(salt_composition) LIKE '%ranitidine%'
       OR LOWER(salt_composition) LIKE '%famotidine%'
       OR LOWER(salt_composition) LIKE '%domperidone%'
       OR LOWER(salt_composition) LIKE '%itopride%'
       OR LOWER(salt_composition) LIKE '%ondansetron%');

-- Thyroid / steroids / hormones
UPDATE drug_master
SET drug_schedule = 'H', prescription_required = true
WHERE (drug_schedule IS NULL OR drug_schedule = 'GENERAL')
  AND (LOWER(salt_composition) LIKE '%levothyroxine%'
       OR LOWER(salt_composition) LIKE '%carbimazole%'
       OR LOWER(salt_composition) LIKE '%methimazole%'
       OR LOWER(salt_composition) LIKE '%prednisolone%'
       OR LOWER(salt_composition) LIKE '%methylprednisolone%'
       OR LOWER(salt_composition) LIKE '%dexamethasone%'
       OR LOWER(salt_composition) LIKE '%hydrocortisone%'
       OR LOWER(salt_composition) LIKE '%betamethasone%'
       OR LOWER(salt_composition) LIKE '%triamcinolone%');

-- Psychiatry — SSRIs / SNRIs / antipsychotics
-- (benzos all H1, codeine combos H1, tramadol H1 — skip those)
UPDATE drug_master
SET drug_schedule = 'H', prescription_required = true
WHERE (drug_schedule IS NULL OR drug_schedule = 'GENERAL')
  AND (LOWER(salt_composition) LIKE '%escitalopram%'
       OR LOWER(salt_composition) LIKE '%citalopram%'
       OR LOWER(salt_composition) LIKE '%sertraline%'
       OR LOWER(salt_composition) LIKE '%fluoxetine%'
       OR LOWER(salt_composition) LIKE '%paroxetine%'
       OR LOWER(salt_composition) LIKE '%venlafaxine%'
       OR LOWER(salt_composition) LIKE '%duloxetine%'
       OR LOWER(salt_composition) LIKE '%mirtazapine%'
       OR LOWER(salt_composition) LIKE '%olanzapine%'
       OR LOWER(salt_composition) LIKE '%risperidone%'
       OR LOWER(salt_composition) LIKE '%quetiapine%'
       OR LOWER(salt_composition) LIKE '%aripiprazole%'
       OR LOWER(salt_composition) LIKE '%haloperidol%'
       OR LOWER(salt_composition) LIKE '%lithium carbonate%');

-- Antiepileptics
UPDATE drug_master
SET drug_schedule = 'H', prescription_required = true
WHERE (drug_schedule IS NULL OR drug_schedule = 'GENERAL')
  AND (LOWER(salt_composition) LIKE '%phenytoin%'
       OR LOWER(salt_composition) LIKE '%carbamazepine%'
       OR LOWER(salt_composition) LIKE '%oxcarbazepine%'
       OR LOWER(salt_composition) LIKE '%levetiracetam%'
       OR LOWER(salt_composition) LIKE '%valproate%'
       OR LOWER(salt_composition) LIKE '%valproic%'
       OR LOWER(salt_composition) LIKE '%lamotrigine%'
       OR LOWER(salt_composition) LIKE '%gabapentin%'
       OR LOWER(salt_composition) LIKE '%pregabalin%'
       OR LOWER(salt_composition) LIKE '%topiramate%'
       OR LOWER(salt_composition) LIKE '%phenobarbital%');

-- Respiratory — bronchodilators, ICS, leukotriene antagonists
UPDATE drug_master
SET drug_schedule = 'H', prescription_required = true
WHERE (drug_schedule IS NULL OR drug_schedule = 'GENERAL')
  AND (LOWER(salt_composition) LIKE '%salbutamol%'
       OR LOWER(salt_composition) LIKE '%levosalbutamol%'
       OR LOWER(salt_composition) LIKE '%salmeterol%'
       OR LOWER(salt_composition) LIKE '%formoterol%'
       OR LOWER(salt_composition) LIKE '%terbutaline%'
       OR LOWER(salt_composition) LIKE '%ipratropium%'
       OR LOWER(salt_composition) LIKE '%tiotropium%'
       OR LOWER(salt_composition) LIKE '%fluticasone%'
       OR LOWER(salt_composition) LIKE '%budesonide%'
       OR LOWER(salt_composition) LIKE '%beclomethasone%'
       OR LOWER(salt_composition) LIKE '%mometasone%'
       OR LOWER(salt_composition) LIKE '%montelukast%'
       OR LOWER(salt_composition) LIKE '%theophylline%'
       OR LOWER(salt_composition) LIKE '%doxofylline%');

-- Oncology / immunosuppressants (representative; full oncology pack later)
UPDATE drug_master
SET drug_schedule = 'H', prescription_required = true
WHERE (drug_schedule IS NULL OR drug_schedule = 'GENERAL')
  AND (LOWER(salt_composition) LIKE '%methotrexate%'
       OR LOWER(salt_composition) LIKE '%azathioprine%'
       OR LOWER(salt_composition) LIKE '%mycophenolate%'
       OR LOWER(salt_composition) LIKE '%tacrolimus%'
       OR LOWER(salt_composition) LIKE '%cyclosporine%'
       OR LOWER(salt_composition) LIKE '%tamoxifen%'
       OR LOWER(salt_composition) LIKE '%anastrozole%'
       OR LOWER(salt_composition) LIKE '%letrozole%');

-- Urology / BPH
UPDATE drug_master
SET drug_schedule = 'H', prescription_required = true
WHERE (drug_schedule IS NULL OR drug_schedule = 'GENERAL')
  AND (LOWER(salt_composition) LIKE '%tamsulosin%'
       OR LOWER(salt_composition) LIKE '%finasteride%'
       OR LOWER(salt_composition) LIKE '%dutasteride%'
       OR LOWER(salt_composition) LIKE '%sildenafil%'
       OR LOWER(salt_composition) LIKE '%tadalafil%'
       OR LOWER(salt_composition) LIKE '%solifenacin%'
       OR LOWER(salt_composition) LIKE '%tolterodine%');

-- Neurology — antiparkinsonism, dementia
UPDATE drug_master
SET drug_schedule = 'H', prescription_required = true
WHERE (drug_schedule IS NULL OR drug_schedule = 'GENERAL')
  AND (LOWER(salt_composition) LIKE '%levodopa%'
       OR LOWER(salt_composition) LIKE '%carbidopa%'
       OR LOWER(salt_composition) LIKE '%pramipexole%'
       OR LOWER(salt_composition) LIKE '%donepezil%'
       OR LOWER(salt_composition) LIKE '%memantine%');

-- Migraine / neuropathic
UPDATE drug_master
SET drug_schedule = 'H', prescription_required = true
WHERE (drug_schedule IS NULL OR drug_schedule = 'GENERAL')
  AND (LOWER(salt_composition) LIKE '%sumatriptan%'
       OR LOWER(salt_composition) LIKE '%rizatriptan%'
       OR LOWER(salt_composition) LIKE '%flunarizine%');
