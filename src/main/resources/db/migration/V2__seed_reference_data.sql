-- V2: Seed / reference data (squashed from the former migration chain).
-- Platform master tables: drug_master, salt_master, manufacturer_master,
-- hsn_gst_master, generic_substitution, drug_interaction, coa_template,
-- currency, ai_model_registry.

--
-- PostgreSQL database dump
--

-- Dumped from database version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)

--
-- Data for Name: organisation; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: account; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: ai_model_registry; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.ai_model_registry VALUES
	('f4fc6914-8eda-43e9-9130-1226aa1dc568', 'INVOICE_REVIEW', 'deterministic_rules', '1', 'RULE_ENGINE', NULL, NULL, 'ACTIVE', 1.0000, '2026-06-12 15:36:20.601734+00'),
	('712d0d33-f519-4241-b7e6-74b1003656f7', 'STOCK_REVIEW', 'deterministic_rules', '1', 'RULE_ENGINE', NULL, NULL, 'ACTIVE', 1.0000, '2026-06-12 15:36:20.601734+00'),
	('87beead7-e7ae-4388-b23f-69ca74a5b41f', 'PAYMENT_REVIEW', 'deterministic_rules', '1', 'RULE_ENGINE', NULL, NULL, 'ACTIVE', 1.0000, '2026-06-12 15:36:20.601734+00');

--
-- Data for Name: ai_model_run; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: ai_pattern; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: branch; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: ca_firm; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: app_user; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: ai_suggestion; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: ai_training_example; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: ai_usage_log; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: api_key; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: workflow_definition; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: approval_request; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: approval_decision; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: price_list; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: contact; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: journal_entry; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: invoice; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: payment; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: bank_transaction; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: batch_trace; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: beat; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: beat_customer; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: item_group; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: rack_location; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: tax_group; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: uom; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: item; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: bom_component; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: bom_alternate; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: bom_co_product; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: budget_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: ca_alert_dismissal; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: ca_client_link; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: ca_compliance_deadline; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: ca_report_dispatch; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: coa_template; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.coa_template VALUES
	('4678fb87-d358-4de1-a27e-ed89c82d22a2', 'TRADING', '1000', 'Assets', 'ASSET', NULL, NULL, 1, true),
	('8c2cf134-1911-4d8a-8dc1-d707b3b78932', 'TRADING', '1010', 'Cash', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('ede58e7c-06e7-4278-8c49-2e629b9e4a5c', 'TRADING', '1020', 'Bank Account', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('e86f217c-fe16-4422-9609-ad7aa1083799', 'TRADING', '1100', 'Accounts Receivable', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('fdf6d0d3-3f62-484f-b92b-af2288f38fa1', 'TRADING', '1200', 'Inventory', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('1b415457-9314-4742-a9e6-f2c2b5a4ec08', 'TRADING', '1300', 'Prepaid Expenses', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('b56edd56-c84a-413a-9d2a-502719a3d29b', 'TRADING', '1400', 'Advances to Suppliers', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('19bfc21e-464d-4d40-a8ef-82f22c374ce0', 'TRADING', '1500', 'GST Input Credit', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('6eaee530-f349-456a-948a-6a88cae72b0f', 'TRADING', '1600', 'Fixed Assets', 'ASSET', 'FIXED_ASSET', '1000', 2, true),
	('3d439023-29cd-4388-a970-b651d3859782', 'TRADING', '1690', 'Accumulated Depreciation', 'ASSET', 'FIXED_ASSET', '1000', 2, true),
	('1640e949-8fd0-4443-9e9d-cd1953cbbcfa', 'TRADING', '1610', 'Furniture & Fixtures', 'ASSET', 'FIXED_ASSET', '1600', 3, true),
	('2b169193-2874-40a2-bc13-9e53aa8e5a8c', 'TRADING', '1620', 'Computer Equipment', 'ASSET', 'FIXED_ASSET', '1600', 3, true),
	('166c3b33-df13-4206-a446-f1917276d9f7', 'TRADING', '2000', 'Liabilities', 'LIABILITY', NULL, NULL, 1, true),
	('df15c7df-575d-4665-b86a-f9981963baf6', 'TRADING', '2010', 'Accounts Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('7984c65c-3a30-4348-9069-71594a261ce3', 'TRADING', '2020', 'CGST Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('0644bbcb-5973-4d7b-977e-1c35b7e1fb30', 'TRADING', '2021', 'SGST Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('e5f0100c-9986-465c-86b7-6ad57c386d99', 'TRADING', '2022', 'IGST Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('b11ed0ed-0d54-4e84-8087-8bc2f11f7d14', 'TRADING', '2030', 'TDS Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('c50a169d-de91-4d90-975f-9edbb8382e1c', 'TRADING', '2040', 'Salary Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('2f8f26c1-3fe6-4ef8-85e0-b9577c075b16', 'TRADING', '2050', 'PF Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('aa12885c-6743-4e17-8bad-82a91ac41363', 'TRADING', '2060', 'ESI Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('569cca8a-15c0-4ee4-bfbd-df57513529c4', 'TRADING', '2070', 'Professional Tax Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('79930e06-e0e9-4804-baa1-82e54e3aeec0', 'TRADING', '2100', 'Advance from Customers', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('7ebf89c2-1001-40c1-94a4-ce573814ba18', 'TRADING', '2200', 'Accrued Expenses', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('4c3b4dd3-2337-46cb-8bf5-d0830d23f31e', 'TRADING', '2500', 'Long-term Loans', 'LIABILITY', 'LONG_TERM_LIABILITY', '2000', 2, true),
	('381883d2-66c2-4339-b164-1b75441cd481', 'TRADING', '3000', 'Equity', 'EQUITY', NULL, NULL, 1, true),
	('283d3513-c244-44f2-a4db-249c7c240cca', 'TRADING', '3010', 'Owner Capital', 'EQUITY', 'OWNERS_EQUITY', '3000', 2, true),
	('acfcee33-71c2-45dc-acf2-b7407820d63a', 'TRADING', '3020', 'Retained Earnings', 'EQUITY', 'RETAINED_EARNINGS', '3000', 2, true),
	('f1e45699-b871-4fa6-9b47-4492ae44999e', 'TRADING', '3030', 'Drawings', 'EQUITY', 'DRAWINGS', '3000', 2, true),
	('fbf40589-9150-4cc8-97e8-650ee79a3d56', 'TRADING', '4000', 'Revenue', 'REVENUE', NULL, NULL, 1, true),
	('27440c0b-9d8a-42e3-be0e-534b8ebedaee', 'TRADING', '4010', 'Sales Revenue', 'REVENUE', 'OPERATING_REVENUE', '4000', 2, true),
	('e2ec2483-9078-43a0-86ef-ab48f907db38', 'TRADING', '4020', 'Service Revenue', 'REVENUE', 'OPERATING_REVENUE', '4000', 2, true),
	('72941d2a-7575-4366-923f-9facc7cf8dfc', 'TRADING', '4100', 'Other Income', 'REVENUE', 'OTHER_INCOME', '4000', 2, true),
	('9a36d1a7-54e8-40fd-88a2-cc1caa3436ca', 'TRADING', '4110', 'Interest Income', 'REVENUE', 'OTHER_INCOME', '4100', 3, true),
	('245014a1-26dd-4e49-90aa-19c0732f4f2f', 'TRADING', '4120', 'Discount Received', 'REVENUE', 'OTHER_INCOME', '4100', 3, true),
	('9f6a6a9f-5bb0-49fc-b2d0-6ba235eef08d', 'TRADING', '5000', 'Expenses', 'EXPENSE', NULL, NULL, 1, true),
	('8a75e06a-b7b7-4773-b8e3-6cd7e70f3b65', 'TRADING', '5010', 'Cost of Goods Sold', 'EXPENSE', 'COGS', '5000', 2, true),
	('392f6876-3d85-4735-8c9c-b99f0f32b0e1', 'TRADING', '5020', 'Purchase Expense', 'EXPENSE', 'COGS', '5000', 2, true),
	('f68e284f-f048-4a70-a8aa-34500a9ffd11', 'TRADING', '5100', 'Salary Expense', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('518d58c3-47ad-41fd-a62c-ad51451fcf04', 'TRADING', '5110', 'Employer PF Contribution', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('1007b3e2-a700-489a-975b-7109f3b14d1b', 'TRADING', '5120', 'Employer ESI Contribution', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('7d6de71e-fe98-468c-805a-2c12e11830b5', 'TRADING', '5200', 'Rent Expense', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('52b1c71c-a849-4d97-9d6b-9129da089bf8', 'TRADING', '5210', 'Utilities', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('88722fac-2348-43ca-98ab-b1fa88b3e8a9', 'TRADING', '5220', 'Office Supplies', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('d07a6c17-854e-4e35-ae8e-bf1879943e6c', 'TRADING', '5230', 'Telephone & Internet', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('f25ecc1f-45cd-4a28-bd8e-14598e0c2dbb', 'TRADING', '5240', 'Travel & Conveyance', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('fff88ecd-c47f-4ad0-a38e-37d844d34c8c', 'TRADING', '5250', 'Insurance', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('4aba9cad-cfb6-4b2b-a164-d7e22cc86977', 'TRADING', '5260', 'Legal & Professional Fees', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('1ca52e4a-450f-47b7-af18-d80a23096180', 'TRADING', '5270', 'Depreciation Expense', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('c7222f41-0412-4c41-aa88-4818333ead1b', 'TRADING', '5280', 'Bank Charges', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('d232fa83-ca3c-44ae-a0b0-d7f65511d0e9', 'TRADING', '5290', 'Discount Allowed', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('d18ab432-0fe4-45ed-a9eb-a09ab65e6fdd', 'TRADING', '5300', 'Miscellaneous Expense', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('2aae72e1-bb50-48b8-a1d9-7284f7953738', 'TRADING', '5400', 'Inventory Loss/Shrinkage', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('99f8c4f0-b702-43da-b0a7-7beb1f73cc55', 'TRADING', '5500', 'Forex Gain/Loss', 'EXPENSE', 'OTHER_EXPENSE', '5000', 2, true),
	('594c43e7-d8e4-47ad-8493-8d2699615fb4', 'TRADING', '5600', 'Rounding Adjustment', 'EXPENSE', 'OTHER_EXPENSE', '5000', 2, true),
	('afc4d8e4-9c95-4c4a-a97f-7d979d5a51ea', 'RETAIL', '1000', 'Assets', 'ASSET', NULL, NULL, 1, true),
	('e7c458c9-54b1-40d8-abd4-d862f40d50e3', 'RETAIL', '1010', 'Cash', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('0e9ddad8-b0c1-4ff3-92a5-3434f4d73e55', 'RETAIL', '1020', 'Bank Account', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('6ebf0554-81bc-416c-bbbb-2d59038b1287', 'RETAIL', '1100', 'Accounts Receivable', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('89f5a11c-f3e5-4485-9f6b-e9fb4dbc3deb', 'RETAIL', '1200', 'Inventory', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('e8fbc6a9-1fdf-4a69-a3bb-eb148bca4268', 'RETAIL', '1300', 'Prepaid Expenses', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('411a77e6-78b7-480f-9b02-c9fc804788f8', 'RETAIL', '1400', 'Advances to Suppliers', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('f9642263-1d5b-482a-88fc-a4d4199f03d2', 'RETAIL', '1500', 'GST Input Credit', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('bf7230c2-281b-4fbd-9101-6d7af4845c04', 'RETAIL', '1600', 'Fixed Assets', 'ASSET', 'FIXED_ASSET', '1000', 2, true),
	('5a0b348b-1f94-4afe-94b8-ead544d95af8', 'RETAIL', '1610', 'Furniture & Fixtures', 'ASSET', 'FIXED_ASSET', '1600', 3, true),
	('b24d1966-9d43-40c6-bce6-b931082e0ed0', 'RETAIL', '1620', 'Computer Equipment', 'ASSET', 'FIXED_ASSET', '1600', 3, true),
	('3546cbc6-7752-4f21-b292-d19813467106', 'RETAIL', '1690', 'Accumulated Depreciation', 'ASSET', 'FIXED_ASSET', '1000', 2, true),
	('cfcbebde-4b48-47fd-86a3-09ba03afb691', 'RETAIL', '2000', 'Liabilities', 'LIABILITY', NULL, NULL, 1, true),
	('928028ab-0d78-44db-accb-143594619245', 'RETAIL', '2010', 'Accounts Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('b97d0aa6-bce8-4a30-bca3-c39b4c0ee9bd', 'RETAIL', '2020', 'CGST Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('b910f6a3-8b5c-45d8-94dc-92591d554e9e', 'RETAIL', '2021', 'SGST Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('ff54a229-a266-41bb-b5cb-001191cb6238', 'RETAIL', '2022', 'IGST Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('8140ce07-7262-45a0-bed3-a0b6b5d7f056', 'RETAIL', '2030', 'TDS Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('575a0eef-8172-4ac1-80e6-5bc2e78faef5', 'RETAIL', '2040', 'Salary Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('f30fbb03-7ed5-46dd-9832-572260d8a476', 'RETAIL', '2050', 'PF Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('64369a30-a08a-4871-b0de-f3f94d1ea136', 'RETAIL', '2060', 'ESI Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('21ab835a-b650-4d00-994b-7254939de34f', 'RETAIL', '2070', 'Professional Tax Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('b5df0fac-5c7e-463b-b65f-bf7bbbb7c541', 'RETAIL', '2100', 'Advance from Customers', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('0baba71c-8665-44cb-aa3e-c14be6f91931', 'RETAIL', '2200', 'Accrued Expenses', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('dadce32b-dd8a-41ed-9075-3e4f05d0a842', 'RETAIL', '2500', 'Long-term Loans', 'LIABILITY', 'LONG_TERM_LIABILITY', '2000', 2, true),
	('41a26c6a-7534-4764-b8b9-79be3ca04afb', 'RETAIL', '3000', 'Equity', 'EQUITY', NULL, NULL, 1, true),
	('6c311dc3-5d23-4943-96d3-67ef900e03e2', 'RETAIL', '3010', 'Owner Capital', 'EQUITY', 'OWNERS_EQUITY', '3000', 2, true),
	('e6e83b19-f30d-4006-8679-b8d771f75293', 'RETAIL', '3020', 'Retained Earnings', 'EQUITY', 'RETAINED_EARNINGS', '3000', 2, true),
	('de87e999-40c8-4f39-8092-641e99a1e124', 'RETAIL', '3030', 'Drawings', 'EQUITY', 'DRAWINGS', '3000', 2, true),
	('4f0c5bf9-e0c5-4869-a77d-42400263c96e', 'RETAIL', '4000', 'Revenue', 'REVENUE', NULL, NULL, 1, true),
	('28c232e3-6e76-413b-8cb0-a2997fc470ad', 'RETAIL', '4010', 'Sales Revenue', 'REVENUE', 'OPERATING_REVENUE', '4000', 2, true),
	('d3c1dc62-e86d-49fe-b0a3-f60b41182aff', 'RETAIL', '4020', 'Service Revenue', 'REVENUE', 'OPERATING_REVENUE', '4000', 2, true),
	('706b78e3-26dc-4120-886f-d37aa0dc7891', 'RETAIL', '4100', 'Other Income', 'REVENUE', 'OTHER_INCOME', '4000', 2, true),
	('573d4d9f-cbba-4350-91e2-1bb6962048d5', 'RETAIL', '4110', 'Interest Income', 'REVENUE', 'OTHER_INCOME', '4100', 3, true),
	('56820ea3-98ff-4005-ad7a-4972191e980f', 'RETAIL', '4120', 'Discount Received', 'REVENUE', 'OTHER_INCOME', '4100', 3, true),
	('5d9414df-8d7f-415a-bb08-10cd44482fe5', 'RETAIL', '5000', 'Expenses', 'EXPENSE', NULL, NULL, 1, true),
	('31d01c8d-90b9-4ff9-a5c3-2ff5bb6b0a9a', 'RETAIL', '5010', 'Cost of Goods Sold', 'EXPENSE', 'COGS', '5000', 2, true),
	('e80482f9-8a23-4d71-9b52-d5f01078f993', 'RETAIL', '5020', 'Purchase Expense', 'EXPENSE', 'COGS', '5000', 2, true),
	('ce503aa0-4ece-4978-ae36-9ad29f5eafab', 'RETAIL', '5100', 'Salary Expense', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('f5cbdd7a-da9b-497f-a020-193fcf311703', 'RETAIL', '5110', 'Employer PF Contribution', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('4579d5ee-39a2-49ac-a35b-fb120569d0fb', 'RETAIL', '5120', 'Employer ESI Contribution', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('1c60a363-9702-4922-9076-a9125e1d12f8', 'RETAIL', '5200', 'Rent Expense', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('543d154c-7800-42b5-9343-a481f5651e71', 'RETAIL', '5210', 'Utilities', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('324792b0-79ac-4ecc-b3c7-3c2bea98df92', 'RETAIL', '5220', 'Office Supplies', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('295d057e-b009-4563-bb1e-7936545d41e0', 'RETAIL', '5230', 'Telephone & Internet', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('b3540b68-2065-44b4-b5ef-67ea3b41b3e1', 'RETAIL', '5240', 'Travel & Conveyance', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('158da4db-7b22-487a-bf56-759211cbfe59', 'RETAIL', '5250', 'Insurance', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('60f7b212-cea6-46f0-b804-f15994984261', 'RETAIL', '5260', 'Legal & Professional Fees', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('4bf61c68-8c11-4b9b-9635-01d6922975b2', 'RETAIL', '5270', 'Depreciation Expense', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('a14d402b-3f6a-4812-8c7b-d9c2145e6a9a', 'RETAIL', '5280', 'Bank Charges', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('b805fece-9c6e-4405-963b-a026cc2448e1', 'RETAIL', '5290', 'Discount Allowed', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('442c6b5a-6923-44f6-9f57-340e8fc6b7e5', 'RETAIL', '5300', 'Miscellaneous Expense', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('263b6dc8-778d-41a8-bebc-cad7ead00f6f', 'RETAIL', '5400', 'Inventory Loss/Shrinkage', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('dff27d6d-a23e-48d4-a5ad-cbfb59a5d147', 'RETAIL', '5500', 'Forex Gain/Loss', 'EXPENSE', 'OTHER_EXPENSE', '5000', 2, true),
	('a89898a4-7693-436f-b4ca-2e8455fb1525', 'RETAIL', '5600', 'Rounding Adjustment', 'EXPENSE', 'OTHER_EXPENSE', '5000', 2, true),
	('5556e0d9-4469-476d-a911-4b2bfe8702f8', 'SERVICES', '1000', 'Assets', 'ASSET', NULL, NULL, 1, true),
	('d2cd9f85-f49b-454f-b531-d482a2b257a9', 'SERVICES', '1010', 'Cash', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('486c814f-3340-4879-83a4-a1ef3156e3dd', 'SERVICES', '1020', 'Bank Account', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('0d1881be-a96b-4bda-9a6d-5b0a3573d8b8', 'SERVICES', '1100', 'Accounts Receivable', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('1ad42f1d-45e0-49b0-9748-878b7be10ca6', 'SERVICES', '1200', 'Inventory', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('ce4ddb6e-7272-444b-9cf8-0ee195857a7b', 'SERVICES', '1300', 'Prepaid Expenses', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('40255d20-342d-481a-b6cd-e7e2e57bdae9', 'SERVICES', '1400', 'Advances to Suppliers', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('61f47dd7-5f36-4a77-be8d-c22e68492c1b', 'SERVICES', '1500', 'GST Input Credit', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('89b21994-9516-4536-a56b-7a1bbf524845', 'SERVICES', '1600', 'Fixed Assets', 'ASSET', 'FIXED_ASSET', '1000', 2, true),
	('47640fc2-1c7b-4090-bcca-69df4beeeb9e', 'SERVICES', '1610', 'Furniture & Fixtures', 'ASSET', 'FIXED_ASSET', '1600', 3, true),
	('8e8b01cd-98bc-4c2c-877f-c528110540cc', 'SERVICES', '1620', 'Computer Equipment', 'ASSET', 'FIXED_ASSET', '1600', 3, true),
	('25fe99f3-cee9-47c1-9375-f42270b7d114', 'SERVICES', '1690', 'Accumulated Depreciation', 'ASSET', 'FIXED_ASSET', '1000', 2, true),
	('1a07478d-051d-4b06-aee3-83d339bdc36d', 'SERVICES', '2000', 'Liabilities', 'LIABILITY', NULL, NULL, 1, true),
	('ee522ca7-677e-42cf-bedc-a78808d979ba', 'SERVICES', '2010', 'Accounts Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('3459d39c-3532-46a3-bb5e-8d7e7d77b046', 'SERVICES', '2020', 'CGST Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('a142ed7e-b376-4960-bb94-dc8701b15999', 'SERVICES', '2021', 'SGST Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('474e61ae-5ee3-4e7d-95e0-bc9bb345969a', 'SERVICES', '2022', 'IGST Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('8dd668cf-b035-4ed6-b3e0-00b519cc6ed4', 'SERVICES', '2030', 'TDS Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('196bcf4e-6758-48c6-a61a-d5fa16d64369', 'SERVICES', '2040', 'Salary Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('d470683c-0d66-4bb5-bf7a-29b14801e66e', 'SERVICES', '2050', 'PF Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('50c4c995-d8eb-4298-8091-1c9d5278d414', 'SERVICES', '2060', 'ESI Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('d4ed8895-752b-4c24-a98d-0ca3001304b0', 'SERVICES', '2070', 'Professional Tax Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('cf38cd1e-b492-4e3b-bd68-0fd475691a9f', 'SERVICES', '2100', 'Advance from Customers', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('d25fbfa3-ac5d-4472-80a0-99d3f7843e1a', 'SERVICES', '2200', 'Accrued Expenses', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('5734c771-a890-4695-8b0a-ba504796b492', 'SERVICES', '2500', 'Long-term Loans', 'LIABILITY', 'LONG_TERM_LIABILITY', '2000', 2, true),
	('0933c78e-e6f6-47f4-b089-57bfd93777e7', 'SERVICES', '3000', 'Equity', 'EQUITY', NULL, NULL, 1, true),
	('ff41c1c0-7cd1-41f3-ba41-914c4c7edffd', 'SERVICES', '3010', 'Owner Capital', 'EQUITY', 'OWNERS_EQUITY', '3000', 2, true),
	('573a565d-c697-456c-bdfd-294c107e1ded', 'SERVICES', '3020', 'Retained Earnings', 'EQUITY', 'RETAINED_EARNINGS', '3000', 2, true),
	('eec6124b-9ce3-42e1-a165-2844ad787d02', 'SERVICES', '3030', 'Drawings', 'EQUITY', 'DRAWINGS', '3000', 2, true),
	('76fa8fcd-b891-46b8-8ca6-29443377979a', 'SERVICES', '4000', 'Revenue', 'REVENUE', NULL, NULL, 1, true),
	('f788b8e4-4a9a-477c-a0f5-15179772e992', 'SERVICES', '4010', 'Sales Revenue', 'REVENUE', 'OPERATING_REVENUE', '4000', 2, true),
	('a308e232-49d5-400e-9b32-8d27df92fa9c', 'SERVICES', '4020', 'Service Revenue', 'REVENUE', 'OPERATING_REVENUE', '4000', 2, true),
	('b7a2dd7e-d6de-4cb3-b469-b81818b24c06', 'SERVICES', '4100', 'Other Income', 'REVENUE', 'OTHER_INCOME', '4000', 2, true),
	('834e63c7-ea64-4879-91f7-a413bc1d053e', 'SERVICES', '4110', 'Interest Income', 'REVENUE', 'OTHER_INCOME', '4100', 3, true),
	('ead09a88-d796-4551-ac6a-a5f35608571b', 'SERVICES', '4120', 'Discount Received', 'REVENUE', 'OTHER_INCOME', '4100', 3, true),
	('a782acaf-d4a4-4c06-99b9-955a7b92d538', 'SERVICES', '5000', 'Expenses', 'EXPENSE', NULL, NULL, 1, true),
	('3509dd13-d7f6-42b9-b609-b807ac9b5e5d', 'SERVICES', '5010', 'Cost of Goods Sold', 'EXPENSE', 'COGS', '5000', 2, true),
	('4c508198-b92d-40e0-87d7-5571ba5aa594', 'SERVICES', '5020', 'Purchase Expense', 'EXPENSE', 'COGS', '5000', 2, true),
	('d59a5a7d-1a62-4727-9440-db87f15d27e9', 'SERVICES', '5100', 'Salary Expense', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('7844ad52-288f-4365-878d-196c3e2d8f72', 'SERVICES', '5110', 'Employer PF Contribution', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('ae5d1da6-cfec-4d7b-9417-cb94b7faebdd', 'SERVICES', '5120', 'Employer ESI Contribution', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('fcac765f-3dc7-4b36-ab53-b25523741caa', 'SERVICES', '5200', 'Rent Expense', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('d774adb4-1947-45fe-8ccc-f438c42e2f37', 'SERVICES', '5210', 'Utilities', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('14544d66-54ce-4446-ae6e-15cba22d42e4', 'SERVICES', '5220', 'Office Supplies', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('64718ef1-4d76-48ca-9b3c-a7133f6c9e24', 'SERVICES', '5230', 'Telephone & Internet', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('f2bf2d18-0b5f-4a8d-b713-07c76b8ed124', 'SERVICES', '5240', 'Travel & Conveyance', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('15078c1f-adcb-49bb-8d70-cf56a8e9eb2d', 'SERVICES', '5250', 'Insurance', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('09933ec6-0fa1-4efb-b4d9-a361576d5c31', 'SERVICES', '5260', 'Legal & Professional Fees', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('bfce93fe-3de0-4346-a3cd-0cd461330bb9', 'SERVICES', '5270', 'Depreciation Expense', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('7294f179-11cc-432b-accc-15871494df5f', 'SERVICES', '5280', 'Bank Charges', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('a5953813-71e8-4635-87c0-23b55439341e', 'SERVICES', '5290', 'Discount Allowed', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('ad14f6e9-86ef-4fe6-8b0c-a7a4c7b6cafd', 'SERVICES', '5300', 'Miscellaneous Expense', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('e590d226-93a9-4570-9458-e250775adae6', 'SERVICES', '5400', 'Inventory Loss/Shrinkage', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('bfccd869-86db-4de8-9aee-30de8c6d9529', 'SERVICES', '5500', 'Forex Gain/Loss', 'EXPENSE', 'OTHER_EXPENSE', '5000', 2, true),
	('049ba5e2-d491-44da-8a1c-8073a5a76273', 'SERVICES', '5600', 'Rounding Adjustment', 'EXPENSE', 'OTHER_EXPENSE', '5000', 2, true),
	('7cc885f2-6900-4680-b04d-e78803e8581d', 'F_AND_B', '1000', 'Assets', 'ASSET', NULL, NULL, 1, true),
	('b10fd38d-64db-4d9a-92c5-42425856fc0e', 'F_AND_B', '1010', 'Cash', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('8f9c93de-0167-4b37-ae26-c15dd96d7bdf', 'F_AND_B', '1020', 'Bank Account', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('2d00ca9d-f84a-47d4-91b4-5f60979dbbcf', 'F_AND_B', '1100', 'Accounts Receivable', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('66522a88-0a7b-4d60-8ec4-d9297903e564', 'F_AND_B', '1200', 'Inventory', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('594bbf65-44c0-4e74-8501-fdca23933bd6', 'F_AND_B', '1300', 'Prepaid Expenses', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('94d76141-bf86-405d-a43d-64a24e216d0a', 'F_AND_B', '1400', 'Advances to Suppliers', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('aeb6b818-4947-42bc-826b-182cecd53a75', 'F_AND_B', '1500', 'GST Input Credit', 'ASSET', 'CURRENT_ASSET', '1000', 2, true),
	('a63f67af-3646-4e37-93bf-803d5f27964f', 'F_AND_B', '1600', 'Fixed Assets', 'ASSET', 'FIXED_ASSET', '1000', 2, true),
	('475dcb19-289c-40ad-969d-746f9ffa8c3e', 'F_AND_B', '1610', 'Furniture & Fixtures', 'ASSET', 'FIXED_ASSET', '1600', 3, true),
	('e640663b-8816-4db7-b10b-80cd7b309c04', 'F_AND_B', '1620', 'Computer Equipment', 'ASSET', 'FIXED_ASSET', '1600', 3, true),
	('221ca02a-e0c6-4052-b0cf-3345e6f66ac6', 'F_AND_B', '1690', 'Accumulated Depreciation', 'ASSET', 'FIXED_ASSET', '1000', 2, true),
	('bd97e8e8-16ae-4305-8233-e6a4eec52616', 'F_AND_B', '2000', 'Liabilities', 'LIABILITY', NULL, NULL, 1, true),
	('2a8a14e6-cc71-46f8-89aa-5eea2a4298e9', 'F_AND_B', '2010', 'Accounts Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('b6e0c172-3d7b-41d7-acd5-a8c87c4883c9', 'F_AND_B', '2020', 'CGST Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('0b25bce7-1548-453f-8a1a-7a63d43553f0', 'F_AND_B', '2021', 'SGST Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('95becaf0-e3d8-44b9-af14-4f7c54f6412c', 'F_AND_B', '2022', 'IGST Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('a1e44cd2-2342-4ce6-925f-99d767bc02e0', 'F_AND_B', '2030', 'TDS Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('26ad0263-e2af-4466-b218-097bce7eb312', 'F_AND_B', '2040', 'Salary Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('c3ad226f-3f29-48bb-93e4-a53e3ea18e5c', 'F_AND_B', '2050', 'PF Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('1b717a2a-4ea0-4a21-b03e-95152a755513', 'F_AND_B', '2060', 'ESI Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('0dce7ddd-b438-4f06-bdc2-f86b71f8bff6', 'F_AND_B', '2070', 'Professional Tax Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('4fff7a1e-a598-4317-82c1-79d3c8a0e3ae', 'F_AND_B', '2100', 'Advance from Customers', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('f13ed191-a6fe-4485-8f42-6cb2c4cc26fb', 'F_AND_B', '2200', 'Accrued Expenses', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('8e4cd301-8f3d-4e23-8e4a-b6e68d9884b8', 'F_AND_B', '2500', 'Long-term Loans', 'LIABILITY', 'LONG_TERM_LIABILITY', '2000', 2, true),
	('7faa8f6b-0af5-4c4d-8a18-077dd1e15bf3', 'F_AND_B', '3000', 'Equity', 'EQUITY', NULL, NULL, 1, true),
	('8619f10f-9611-4b88-9894-a36087ef2b6d', 'F_AND_B', '3010', 'Owner Capital', 'EQUITY', 'OWNERS_EQUITY', '3000', 2, true),
	('5fe75a53-c442-4973-a920-b5be519b7368', 'F_AND_B', '3020', 'Retained Earnings', 'EQUITY', 'RETAINED_EARNINGS', '3000', 2, true),
	('82e34ba1-765d-4af5-aa73-eb24e952d682', 'F_AND_B', '3030', 'Drawings', 'EQUITY', 'DRAWINGS', '3000', 2, true),
	('c798bbd0-ac6f-4c41-9eaa-27681d4dc886', 'F_AND_B', '4000', 'Revenue', 'REVENUE', NULL, NULL, 1, true),
	('b0cbc129-205c-4103-a18a-86b8974f229d', 'F_AND_B', '4010', 'Sales Revenue', 'REVENUE', 'OPERATING_REVENUE', '4000', 2, true),
	('fa208867-5e86-481b-ad5a-96b3243202ad', 'F_AND_B', '4020', 'Service Revenue', 'REVENUE', 'OPERATING_REVENUE', '4000', 2, true),
	('9f30cfe0-75bb-47ee-9fd5-2babe6b01df1', 'F_AND_B', '4100', 'Other Income', 'REVENUE', 'OTHER_INCOME', '4000', 2, true),
	('f8dc748c-bcf7-4854-979f-f64ec043212c', 'F_AND_B', '4110', 'Interest Income', 'REVENUE', 'OTHER_INCOME', '4100', 3, true),
	('cdd63a8f-4166-4f07-8dfe-fcab3502dc01', 'F_AND_B', '4120', 'Discount Received', 'REVENUE', 'OTHER_INCOME', '4100', 3, true);
INSERT INTO public.coa_template VALUES
	('3b828233-3b02-4f46-9ecc-302f896f669b', 'F_AND_B', '5000', 'Expenses', 'EXPENSE', NULL, NULL, 1, true),
	('3424e90a-8a3d-4f77-9086-7fe19de6acb9', 'F_AND_B', '5010', 'Cost of Goods Sold', 'EXPENSE', 'COGS', '5000', 2, true),
	('629bae18-b44f-44e2-8cfb-700e57c53da8', 'F_AND_B', '5020', 'Purchase Expense', 'EXPENSE', 'COGS', '5000', 2, true),
	('33819219-3de6-4030-bb66-ce6232d13b79', 'F_AND_B', '5100', 'Salary Expense', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('4aeb28a1-1635-4506-ad68-4e737c6a3a9a', 'F_AND_B', '5110', 'Employer PF Contribution', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('3691600e-0d48-4bfc-8c99-f4c08b278efd', 'F_AND_B', '5120', 'Employer ESI Contribution', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('c4b24fce-f8fd-4996-9927-2d3b0badca9b', 'F_AND_B', '5200', 'Rent Expense', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('5d5a5bb9-af31-4002-b269-2d5f17990aca', 'F_AND_B', '5210', 'Utilities', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('64f1e529-c494-4c91-8704-46df48a452a8', 'F_AND_B', '5220', 'Office Supplies', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('8073886b-e62a-41f9-94db-64e32de115b5', 'F_AND_B', '5230', 'Telephone & Internet', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('ce2697f3-2ab7-438a-9d6f-5615be8f1ad9', 'F_AND_B', '5240', 'Travel & Conveyance', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('3ac48c4a-b36a-41d8-b031-2f92d097737f', 'F_AND_B', '5250', 'Insurance', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('044cf667-cd50-4a3c-bc63-796fa910b3a0', 'F_AND_B', '5260', 'Legal & Professional Fees', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('6548dd32-9a31-443d-b7a2-549b17d2d9fa', 'F_AND_B', '5270', 'Depreciation Expense', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('e2a1462b-75ff-4615-8aab-801b8b27e0b4', 'F_AND_B', '5280', 'Bank Charges', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('df3bc3bb-3fdf-41e5-8422-75936128b142', 'F_AND_B', '5290', 'Discount Allowed', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('1227717c-5a78-4db4-a866-0d7bb762c66a', 'F_AND_B', '5300', 'Miscellaneous Expense', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('846c6d52-6d93-49a8-9e4a-73389b94b980', 'F_AND_B', '5400', 'Inventory Loss/Shrinkage', 'EXPENSE', 'OPERATING_EXPENSE', '5000', 2, true),
	('7e83bcb4-3443-46af-9bb1-29edbf811ad8', 'F_AND_B', '5500', 'Forex Gain/Loss', 'EXPENSE', 'OTHER_EXPENSE', '5000', 2, true),
	('7baac0e2-4b42-4a7b-8269-4e9fcd176572', 'F_AND_B', '5600', 'Rounding Adjustment', 'EXPENSE', 'OTHER_EXPENSE', '5000', 2, true),
	('3283c807-4b51-4602-bcee-23fa495c54b1', 'TRADING', '3040', 'Opening Balance Equity', 'EQUITY', 'OWNERS_EQUITY', '3000', 2, true),
	('7202eb11-bc55-423d-99cf-1ac87b6fd92a', 'SERVICES', '2031', 'TCS Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('7233be2d-3e48-4006-af2c-0b3ee6c4a38d', 'RETAIL', '2031', 'TCS Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('67de0ce8-1756-42a8-9bac-94f528956128', 'TRADING', '2031', 'TCS Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('e3246f00-9fb0-4fae-b5cb-0fd2038fe54f', 'F_AND_B', '2031', 'TCS Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
	('cb3611a6-6b66-4a79-a960-b2d5e134233c', 'TRADING', '1210', 'Work-In-Progress', 'ASSET', 'CURRENT_ASSET', NULL, 2, true),
	('9336aa25-e3df-4a41-bab1-295f73c5622a', 'TRADING', '5030', 'Manufacturing Overhead', 'EXPENSE', 'COGS', NULL, 2, true),
	('19c09f10-ced4-48f4-8edc-69c0fe04401e', 'TRADING', '5040', 'Direct Labor', 'EXPENSE', 'COGS', NULL, 2, true),
	('772b4a03-a65e-4666-a464-29e0aeb52f6b', 'TRADING', '5050', 'Material Variance', 'EXPENSE', 'COGS', NULL, 2, true);

--
-- Data for Name: warehouse; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: consignment_stock; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: consignment_settlement; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: contact_person; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: cost_lot; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: cost_lot_consumption; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: credit_note; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: supplier; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: stock_batch; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: credit_note_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: currency; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.currency VALUES
	('17399dd7-9086-40cf-bfbb-e47500f4df07', 'INR', 'Indian Rupee', '₹', 2, true),
	('4d7b44b1-fb7a-421b-b27b-5e3a03f9bc5f', 'USD', 'US Dollar', '$', 2, true),
	('19655df8-5744-404a-9ccf-9a0f78a18f00', 'EUR', 'Euro', '€', 2, true),
	('9878034d-53cf-450d-9724-26db7da22c86', 'GBP', 'British Pound', '£', 2, true),
	('c72f19e6-2213-4b6f-bc71-c3931f9367a1', 'AED', 'UAE Dirham', 'د.إ', 2, true),
	('391b0be6-920d-43c2-b192-e48c9977e017', 'SGD', 'Singapore Dollar', 'S$', 2, true),
	('1bc1601a-8371-4423-9378-b0e0e3702287', 'JPY', 'Japanese Yen', '¥', 0, true),
	('1ad70b04-1998-4402-b7c8-e2916e4a72f3', 'AUD', 'Australian Dollar', 'A$', 2, true),
	('090d4747-9756-4dee-83c7-ce86929289e0', 'CAD', 'Canadian Dollar', 'C$', 2, true),
	('ee911a97-a8ea-4ad8-b33e-109fc58428db', 'CHF', 'Swiss Franc', 'Fr', 2, true);

--
-- Data for Name: customer_wallet; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: route; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: van; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: route_execution; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: day_close; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: dcr_report; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: debit_note; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: debit_note_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: delegated_access_token; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: estimate; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: sales_order; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: delivery_challan; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: sales_order_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: delivery_challan_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: demand_forecast; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: document_state_config; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: domain_event; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: domain_events; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: salt_master; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.salt_master VALUES
	('5f40d97e-0c74-4d38-895a-645462f6558c', 'Paracetamol', 'Analgesic/NSAID', '2026-06-12 15:36:21.616872+00'),
	('71642ef1-fb08-4b96-89c7-e0e85fd55a1c', 'Ibuprofen', 'Analgesic/NSAID', '2026-06-12 15:36:21.616872+00'),
	('ae12d15c-14c1-4aad-a976-daad630ac9b3', 'Diclofenac Sodium', 'Analgesic/NSAID', '2026-06-12 15:36:21.616872+00'),
	('d76bccf6-4b49-4017-b3bb-9204060d03c4', 'Nimesulide', 'Analgesic/NSAID', '2026-06-12 15:36:21.616872+00'),
	('a82353e4-bd5c-4235-8d8a-c1395385c995', 'Aceclofenac', 'Analgesic/NSAID', '2026-06-12 15:36:21.616872+00'),
	('7e59ef70-d4ca-4fb9-901e-b1ea60b695ad', 'Aspirin', 'Analgesic/NSAID', '2026-06-12 15:36:21.616872+00'),
	('22c8157d-5c6d-45b2-9359-2f621ab2471d', 'Tramadol HCl', 'Analgesic/NSAID', '2026-06-12 15:36:21.616872+00'),
	('52aea09d-29f2-43fb-a2b6-f8ef278a96c7', 'Ketorolac Tromethamine', 'Analgesic/NSAID', '2026-06-12 15:36:21.616872+00'),
	('1934bc66-459d-425d-bd67-e9a86670fe2d', 'Naproxen', 'Analgesic/NSAID', '2026-06-12 15:36:21.616872+00'),
	('0864800f-581b-4296-a5a5-3a6ceba38049', 'Mefenamic Acid', 'Analgesic/NSAID', '2026-06-12 15:36:21.616872+00'),
	('75543c99-1ff5-41f7-b7a1-94b8a0656c37', 'Amoxicillin', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('7121615e-b01c-43d1-95cd-83a866816266', 'Amoxicillin+Clavulanic Acid', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('55786ce1-26ae-4847-b5a6-ae94bf0322fb', 'Azithromycin', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('1af5a9c7-cc5b-44f4-bd2d-a613a30d343b', 'Ciprofloxacin HCl', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('b4495d8d-1049-4586-a1b6-c6f900576151', 'Doxycycline HCl', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('5145eac4-9a7e-4c87-ae4b-b07d92c4b0bb', 'Metronidazole', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('4265bc8f-d41d-4449-9a59-d2ddb69e3664', 'Cefixime', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('464cb5e7-92cd-4d4f-a0b5-5d108f7381f3', 'Cephalexin', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('d8132646-dd0e-4611-8af5-83cf1c3c0c77', 'Clindamycin', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('8b1fcf6e-cee6-479e-af5d-c28060b7ac56', 'Levofloxacin', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('b35104c9-3bc7-4789-b3ca-fba6ec95a2c9', 'Ofloxacin', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('a5264fd9-3597-41e9-b954-c199a82a0618', 'Erythromycin', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('d3ff35b2-7d28-430e-addf-d3da8be37e00', 'Cefpodoxime', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('c59ece1a-28e2-4a51-86f1-00db1a684c35', 'Cefuroxime', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('065c9a10-7775-423c-8c02-53232694932a', 'Ampicillin', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('f6e815a4-6df7-4ce4-b251-570794fba009', 'Tetracycline', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('1d528045-2e25-446a-af77-425c4120a71b', 'Co-trimoxazole', 'Antibiotic', '2026-06-12 15:36:21.616872+00'),
	('766a6b24-4ed1-458e-9c8c-0e62b5f3e2be', 'Omeprazole', 'Antacid/PPI', '2026-06-12 15:36:21.616872+00'),
	('6d4b13a0-6c32-45e1-85ff-650a5c356d6e', 'Pantoprazole Sodium', 'Antacid/PPI', '2026-06-12 15:36:21.616872+00'),
	('f6599bad-8149-45a0-91bb-11148e16e949', 'Rabeprazole Sodium', 'Antacid/PPI', '2026-06-12 15:36:21.616872+00'),
	('d42bf8b0-df49-4ef0-bb92-383bcb56c664', 'Esomeprazole Magnesium', 'Antacid/PPI', '2026-06-12 15:36:21.616872+00'),
	('56dd655b-5099-41ce-b172-f5bff7222269', 'Lansoprazole', 'Antacid/PPI', '2026-06-12 15:36:21.616872+00'),
	('97875981-850a-4f77-914a-fdbbe3c69c8c', 'Ranitidine HCl', 'Antacid/PPI', '2026-06-12 15:36:21.616872+00'),
	('da51b2a4-5340-4cd7-bcf1-ec001e01dc1c', 'Famotidine', 'Antacid/PPI', '2026-06-12 15:36:21.616872+00'),
	('38aa8c76-24e9-4abb-aeff-340deff5a7ab', 'Domperidone', 'Antacid/PPI', '2026-06-12 15:36:21.616872+00'),
	('5db455ba-ba5e-44df-917d-a6aebebfda44', 'Ondansetron HCl', 'Antacid/PPI', '2026-06-12 15:36:21.616872+00'),
	('f730c971-2443-4a5b-abbf-5a65a3e1a56d', 'Metoclopramide HCl', 'Antacid/PPI', '2026-06-12 15:36:21.616872+00'),
	('e9c58cb4-58c0-4dd2-959a-b2a73dab0205', 'Sucralfate', 'Antacid/PPI', '2026-06-12 15:36:21.616872+00'),
	('41fdbeae-ec17-41cc-84ba-040b488a70dd', 'Cetirizine HCl', 'Antihistamine', '2026-06-12 15:36:21.616872+00'),
	('54071a12-7461-47d0-823f-c7c87773cf3d', 'Levocetirizine HCl', 'Antihistamine', '2026-06-12 15:36:21.616872+00'),
	('d7a717d9-52d2-44fb-9afa-b561e86958a7', 'Fexofenadine HCl', 'Antihistamine', '2026-06-12 15:36:21.616872+00'),
	('a89426bf-b02f-40c8-9832-a86b9c83b7a6', 'Loratadine', 'Antihistamine', '2026-06-12 15:36:21.616872+00'),
	('3c7084d2-edf1-4689-8501-1f576f0973b4', 'Desloratadine', 'Antihistamine', '2026-06-12 15:36:21.616872+00'),
	('eca21dc9-6ffb-4354-894c-829a66755e3b', 'Chlorpheniramine Maleate', 'Antihistamine', '2026-06-12 15:36:21.616872+00'),
	('3774c1bd-293b-4881-94f7-edd952cfae2a', 'Hydroxyzine HCl', 'Antihistamine', '2026-06-12 15:36:21.616872+00'),
	('2209ba14-87ff-4abd-a090-9fbc51b540fd', 'Montelukast Sodium', 'Antihistamine', '2026-06-12 15:36:21.616872+00'),
	('5d627610-1267-4dea-87de-a51197c1d0a4', 'Bilastine', 'Antihistamine', '2026-06-12 15:36:21.616872+00'),
	('57223352-afb9-4116-9097-6438efcc8357', 'Metformin HCl', 'Antidiabetic', '2026-06-12 15:36:21.616872+00'),
	('38456591-4a1b-4cff-abca-311663f965a0', 'Glibenclamide', 'Antidiabetic', '2026-06-12 15:36:21.616872+00'),
	('a5524af1-ff29-442b-858b-837562592572', 'Gliclazide', 'Antidiabetic', '2026-06-12 15:36:21.616872+00'),
	('075d8268-1a17-4ba8-831f-36e35331685a', 'Glimepiride', 'Antidiabetic', '2026-06-12 15:36:21.616872+00'),
	('797e4470-13db-467e-a7d7-29230bf4ea53', 'Glipizide', 'Antidiabetic', '2026-06-12 15:36:21.616872+00'),
	('210364ff-948d-4721-adbc-e60f05a6e1f8', 'Sitagliptin Phosphate', 'Antidiabetic', '2026-06-12 15:36:21.616872+00'),
	('562708f4-fc58-473c-8cd6-4cd482653130', 'Vildagliptin', 'Antidiabetic', '2026-06-12 15:36:21.616872+00'),
	('087a9468-d100-4d84-8ce6-296825765f6c', 'Dapagliflozin', 'Antidiabetic', '2026-06-12 15:36:21.616872+00'),
	('8a6de9cf-49b4-454b-b512-228222d1ae5a', 'Empagliflozin', 'Antidiabetic', '2026-06-12 15:36:21.616872+00'),
	('df8f5e3c-3d0b-41eb-8d3d-21d3383fbd1b', 'Teneligliptin', 'Antidiabetic', '2026-06-12 15:36:21.616872+00'),
	('a842f80d-9441-4a30-8c01-d24efad8d4cf', 'Insulin Regular', 'Antidiabetic', '2026-06-12 15:36:21.616872+00'),
	('5f479137-3b83-4383-b26d-8c479158d5a7', 'Insulin NPH', 'Antidiabetic', '2026-06-12 15:36:21.616872+00'),
	('7d0d8df1-f7b3-448a-aed9-0ce83191dc76', 'Amlodipine Besylate', 'Antihypertensive', '2026-06-12 15:36:21.616872+00'),
	('f5cfe193-a2ec-4c39-9314-921399f56932', 'Atenolol', 'Antihypertensive', '2026-06-12 15:36:21.616872+00'),
	('bf96342a-4d7d-468c-be97-769b505b687c', 'Losartan Potassium', 'Antihypertensive', '2026-06-12 15:36:21.616872+00'),
	('6fce570f-5ef1-4c2d-a5bc-6399c9f6a860', 'Telmisartan', 'Antihypertensive', '2026-06-12 15:36:21.616872+00'),
	('44bebb2b-b61c-4ed1-8030-d49519455ece', 'Enalapril Maleate', 'Antihypertensive', '2026-06-12 15:36:21.616872+00'),
	('e8c4a0a9-c28d-4e1d-9e9f-e110b89b5b1a', 'Ramipril', 'Antihypertensive', '2026-06-12 15:36:21.616872+00'),
	('f335ae02-2f9a-4f27-8efe-f00409d19614', 'Lisinopril', 'Antihypertensive', '2026-06-12 15:36:21.616872+00'),
	('b674433c-92c7-432c-9fdd-b40825a7fc65', 'Metoprolol Succinate', 'Antihypertensive', '2026-06-12 15:36:21.616872+00'),
	('79312bd6-d51f-492e-ba36-e62fc9ed5ddc', 'Carvedilol', 'Antihypertensive', '2026-06-12 15:36:21.616872+00'),
	('f1af0779-8084-439b-bc9b-aef2a32583a8', 'Nebivolol HCl', 'Antihypertensive', '2026-06-12 15:36:21.616872+00'),
	('465cd109-27d5-45e8-930e-b2384de7dcb5', 'Hydrochlorothiazide', 'Antihypertensive', '2026-06-12 15:36:21.616872+00'),
	('317d7b70-44c7-4292-b96f-15563327d4cc', 'Furosemide', 'Antihypertensive', '2026-06-12 15:36:21.616872+00'),
	('29ee6163-5fdc-4a09-a9ba-5d57d02437ec', 'Spironolactone', 'Antihypertensive', '2026-06-12 15:36:21.616872+00'),
	('67a80925-3242-46fb-b7f1-c1e6c5e6aba7', 'Olmesartan Medoxomil', 'Antihypertensive', '2026-06-12 15:36:21.616872+00'),
	('7cef8659-5c84-4e2d-9d6f-a7e2df9214cd', 'Valsartan', 'Antihypertensive', '2026-06-12 15:36:21.616872+00'),
	('9db1715a-884c-40bd-8664-069a5d9a4d12', 'Atorvastatin Calcium', 'Lipid-lowering', '2026-06-12 15:36:21.616872+00'),
	('92a4fcba-09e2-47c6-951f-d0d34865bcc5', 'Rosuvastatin Calcium', 'Lipid-lowering', '2026-06-12 15:36:21.616872+00'),
	('8ca073fb-24ab-4ab4-8c21-e0edd9f63283', 'Simvastatin', 'Lipid-lowering', '2026-06-12 15:36:21.616872+00'),
	('2827b69f-4f2c-47e5-ad56-e6e410659c40', 'Fenofibrate', 'Lipid-lowering', '2026-06-12 15:36:21.616872+00'),
	('cd60d98f-5547-4812-a829-782de7aa5e50', 'Ezetimibe', 'Lipid-lowering', '2026-06-12 15:36:21.616872+00'),
	('577f9b1a-aafd-478f-88af-336775e97515', 'Salbutamol Sulphate', 'Respiratory', '2026-06-12 15:36:21.616872+00'),
	('78e333e9-0baf-40f7-8d28-e22f3b939e3e', 'Theophylline', 'Respiratory', '2026-06-12 15:36:21.616872+00'),
	('85714ca0-1b46-4dc8-a526-54d3b5b6ab26', 'Budesonide', 'Respiratory', '2026-06-12 15:36:21.616872+00'),
	('799ea644-fcb3-453e-870b-80cbb4b5bb76', 'Formoterol Fumarate', 'Respiratory', '2026-06-12 15:36:21.616872+00'),
	('54e2afd1-aeff-44c3-b455-894d235839a6', 'Tiotropium Bromide', 'Respiratory', '2026-06-12 15:36:21.616872+00'),
	('80a3a1b1-48c5-48bf-bfd7-0bec1f51630e', 'Bromhexine HCl', 'Respiratory', '2026-06-12 15:36:21.616872+00'),
	('87f74373-223d-426d-9746-19aef4917961', 'Ambroxol HCl', 'Respiratory', '2026-06-12 15:36:21.616872+00'),
	('91c83c5b-a1e9-4f4a-bc29-fc5224015440', 'Dextromethorphan HBr', 'Respiratory', '2026-06-12 15:36:21.616872+00'),
	('d8a95cbf-9aa0-4a98-9c5d-7adb4efbe90b', 'Levosalbutamol Sulphate', 'Respiratory', '2026-06-12 15:36:21.616872+00'),
	('431611a5-5f6a-4237-b233-1320daa6a712', 'Ipratropium Bromide', 'Respiratory', '2026-06-12 15:36:21.616872+00'),
	('b6093fab-b202-413a-ad74-b2c042eca734', 'Vitamin D3', 'Vitamin/Supplement', '2026-06-12 15:36:21.616872+00'),
	('0bf94773-d112-4adc-b183-121deeb13dc2', 'Vitamin B12', 'Vitamin/Supplement', '2026-06-12 15:36:21.616872+00'),
	('b20dd2a8-554a-44e2-9ac1-304f43b04310', 'Folic Acid', 'Vitamin/Supplement', '2026-06-12 15:36:21.616872+00'),
	('19632a2d-6c8a-46a9-a168-9c396eb66add', 'Ferrous Sulphate', 'Vitamin/Supplement', '2026-06-12 15:36:21.616872+00'),
	('c7fed11e-4c7e-49b3-aacc-ef5ff4edd1d0', 'Calcium Carbonate', 'Vitamin/Supplement', '2026-06-12 15:36:21.616872+00'),
	('d1c96ba6-6df3-4582-a80d-136234a7be8c', 'Zinc Sulphate', 'Vitamin/Supplement', '2026-06-12 15:36:21.616872+00'),
	('c78c0b09-38e9-4379-b0d8-608f20d46fc4', 'Vitamin C', 'Vitamin/Supplement', '2026-06-12 15:36:21.616872+00'),
	('de969ab3-bdd8-4833-9e56-c7c7e9843d78', 'Multivitamin', 'Vitamin/Supplement', '2026-06-12 15:36:21.616872+00'),
	('80f3f3dd-0ec6-4c5e-9f21-5a1650b13259', 'Thiamine HCl', 'Vitamin/Supplement', '2026-06-12 15:36:21.616872+00'),
	('0854317e-d5ec-4369-a2b2-a59996ffe38e', 'Pyridoxine HCl', 'Vitamin/Supplement', '2026-06-12 15:36:21.616872+00'),
	('d4d149c9-4aeb-4c40-9e22-a544063b1879', 'Riboflavin', 'Vitamin/Supplement', '2026-06-12 15:36:21.616872+00'),
	('e6aaaf85-0dc1-432a-9c08-8c18dbadec9a', 'Pregabalin', 'Neuro/Antiepileptic', '2026-06-12 15:36:21.616872+00'),
	('afc84440-84d7-48f0-96e0-86a3283aefe6', 'Gabapentin', 'Neuro/Antiepileptic', '2026-06-12 15:36:21.616872+00'),
	('07e7589d-98d9-492c-937c-5efba3c2869c', 'Levetiracetam', 'Neuro/Antiepileptic', '2026-06-12 15:36:21.616872+00'),
	('97444490-d399-4fcf-b4f9-dd167b30efaa', 'Phenytoin Sodium', 'Neuro/Antiepileptic', '2026-06-12 15:36:21.616872+00'),
	('b33f8db2-edfb-4f1f-862c-6bce037d8fc3', 'Carbamazepine', 'Neuro/Antiepileptic', '2026-06-12 15:36:21.616872+00'),
	('0a7b5d29-41ca-4211-ab7e-a50a70446184', 'Valproate Sodium', 'Neuro/Antiepileptic', '2026-06-12 15:36:21.616872+00'),
	('8513cabc-3f29-49e2-ae95-7e154749cd61', 'Lamotrigine', 'Neuro/Antiepileptic', '2026-06-12 15:36:21.616872+00'),
	('0eef57f8-85d6-4e0e-9b68-676992b33de2', 'Clonazepam', 'Neuro/Antiepileptic', '2026-06-12 15:36:21.616872+00'),
	('3d6b896e-e659-4170-975b-b10e7dcf0010', 'Alprazolam', 'Neuro/Antiepileptic', '2026-06-12 15:36:21.616872+00'),
	('7c1b6b21-fe5b-4c50-8652-447457a60e74', 'Diazepam', 'Neuro/Antiepileptic', '2026-06-12 15:36:21.616872+00'),
	('9a1e08c1-210a-48d1-b249-20262b56a4fd', 'Zolpidem Tartrate', 'Neuro/Antiepileptic', '2026-06-12 15:36:21.616872+00'),
	('853ad850-1b55-472e-9add-d94726df11c5', 'Sertraline HCl', 'Antidepressant', '2026-06-12 15:36:21.616872+00'),
	('585511b8-6bef-4e18-b785-c831b7fd74c8', 'Escitalopram Oxalate', 'Antidepressant', '2026-06-12 15:36:21.616872+00'),
	('6f1093bf-058b-4fe2-bd29-08a43eae0512', 'Fluoxetine HCl', 'Antidepressant', '2026-06-12 15:36:21.616872+00'),
	('c21a5d90-1c4a-4602-ae5f-90c88d500ed4', 'Amitriptyline HCl', 'Antidepressant', '2026-06-12 15:36:21.616872+00'),
	('07011b9a-4cee-4305-a003-8a45b14cc81c', 'Venlafaxine HCl', 'Antidepressant', '2026-06-12 15:36:21.616872+00'),
	('d39a574e-45cb-4fad-90d4-67ed9fa6559f', 'Duloxetine HCl', 'Antidepressant', '2026-06-12 15:36:21.616872+00'),
	('58d0c587-a7d0-4523-af7b-31c009e79552', 'Mirtazapine', 'Antidepressant', '2026-06-12 15:36:21.616872+00'),
	('228a3503-9b4d-4cab-977f-784f6b7e3956', 'Levothyroxine Sodium', 'Thyroid', '2026-06-12 15:36:21.616872+00'),
	('27dc64ea-bc85-4524-900f-82dd6c7dc21b', 'Carbimazole', 'Thyroid', '2026-06-12 15:36:21.616872+00'),
	('934c5ff6-1f76-450c-88d9-f28668196713', 'Propylthiouracil', 'Thyroid', '2026-06-12 15:36:21.616872+00'),
	('9f7d7d83-a473-4af7-a876-4cdf34436ddf', 'Fluconazole', 'Antifungal', '2026-06-12 15:36:21.616872+00'),
	('5fbb8d2f-1cd2-40d4-b103-fecc0094e201', 'Itraconazole', 'Antifungal', '2026-06-12 15:36:21.616872+00'),
	('bdcf6ffd-b6e4-489e-9669-16bb5107f39a', 'Clotrimazole', 'Antifungal', '2026-06-12 15:36:21.616872+00'),
	('f53f6906-8c24-4336-9701-5661f3ab73e7', 'Terbinafine HCl', 'Antifungal', '2026-06-12 15:36:21.616872+00'),
	('bd959c95-82bc-41eb-978f-a343b9876603', 'Ketoconazole', 'Antifungal', '2026-06-12 15:36:21.616872+00'),
	('62f9c66e-e0c1-4e9d-ba62-e743730a94c2', 'Acyclovir', 'Antiviral', '2026-06-12 15:36:21.616872+00'),
	('99e2d843-d4aa-48db-aa1a-124789517e7b', 'Oseltamivir Phosphate', 'Antiviral', '2026-06-12 15:36:21.616872+00'),
	('7eaa1370-98d3-4f74-a2a3-b884f466aa4a', 'Tenofovir', 'Antiviral', '2026-06-12 15:36:21.616872+00'),
	('50b530c2-5668-4a0e-b969-8cb35f5c7734', 'Lamivudine', 'Antiviral', '2026-06-12 15:36:21.616872+00'),
	('ebb5e645-f162-47c4-8732-51f3b680fb68', 'Betamethasone Valerate', 'Dermatological', '2026-06-12 15:36:21.616872+00'),
	('0ee2978b-8d47-4138-a690-47286ab67d1a', 'Mupirocin', 'Dermatological', '2026-06-12 15:36:21.616872+00'),
	('3a909368-8099-4b38-88c6-56aa7a6e27f1', 'Calamine', 'Dermatological', '2026-06-12 15:36:21.616872+00'),
	('4e429052-13c3-4a07-881c-0b799675ff2e', 'Permethrin', 'Dermatological', '2026-06-12 15:36:21.616872+00'),
	('6301e7bc-280c-4e8b-8c83-4676c259a5cd', 'Hydrocortisone', 'Dermatological', '2026-06-12 15:36:21.616872+00'),
	('c6fad96a-dcc4-4b0b-a82c-db844f866379', 'Clobetasol Propionate', 'Dermatological', '2026-06-12 15:36:21.616872+00'),
	('ee4111f7-677f-4e17-ba04-363aed1ca179', 'Mometasone Furoate', 'Dermatological', '2026-06-12 15:36:21.616872+00'),
	('61698832-44a1-4b79-ac47-14e5936a4477', 'Loperamide HCl', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('9302b66a-60c8-4228-884c-f74772c635db', 'Albendazole', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('6a61bc46-db31-4eb1-87b2-18cceecff61e', 'Mebendazole', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('6814eda8-ddcb-44a7-a4b0-de0ff4c9b6a8', 'Ivermectin', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('b431f7cb-2621-4c68-9eed-520c4bc20c01', 'Lactulose', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('45fba3d0-5369-49eb-946e-e418219cd89d', 'Bisacodyl', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('b9f19970-f33d-4042-a4ab-8474270ad0a1', 'Tamsulosin HCl', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('ad1dfcb0-d8af-437b-be8b-610b80596a52', 'Sildenafil Citrate', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('3d962846-5816-4499-a8df-b3473a270524', 'Tadalafil', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('34ecc33d-50cd-45a1-8602-37cda5dc07a4', 'Progesterone', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('d18b2e10-c952-4647-b339-b42bc0cc17b1', 'Mifepristone', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('603c53c9-8623-4714-baac-98cc89810efe', 'Methylprednisolone', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('9c7482a4-45b2-420a-b30a-24939765b139', 'Prednisolone', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('0448b341-175c-4ae7-a72e-31f7ee94e0e5', 'Dexamethasone', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('ef21308e-1514-49dd-8cc4-134a249a7426', 'Colchicine', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('ce950b2e-6659-4808-8dca-ecb5fc6898ba', 'Allopurinol', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('bd475a71-c35d-49c5-9227-dcbc47bfe925', 'Hydroxychloroquine Sulphate', 'GI/Other', '2026-06-12 15:36:21.616872+00'),
	('466886a0-ec19-4e57-9a90-4f8e6799e6ac', 'Eschscholtzia Cali.,Lupulus Q,Passiflora Incarnata Q,ZincumMetallicum 6x,Purified water q.s', NULL, '2026-06-12 15:36:22.208871+00'),
	('b59913b3-89d7-49f9-8ebb-0c4b948e4d35', 'Ferrum lacticum 1X, Ammonium acetate 1X, Natrum phosphoricum 1X, Kalium phosphoricum 1X, Citric acid 1X, Acid phosphoricum 1X', NULL, '2026-06-12 15:36:22.208871+00'),
	('5280f048-3a33-4c2b-8408-f80b89292054', 'Potassium iodide,Sodium chloride,Calcium chloride', NULL, '2026-06-12 15:36:22.208871+00'),
	('4e52e18f-9f9f-4653-83b9-192e3e66c1ac', 'Clotrimazole IP 1% w/w,Talc 52.25 - ,Starch 35.0-50.0,Cabosil 0.15-0.22,Perfume 0.75-1.0', NULL, '2026-06-12 15:36:22.208871+00'),
	('e26904f6-91a3-447c-830a-e0438654d681', 'Calcium carbonate from an organic source Equivalent to Elemental Calcium , Chloecalciferol IP', NULL, '2026-06-12 15:36:22.208871+00'),
	('0f13a05f-dadb-4ed7-b25f-4b7b9c031d40', 'Elemental Calcium: ,Vitamin D3', NULL, '2026-06-12 15:36:22.208871+00'),
	('d6235bd5-460c-4f82-9054-c6826b06e89c', 'Sabal Serrulata,Echinacea Purpurea,Passiflora Incarnata,Cantharis,Mercurius Biliodatus,Excipients,Alcohol', NULL, '2026-06-12 15:36:22.208871+00'),
	('1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', NULL, '2026-06-12 15:36:22.208871+00'),
	('33768dba-848a-4366-9705-341393302716', 'Calcitriol + Calcium Carbonate + Zinc Sulfate', NULL, '2026-06-12 15:36:22.208871+00'),
	('afdf697d-a213-42c9-90d6-cae10ca69f16', 'Cucumber Demineralised Water', NULL, '2026-06-12 15:36:22.208871+00'),
	('a6d88451-781e-4cdb-8167-96dfe48aba2d', 'Demineralised Water Rose Petals', NULL, '2026-06-12 15:36:22.208871+00'),
	('db2ebda2-724b-43b8-af24-62703becf893', 'Diclofenac diethylamine Methyl salicylate Menthol', NULL, '2026-06-12 15:36:22.208871+00'),
	('94d3b646-c136-47f8-9eb4-4b054507cc69', 'Hyoscine butylbromide ,Paracetamol', NULL, '2026-06-12 15:36:22.208871+00'),
	('07c1490b-a3a5-4a45-b8d1-4219f95246eb', 'Crab Apple', NULL, '2026-06-12 15:36:22.208871+00'),
	('b6074f7c-a938-45b3-922d-286471279413', 'Aceclofenac + Paracetamol', 'NSAID/Analgesic', '2026-06-12 15:36:22.323271+00'),
	('3c8e9eb0-94aa-45b3-929c-43a7a728e982', 'Aceclofenac + Paracetamol + Serratiopeptidase', 'NSAID/Analgesic', '2026-06-12 15:36:22.323271+00'),
	('57c9c9f4-4944-4870-bc61-68712b84442f', 'Dicyclomine + Mefenamic Acid', 'Antispasmodic/NSAID', '2026-06-12 15:36:22.323271+00'),
	('a5f7674f-e9f2-4361-bf89-6979c7b780c7', 'Drotaverine', 'Antispasmodic', '2026-06-12 15:36:22.323271+00'),
	('20aa9ddb-4fdf-4039-92a1-041eeaf83dab', 'Drotaverine + Mefenamic Acid', 'Antispasmodic/NSAID', '2026-06-12 15:36:22.323271+00'),
	('af382bb9-1b07-48d1-9cfc-3302297651b2', 'Ketorolac', 'NSAID', '2026-06-12 15:36:22.323271+00'),
	('99c076f9-4df1-4935-8aa9-660e9cde228e', 'Ibuprofen + Paracetamol', 'NSAID/Analgesic', '2026-06-12 15:36:22.323271+00'),
	('1bc9ba5e-24b3-42e3-98cd-bb282f57d42d', 'Diclofenac Diethylamine', 'Topical Analgesic', '2026-06-12 15:36:22.323271+00'),
	('4a6cb36f-5be1-4018-b38f-1b9cf33aaf72', 'Methyl Salicylate + Menthol + Eucalyptus Oil', 'Topical Analgesic', '2026-06-12 15:36:22.323271+00'),
	('c4dfd4d3-bbe3-4b67-9927-fd6f6a72deef', 'Amoxicillin + Clavulanic Acid', 'Antibiotic', '2026-06-12 15:36:22.323271+00'),
	('70a52747-40b9-4f67-a111-ff699c9d0fcb', 'Cefuroxime Axetil', 'Antibiotic', '2026-06-12 15:36:22.323271+00'),
	('180e84dd-6f1a-46d9-9125-068d9905f5dd', 'Cefpodoxime Proxetil', 'Antibiotic', '2026-06-12 15:36:22.323271+00'),
	('813ed4ce-4190-4c3e-b04d-3a969ff59a85', 'Norfloxacin', 'Antibiotic', '2026-06-12 15:36:22.323271+00'),
	('0a7fa8d7-aef0-4888-b6cc-44ec6e8f7ae3', 'Norfloxacin + Tinidazole', 'Antibiotic/Antiprotozoal', '2026-06-12 15:36:22.323271+00'),
	('a8860914-3b3e-4bd1-9340-dca77aec5331', 'Doxycycline', 'Antibiotic', '2026-06-12 15:36:22.323271+00'),
	('2f77b0b9-eef7-460a-9f44-5229e4195a22', 'Linezolid', 'Antibiotic', '2026-06-12 15:36:22.323271+00'),
	('60d19b93-31bc-473a-886a-88bb35e0fee0', 'Pantoprazole', 'PPI/Antacid', '2026-06-12 15:36:22.323271+00'),
	('6e3de9c9-00e1-475a-9098-2fd98b81989e', 'Pantoprazole + Domperidone', 'PPI/Prokinetic', '2026-06-12 15:36:22.323271+00'),
	('a219f111-9720-400f-bc9a-c95650a699b8', 'Rabeprazole', 'PPI/Antacid', '2026-06-12 15:36:22.323271+00'),
	('4bfec7d4-2e2c-4dae-a571-3e37e9801909', 'Rabeprazole + Domperidone', 'PPI/Prokinetic', '2026-06-12 15:36:22.323271+00'),
	('2c9956c1-6ea0-4b37-8152-575593f66970', 'Omeprazole + Domperidone', 'PPI/Prokinetic', '2026-06-12 15:36:22.323271+00'),
	('c3780c63-1e02-49c3-ac9b-ccad1f725c4c', 'Esomeprazole', 'PPI/Antacid', '2026-06-12 15:36:22.323271+00'),
	('897e58f6-545c-47ed-9635-ade5f8ef05de', 'Esomeprazole + Domperidone', 'PPI/Prokinetic', '2026-06-12 15:36:22.323271+00'),
	('a496e3ba-02c1-42a0-8cd4-5cb4d98f5fe1', 'Itopride', 'Prokinetic', '2026-06-12 15:36:22.323271+00'),
	('6d55247f-c9ee-45be-8cf2-65f30c4a32af', 'Ondansetron', 'Antiemetic', '2026-06-12 15:36:22.323271+00'),
	('1a8f8a58-9619-4366-9791-5b1aac21abaa', 'Loperamide', 'Antidiarrheal', '2026-06-12 15:36:22.323271+00'),
	('0c070287-aa36-4466-83bf-bc8c36c8bb71', 'Liquid Paraffin + Milk of Magnesia + Sodium Picosulfate', 'Laxative', '2026-06-12 15:36:22.323271+00'),
	('56183e12-c728-4081-b459-f3ec9016ab12', 'Aluminium Hydroxide + Magnesium Hydroxide + Simethicone', 'Antacid', '2026-06-12 15:36:22.323271+00'),
	('0dcd188e-6623-4c22-a94a-98edfcb6ac79', 'Cetirizine', 'Antihistamine', '2026-06-12 15:36:22.323271+00'),
	('5e16b0cc-ee58-43d7-9304-61c152048b02', 'Levocetirizine', 'Antihistamine', '2026-06-12 15:36:22.323271+00'),
	('f67beb26-1ebd-434c-9811-f5a7fdfe359e', 'Fexofenadine', 'Antihistamine', '2026-06-12 15:36:22.323271+00'),
	('f9765289-2c90-422f-8072-cb331321ba0a', 'Montelukast + Levocetirizine', 'Anti-allergic/Respiratory', '2026-06-12 15:36:22.323271+00');
INSERT INTO public.salt_master VALUES
	('ec998f03-1caf-409a-b81d-9143b6d17123', 'Pheniramine Maleate', 'Antihistamine', '2026-06-12 15:36:22.323271+00'),
	('58e1745a-4b7c-4b40-a671-ef40baf7c8b4', 'Diphenhydramine + Ammonium Chloride + Sodium Citrate', 'Cough/Cold', '2026-06-12 15:36:22.323271+00'),
	('4b9cda13-aec8-4704-9860-eacaaf623410', 'Ambroxol + Levosalbutamol + Guaifenesin', 'Cough/Respiratory', '2026-06-12 15:36:22.323271+00'),
	('d50e3b83-4dc1-4a43-bab8-85c416bab58f', 'Phenylephrine + Chlorpheniramine + Dextromethorphan', 'Cough/Cold', '2026-06-12 15:36:22.323271+00'),
	('be54a07a-6ae0-4c96-b3d1-88637d4fd897', 'Chlorpheniramine + Dextromethorphan', 'Cough/Cold', '2026-06-12 15:36:22.323271+00'),
	('5b62efa7-8650-4340-9d2e-08fee0a66f75', 'Dextromethorphan + Chlorpheniramine + Phenylephrine', 'Cough/Cold', '2026-06-12 15:36:22.323271+00'),
	('ec06ced4-83bd-462d-9bab-09100bb4c1f5', 'Paracetamol + Phenylephrine + Chlorpheniramine', 'Cough/Cold', '2026-06-12 15:36:22.323271+00'),
	('6d9475ab-9094-4f59-8942-651057cdfe19', 'Paracetamol + Phenylephrine + Caffeine + Chlorpheniramine', 'Cough/Cold', '2026-06-12 15:36:22.323271+00'),
	('85264d95-fae4-4e00-b721-371ee88c33e1', 'Dextromethorphan + Phenylephrine + Chlorpheniramine', 'Cough/Cold', '2026-06-12 15:36:22.323271+00'),
	('29fe22f9-8534-4049-b817-51231edf9fe8', 'Dextromethorphan + Chlorpheniramine + Ammonium Chloride + Guaifenesin', 'Cough/Cold', '2026-06-12 15:36:22.323271+00'),
	('fcee7b74-2cf6-4080-88a7-5c22e0442b02', 'Metformin', 'Antidiabetic', '2026-06-12 15:36:22.323271+00'),
	('c6c0c4be-30d4-408c-80cb-4fe583cddea7', 'Glimepiride + Metformin', 'Antidiabetic', '2026-06-12 15:36:22.323271+00'),
	('7a2e72ce-8104-458c-ad34-51ab5174bbfb', 'Vildagliptin + Metformin', 'Antidiabetic', '2026-06-12 15:36:22.323271+00'),
	('fd0ca9bb-3771-4f92-87dc-4937957051d7', 'Sitagliptin', 'Antidiabetic', '2026-06-12 15:36:22.323271+00'),
	('db3931a3-385a-4a57-af1d-dfcc4f98c95d', 'Sitagliptin + Metformin', 'Antidiabetic', '2026-06-12 15:36:22.323271+00'),
	('ba86f5aa-702f-4d7a-a8e2-0463c9174445', 'Linagliptin', 'Antidiabetic', '2026-06-12 15:36:22.323271+00'),
	('73df2700-c750-4315-bef4-cb6cd321e446', 'Insulin Glargine', 'Insulin', '2026-06-12 15:36:22.323271+00'),
	('fb07adf3-6c18-4934-a2cf-2e2010f245de', 'Telmisartan + Amlodipine', 'Antihypertensive', '2026-06-12 15:36:22.323271+00'),
	('b271a586-8f80-4831-994c-639964809050', 'Amlodipine + Atenolol', 'Antihypertensive', '2026-06-12 15:36:22.323271+00'),
	('3cf74858-7993-4111-ba00-865a0f1323f8', 'Amlodipine', 'Antihypertensive', '2026-06-12 15:36:22.323271+00'),
	('1d085bc1-7e85-4dce-bd01-860abfd134ec', 'Bisoprolol', 'Antihypertensive', '2026-06-12 15:36:22.323271+00'),
	('b25104c2-ad9a-40c2-a986-31c1d8974eff', 'Metoprolol Tartrate', 'Antihypertensive', '2026-06-12 15:36:22.323271+00'),
	('53c602b9-ed49-4be3-ae74-c5e0090cf05c', 'Losartan', 'Antihypertensive', '2026-06-12 15:36:22.323271+00'),
	('cd19d245-9f95-4910-9ac4-68703152d1e3', 'Aspirin + Atorvastatin', 'Cardiovascular', '2026-06-12 15:36:22.323271+00'),
	('05e120ad-38d9-4f9e-9b25-8ff0c353af22', 'Clopidogrel', 'Antiplatelet', '2026-06-12 15:36:22.323271+00'),
	('2df96ef9-44b6-4ac8-a0da-89c3933e8bc7', 'Atorvastatin', 'Lipid-lowering', '2026-06-12 15:36:22.323271+00'),
	('d4a03a5a-3952-4c41-be0c-04dc4a4842a8', 'Rosuvastatin', 'Lipid-lowering', '2026-06-12 15:36:22.323271+00'),
	('72f68a43-6616-452d-886b-b1c4be9bfc54', 'Olmesartan', 'Antihypertensive', '2026-06-12 15:36:22.323271+00'),
	('c727bdc3-32af-4200-b6b7-6afbb31f3163', 'Calcium + Vitamin D3', 'Calcium/Vitamin', '2026-06-12 15:36:22.323271+00'),
	('1fd4003f-fd34-46d8-9255-75e606d28fc9', 'Calcium + Vitamin D3 + Minerals', 'Calcium/Vitamin', '2026-06-12 15:36:22.323271+00'),
	('863a90d7-7ce4-449f-af45-c7c3e3655c1c', 'Vitamin B Complex', 'Vitamin', '2026-06-12 15:36:22.323271+00'),
	('9f1971c0-cce6-4bfb-9f84-1cfdda77ed38', 'Vitamin B Complex + Zinc', 'Vitamin', '2026-06-12 15:36:22.323271+00'),
	('e2118331-d3d7-4e88-9979-b9ce3901edd3', 'Multivitamin + Multimineral', 'Vitamin', '2026-06-12 15:36:22.323271+00'),
	('10439d5f-ce04-464a-8911-31d4149c89e9', 'Multivitamin + Zinc', 'Vitamin', '2026-06-12 15:36:22.323271+00'),
	('42cc45e6-b6a9-4eae-b20f-53ec37d24f5a', 'Cholecalciferol', 'Vitamin D', '2026-06-12 15:36:22.323271+00'),
	('9e2e820f-6469-4334-9170-8f7553287223', 'Ferrous Ascorbate + Folic Acid', 'Iron/Folate', '2026-06-12 15:36:22.323271+00'),
	('c9f353c9-882e-439d-a405-8ef356b67b4c', 'Ferrous Fumarate + Folic Acid + Vitamin B12', 'Iron/Folate', '2026-06-12 15:36:22.323271+00'),
	('4d3159b5-b5a0-44c1-9e27-0e7c0d8bfc1c', 'Iron + Folic Acid + Vitamin B12', 'Iron/Folate', '2026-06-12 15:36:22.323271+00'),
	('48cd9338-164d-48bf-9640-33737ff5450c', 'Multivitamin + Ginseng + Minerals', 'Supplement', '2026-06-12 15:36:22.323271+00'),
	('6ed65d04-ccc7-4872-bc71-63ed7ec6da6b', 'Levothyroxine', 'Thyroid', '2026-06-12 15:36:22.323271+00'),
	('492921a9-5a0c-44d7-8ca1-fffca80913c3', 'Phenytoin', 'Antiepileptic', '2026-06-12 15:36:22.323271+00'),
	('ad7a2639-7a86-43ef-b778-f593ad761b8b', 'Escitalopram', 'Antidepressant', '2026-06-12 15:36:22.323271+00'),
	('41f774df-d1de-4ac4-b57f-02ae05d4dd52', 'Sertraline', 'Antidepressant', '2026-06-12 15:36:22.323271+00'),
	('d97e1cde-9d53-4177-8fae-357e7d8bc9b6', 'Fluoxetine', 'Antidepressant', '2026-06-12 15:36:22.323271+00'),
	('038108ac-ac6e-4ab9-8ee9-b6e9a7b1dee0', 'Zolpidem', 'Sedative', '2026-06-12 15:36:22.323271+00'),
	('d318bb07-5ae5-4377-9087-2d0a1cb29156', 'Cabergoline', 'Hormonal', '2026-06-12 15:36:22.323271+00'),
	('347e4fa3-b6cf-4747-948d-50604cd9880a', 'Norethisterone', 'Hormonal', '2026-06-12 15:36:22.323271+00'),
	('c8711728-0ae5-40b3-8ffc-740e99738766', 'Salbutamol', 'Respiratory', '2026-06-12 15:36:22.323271+00'),
	('2bf7029a-8ebe-434f-9191-94bc08fb17ae', 'Etofylline + Theophylline', 'Respiratory', '2026-06-12 15:36:22.323271+00'),
	('59c099d6-677a-4452-abd0-79aa1139480d', 'Budesonide + Formoterol', 'Respiratory', '2026-06-12 15:36:22.323271+00'),
	('002395ac-99bd-456a-a601-1dc82e58d0af', 'Levosalbutamol + Ipratropium', 'Respiratory', '2026-06-12 15:36:22.323271+00'),
	('d7940fdb-ccd8-4e12-8c96-e7b43a715d06', 'Framycetin', 'Topical Antibiotic', '2026-06-12 15:36:22.323271+00'),
	('6e773639-c8b7-4fa4-b4fb-0d95f0640bd3', 'Povidone Iodine', 'Antiseptic', '2026-06-12 15:36:22.323271+00'),
	('2783099c-9120-4419-a4e5-4660dde50139', 'Clotrimazole + Beclomethasone', 'Antifungal/Steroid', '2026-06-12 15:36:22.323271+00'),
	('6283618f-76ab-4f91-80c4-0aa4e360aae5', 'Luliconazole', 'Antifungal', '2026-06-12 15:36:22.323271+00'),
	('92681c2b-2d9d-46bc-89f2-10f77d1c036d', 'Terbinafine', 'Antifungal', '2026-06-12 15:36:22.323271+00');

--
-- Data for Name: drug_interaction; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.drug_interaction VALUES
	('90a1e81f-67c2-4d18-b61b-26b3127965a6', '7e59ef70-d4ca-4fb9-901e-b1ea60b695ad', '71642ef1-fb08-4b96-89c7-e0e85fd55a1c', 'MODERATE', 'Concurrent use of Aspirin and Ibuprofen may reduce the cardioprotective effect of Aspirin and increase risk of gastrointestinal bleeding.', 'Avoid regular combined use. If both are needed, take Aspirin 30 minutes before Ibuprofen. Advise patient to report GI symptoms.', true, '2026-06-12 15:36:22.398527+00'),
	('f449b153-71e9-4a43-a740-e2971f947a65', '57223352-afb9-4116-9097-6438efcc8357', '317d7b70-44c7-4292-b96f-15563327d4cc', 'MODERATE', 'Furosemide can increase Metformin plasma levels by reducing renal clearance, raising the risk of lactic acidosis.', 'Monitor renal function when combining. Consider dose adjustment of Metformin. Hold Metformin if eGFR drops below 30.', true, '2026-06-12 15:36:22.398527+00'),
	('f5447537-a6fc-4d5e-bbc7-5b3be462ec6d', '57223352-afb9-4116-9097-6438efcc8357', '465cd109-27d5-45e8-930e-b2384de7dcb5', 'MODERATE', 'Hydrochlorothiazide can cause hyperglycemia, reducing the efficacy of Metformin in controlling blood glucose.', 'Monitor blood glucose closely when initiating or changing thiazide dose. Adjust antidiabetic therapy as needed.', true, '2026-06-12 15:36:22.398527+00'),
	('30bb8f32-5535-4cf0-9af0-a4a332bbec25', '7e59ef70-d4ca-4fb9-901e-b1ea60b695ad', 'ae12d15c-14c1-4aad-a976-daad630ac9b3', 'HIGH', 'Combined use of Aspirin and Diclofenac significantly increases the risk of gastrointestinal ulceration and bleeding.', 'Avoid co-administration unless under specialist supervision. If unavoidable, add a PPI (e.g. Omeprazole) for gastric protection.', true, '2026-06-12 15:36:22.398527+00'),
	('5024b0f5-e0e4-40b4-b43e-3e78d7beb924', '9db1715a-884c-40bd-8664-069a5d9a4d12', 'a5264fd9-3597-41e9-b954-c199a82a0618', 'HIGH', 'Erythromycin inhibits CYP3A4, significantly increasing Atorvastatin plasma levels and the risk of myopathy or rhabdomyolysis.', 'Temporarily suspend Atorvastatin during short Erythromycin courses. If statin therapy cannot be interrupted, consider a non-CYP3A4 metabolised statin (e.g. Rosuvastatin).', true, '2026-06-12 15:36:22.398527+00'),
	('c18aeee8-7c2d-4ad4-86c7-e20d43c4003c', '9db1715a-884c-40bd-8664-069a5d9a4d12', '5fbb8d2f-1cd2-40d4-b103-fecc0094e201', 'CRITICAL', 'Itraconazole is a potent CYP3A4 inhibitor that can dramatically increase Atorvastatin levels, causing severe myopathy or rhabdomyolysis.', 'Avoid co-administration. Suspend Atorvastatin during Itraconazole treatment. Use Fluconazole (weaker CYP3A4 effect) as antifungal alternative where possible.', true, '2026-06-12 15:36:22.398527+00'),
	('781984a0-ac26-4be5-af5c-5a9fe66707bd', '1af5a9c7-cc5b-44f4-bd2d-a613a30d343b', '78e333e9-0baf-40f7-8d28-e22f3b939e3e', 'HIGH', 'Ciprofloxacin inhibits CYP1A2, reducing Theophylline clearance and increasing risk of theophylline toxicity (nausea, tremors, seizures).', 'Reduce Theophylline dose by 30–50% when starting Ciprofloxacin. Monitor serum theophylline levels and clinical signs of toxicity.', true, '2026-06-12 15:36:22.398527+00'),
	('6c725082-faac-4f14-9d88-a0903a431b33', '9f7d7d83-a473-4af7-a876-4cdf34436ddf', '5145eac4-9a7e-4c87-ae4b-b07d92c4b0bb', 'MODERATE', 'Concurrent use of Fluconazole and Metronidazole may potentiate QT prolongation and increase risk of serious cardiac arrhythmias.', 'Use with caution in patients with cardiac risk factors. Obtain baseline ECG and monitor for QT prolongation.', true, '2026-06-12 15:36:22.398527+00'),
	('eb61fa7b-1157-41dd-9256-dee1ceb03791', '9c7482a4-45b2-420a-b30a-24939765b139', '71642ef1-fb08-4b96-89c7-e0e85fd55a1c', 'HIGH', 'Prednisolone combined with Ibuprofen substantially increases the risk of gastrointestinal ulceration, bleeding, and perforation.', 'Avoid combination where possible. If both required, add a PPI (Omeprazole 20mg daily) for gastric protection. Warn patient to report abdominal pain or black stools immediately.', true, '2026-06-12 15:36:22.398527+00'),
	('b3953342-6d61-4329-bc7b-b411c4a68225', '853ad850-1b55-472e-9add-d94726df11c5', '22c8157d-5c6d-45b2-9359-2f621ab2471d', 'HIGH', 'Combining Sertraline with Tramadol significantly raises the risk of serotonin syndrome (agitation, hyperthermia, tachycardia, clonus).', 'Avoid co-administration if possible. If both are prescribed, use the lowest effective Tramadol dose and monitor closely for serotonin syndrome symptoms for 24 hours after initiation.', true, '2026-06-12 15:36:22.398527+00'),
	('1733e5ed-25e1-4eba-8e22-de06b102ac14', 'b33f8db2-edfb-4f1f-862c-6bce037d8fc3', 'a5264fd9-3597-41e9-b954-c199a82a0618', 'HIGH', 'Erythromycin inhibits the metabolism of Carbamazepine, leading to elevated plasma levels and risk of carbamazepine toxicity (diplopia, ataxia, vomiting).', 'Avoid combination. If Erythromycin is required in a patient on Carbamazepine, consider an alternative antibiotic such as Azithromycin with less CYP3A4 interaction.', true, '2026-06-12 15:36:22.398527+00'),
	('b136316d-9013-4abd-a0ea-632c9640c14d', '57223352-afb9-4116-9097-6438efcc8357', '087a9468-d100-4d84-8ce6-296825765f6c', 'LOW', 'Combined use of Metformin and Dapagliflozin is a standard antidiabetic regimen but requires monitoring for volume depletion and urinary tract infections.', 'Ensure adequate hydration. Monitor renal function periodically. Educate patient on signs of dehydration and UTI.', true, '2026-06-12 15:36:22.398527+00');

--
-- Data for Name: drug_licenses; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: drug_master; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.drug_master VALUES
	('7505d73f-5f01-4074-8345-4374e171dab0', 'Crocin 500mg', 'Paracetamol', '5f40d97e-0c74-4d38-895a-645462f6558c', 'Paracetamol 500mg', 'GSK', '3004', 12.00, 'GENERAL', 'Tablet', '15 Tablets', 30.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('60adbc31-d6a4-41eb-96f3-496cc6d48466', 'Calpol 500mg', 'Paracetamol', '5f40d97e-0c74-4d38-895a-645462f6558c', 'Paracetamol 500mg', 'GSK', '3004', 12.00, 'GENERAL', 'Tablet', '15 Tablets', 32.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('a8648697-b02d-41a4-aa6c-571f7c0b9c2d', 'Dolo 650', 'Paracetamol', '5f40d97e-0c74-4d38-895a-645462f6558c', 'Paracetamol 650mg', 'Micro Labs', '3004', 12.00, 'GENERAL', 'Tablet', '15 Tablets', 32.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('420eb12f-ce85-40da-8ef8-c44cd6218b8a', 'Pyrigesic 500mg', 'Paracetamol', '5f40d97e-0c74-4d38-895a-645462f6558c', 'Paracetamol 500mg', 'East India', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 20.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('15757225-fbf3-43a4-a49b-7891454c6a00', 'Paracip 500', 'Paracetamol', '5f40d97e-0c74-4d38-895a-645462f6558c', 'Paracetamol 500mg', 'Cipla', '3004', 12.00, 'GENERAL', 'Tablet', '15 Tablets', 28.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('f00bbca6-2357-4565-88f1-bd727879b474', 'Febrinil 650', 'Paracetamol', '5f40d97e-0c74-4d38-895a-645462f6558c', 'Paracetamol 650mg', 'Alkem', '3004', 12.00, 'GENERAL', 'Tablet', '15 Tablets', 30.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('053b799f-18ad-4e42-9921-8fbefe85f2f0', 'Brufen 400mg', 'Ibuprofen', '71642ef1-fb08-4b96-89c7-e0e85fd55a1c', 'Ibuprofen 400mg', 'Abbott', '3004', 12.00, 'GENERAL', 'Tablet', '15 Tablets', 28.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('868379e0-60ea-42dd-a332-ed08f5c9b370', 'Ibugesic 400mg', 'Ibuprofen', '71642ef1-fb08-4b96-89c7-e0e85fd55a1c', 'Ibuprofen 400mg', 'Cipla', '3004', 12.00, 'GENERAL', 'Tablet', '15 Tablets', 25.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('5b94b677-24af-40cd-a232-231afc6c1cbc', 'Combiflam', 'Ibuprofen+Paracetamol', '71642ef1-fb08-4b96-89c7-e0e85fd55a1c', 'Ibuprofen 400mg + Paracetamol 325mg', 'Sanofi', '3004', 12.00, 'GENERAL', 'Tablet', '20 Tablets', 43.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('acb37a6f-3c7b-45f8-8a15-9eb562155979', 'Advil 200', 'Ibuprofen', '71642ef1-fb08-4b96-89c7-e0e85fd55a1c', 'Ibuprofen 200mg', 'Pfizer', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 38.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('eaf3a643-efce-48e0-ad04-7e7c1a322917', 'Voveran 50', 'Diclofenac Sodium', 'ae12d15c-14c1-4aad-a976-daad630ac9b3', 'Diclofenac Sodium 50mg', 'Novartis', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 38.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('d62613f9-a112-451f-bdfb-d9b21d5de4ee', 'Voltaren 50', 'Diclofenac Sodium', 'ae12d15c-14c1-4aad-a976-daad630ac9b3', 'Diclofenac Sodium 50mg', 'Novartis', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 35.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('931c1f3f-337f-4250-b184-ed8e0a053597', 'Reactin 50', 'Diclofenac Sodium', 'ae12d15c-14c1-4aad-a976-daad630ac9b3', 'Diclofenac Sodium 50mg', 'Alkem', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 32.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('8cadd605-f062-45a4-96c6-37a1531c7e39', 'Zerodol 100', 'Aceclofenac', 'a82353e4-bd5c-4235-8d8a-c1395385c995', 'Aceclofenac 100mg', 'Ipca', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 42.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('f54faf17-f1df-4042-a35c-1969f3427768', 'Hifenac 100', 'Aceclofenac', 'a82353e4-bd5c-4235-8d8a-c1395385c995', 'Aceclofenac 100mg', 'Intas', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 45.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('d63e73ba-0035-4d78-bd3b-745aa295dddb', 'Aceclo Plus', 'Aceclofenac+Paracetamol', 'a82353e4-bd5c-4235-8d8a-c1395385c995', 'Aceclofenac 100mg + Paracetamol 325mg', 'Alkem', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 55.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('1e5a3770-c422-425c-8636-76c707287fe9', 'Dolowin Plus', 'Aceclofenac+Paracetamol', 'a82353e4-bd5c-4235-8d8a-c1395385c995', 'Aceclofenac 100mg + Paracetamol 325mg', 'Win Medicare', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 52.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('6167fe12-785f-44db-a20f-215978390be2', 'Nise 100mg', 'Nimesulide', 'd76bccf6-4b49-4017-b3bb-9204060d03c4', 'Nimesulide 100mg', 'Dr Reddy''s', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 28.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('e26a2cf6-39eb-4647-910c-8ad696174962', 'Nimulid 100mg', 'Nimesulide', 'd76bccf6-4b49-4017-b3bb-9204060d03c4', 'Nimesulide 100mg', 'Panacea', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 26.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('a0c21b39-ca64-4ebf-9840-f26173d7f268', 'Tramazac 50', 'Tramadol HCl', '22c8157d-5c6d-45b2-9359-2f621ab2471d', 'Tramadol HCl 50mg', 'Zydus', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 55.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('ea4c17ef-5b4f-4021-b1a5-838c587f8f17', 'Ultracet', 'Tramadol+Paracetamol', '22c8157d-5c6d-45b2-9359-2f621ab2471d', 'Tramadol 37.5mg + Paracetamol 325mg', 'Janssen', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 95.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('b0e3a86a-f26f-44b2-941f-0978ce6e0daa', 'Mox 500', 'Amoxicillin', '75543c99-1ff5-41f7-b7a1-94b8a0656c37', 'Amoxicillin 500mg', 'Ranbaxy', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 55.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('c76d6ab2-1798-4843-976a-2970bed4ffb1', 'Novamox 500', 'Amoxicillin', '75543c99-1ff5-41f7-b7a1-94b8a0656c37', 'Amoxicillin 500mg', 'Cipla', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 52.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('8ad4c240-eb86-404e-8cb2-b68b0afb7210', 'Augmentin 625mg', 'Amoxicillin+Clavulanic Acid', '7121615e-b01c-43d1-95cd-83a866816266', 'Amoxicillin 500mg + Clavulanic Acid 125mg', 'GSK', '3004', 12.00, 'H', 'Tablet', '6 Tablets', 142.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('c4f2744a-9680-4d7c-a314-3707a6b882e2', 'Clavam 625', 'Amoxicillin+Clavulanic Acid', '7121615e-b01c-43d1-95cd-83a866816266', 'Amoxicillin 500mg + Clavulanic Acid 125mg', 'Alkem', '3004', 12.00, 'H', 'Tablet', '6 Tablets', 128.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('749ec0de-e27c-45a9-8f86-0c6fe285c135', 'Azithral 500', 'Azithromycin', '55786ce1-26ae-4847-b5a6-ae94bf0322fb', 'Azithromycin 500mg', 'Alembic', '3004', 12.00, 'H', 'Tablet', '5 Tablets', 82.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('7978c8ca-31ce-4d30-88e4-fa920f236564', 'Zithromax 500', 'Azithromycin', '55786ce1-26ae-4847-b5a6-ae94bf0322fb', 'Azithromycin 500mg', 'Pfizer', '3004', 12.00, 'H', 'Tablet', '5 Tablets', 95.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('92ba4c34-f12b-41d3-a09a-e6bf9dda37cc', 'Azee 500', 'Azithromycin', '55786ce1-26ae-4847-b5a6-ae94bf0322fb', 'Azithromycin 500mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '5 Tablets', 78.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('9f460619-a048-4128-a9e4-e4f0d21a2763', 'Zady 500', 'Azithromycin', '55786ce1-26ae-4847-b5a6-ae94bf0322fb', 'Azithromycin 500mg', 'Cadila', '3004', 12.00, 'H', 'Tablet', '5 Tablets', 72.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('b49a64dc-c0ad-456b-9f68-8c689c6fd674', 'Ciplox 500', 'Ciprofloxacin HCl', '1af5a9c7-cc5b-44f4-bd2d-a613a30d343b', 'Ciprofloxacin 500mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 52.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('0e523495-674a-4a84-9e98-43660a2f427b', 'Cifran 500', 'Ciprofloxacin HCl', '1af5a9c7-cc5b-44f4-bd2d-a613a30d343b', 'Ciprofloxacin 500mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 48.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('cc469ed3-6115-4626-b9db-9768874e1875', 'Flagyl 400', 'Metronidazole', '5145eac4-9a7e-4c87-ae4b-b07d92c4b0bb', 'Metronidazole 400mg', 'Abbott', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 22.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('12999555-9cc8-47d6-bc38-a748e301cd56', 'Metrogyl 400', 'Metronidazole', '5145eac4-9a7e-4c87-ae4b-b07d92c4b0bb', 'Metronidazole 400mg', 'J B Chemicals', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 20.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('06692c68-44ec-4106-85be-b1ce51dd9255', 'Taxim-O 200', 'Cefixime', '4265bc8f-d41d-4449-9a59-d2ddb69e3664', 'Cefixime 200mg', 'Alkem', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 158.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('6cb6aa94-82c4-4cd3-8bae-822c4781453f', 'Monocef 200', 'Cefixime', '4265bc8f-d41d-4449-9a59-d2ddb69e3664', 'Cefixime 200mg', 'Aristo', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 142.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('904e212c-eb48-4f92-9e96-d98fe1d39e0a', 'Cefix 200', 'Cefixime', '4265bc8f-d41d-4449-9a59-d2ddb69e3664', 'Cefixime 200mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 138.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('b54c8d58-c557-43d4-bb3f-ad0be4c5cdba', 'Doxt-SL', 'Doxycycline HCl', 'b4495d8d-1049-4586-a1b6-c6f900576151', 'Doxycycline 100mg', 'Sun Pharma', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 65.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('19358251-8743-4e29-add8-576bada78ab4', 'Doxolin 100', 'Doxycycline HCl', 'b4495d8d-1049-4586-a1b6-c6f900576151', 'Doxycycline 100mg', 'Aristo', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 58.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('4cb770c6-b4e0-4440-accc-bbaa045ae515', 'Levoflox 500', 'Levofloxacin', '8b1fcf6e-cee6-479e-af5d-c28060b7ac56', 'Levofloxacin 500mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '5 Tablets', 95.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('bf90aec5-44f8-4fe7-b364-572730762b15', 'Levaquin 500', 'Levofloxacin', '8b1fcf6e-cee6-479e-af5d-c28060b7ac56', 'Levofloxacin 500mg', 'Janssen', '3004', 12.00, 'H', 'Tablet', '5 Tablets', 108.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('f2bfaf57-1325-4fdd-80dd-00a1242f427b', 'Zanocin 200', 'Ofloxacin', 'b35104c9-3bc7-4789-b3ca-fba6ec95a2c9', 'Ofloxacin 200mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 42.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('965b9860-efa4-43cf-8846-64ac9ca4d205', 'Oflox 200', 'Ofloxacin', 'b35104c9-3bc7-4789-b3ca-fba6ec95a2c9', 'Ofloxacin 200mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 38.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('ff070a00-2fb8-4c42-8ad5-e842e35b027a', 'Sporidex 500', 'Cephalexin', '464cb5e7-92cd-4d4f-a0b5-5d108f7381f3', 'Cephalexin 500mg', 'Cipla', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 78.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('fab9f282-ce95-4b0c-8ede-5e6944ef3304', 'Phexin 500', 'Cephalexin', '464cb5e7-92cd-4d4f-a0b5-5d108f7381f3', 'Cephalexin 500mg', 'GSK', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 85.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('dc49b93c-2e54-4bba-be85-17f8e7d4c691', 'Omez 20', 'Omeprazole', '766a6b24-4ed1-458e-9c8c-0e62b5f3e2be', 'Omeprazole 20mg', 'Dr Reddy''s', '3004', 12.00, 'GENERAL', 'Capsule', '15 Capsules', 72.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('e33acd72-306b-482b-8d8b-7e11e74784bd', 'Ocid 20', 'Omeprazole', '766a6b24-4ed1-458e-9c8c-0e62b5f3e2be', 'Omeprazole 20mg', 'Cipla', '3004', 12.00, 'GENERAL', 'Capsule', '15 Capsules', 68.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('3d745fce-ca62-46a6-a5b3-ca137feffa99', 'Pan 40', 'Pantoprazole Sodium', '6d4b13a0-6c32-45e1-85ff-650a5c356d6e', 'Pantoprazole 40mg', 'Alkem', '3004', 12.00, 'GENERAL', 'Tablet', '15 Tablets', 65.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('a6e219c3-1c02-4b87-a151-7f135e13a444', 'Pantodac 40', 'Pantoprazole Sodium', '6d4b13a0-6c32-45e1-85ff-650a5c356d6e', 'Pantoprazole 40mg', 'Zydus', '3004', 12.00, 'GENERAL', 'Tablet', '15 Tablets', 62.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('5465acc6-0609-4c4f-ac41-24e842cb0905', 'Razo 20', 'Rabeprazole Sodium', 'f6599bad-8149-45a0-91bb-11148e16e949', 'Rabeprazole 20mg', 'Dr Reddy''s', '3004', 12.00, 'GENERAL', 'Tablet', '15 Tablets', 78.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('a2fd0aa1-80d4-44b8-93db-4fa069b3dd58', 'Rablet 20', 'Rabeprazole Sodium', 'f6599bad-8149-45a0-91bb-11148e16e949', 'Rabeprazole 20mg', 'Lupin', '3004', 12.00, 'GENERAL', 'Tablet', '15 Tablets', 72.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('702a6389-073f-4ed7-a6ad-24305f2618d1', 'Nexium 40', 'Esomeprazole Magnesium', 'd42bf8b0-df49-4ef0-bb92-383bcb56c664', 'Esomeprazole 40mg', 'AstraZeneca', '3004', 12.00, 'GENERAL', 'Tablet', '14 Tablets', 185.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('7a035409-babc-411c-99d1-e67f5f9b30bf', 'Rantac 150', 'Ranitidine HCl', '97875981-850a-4f77-914a-fdbbe3c69c8c', 'Ranitidine 150mg', 'J B Chemicals', '3004', 12.00, 'GENERAL', 'Tablet', '30 Tablets', 38.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('711b0677-a77f-43a5-b83c-fa1e78df536a', 'Aciloc 150', 'Ranitidine HCl', '97875981-850a-4f77-914a-fdbbe3c69c8c', 'Ranitidine 150mg', 'Cadila', '3004', 12.00, 'GENERAL', 'Tablet', '30 Tablets', 35.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('90b673f3-dd15-4fd6-8a88-aa84a2ca3a66', 'Domstal 10', 'Domperidone', '38aa8c76-24e9-4abb-aeff-340deff5a7ab', 'Domperidone 10mg', 'Torrent', '3004', 12.00, 'GENERAL', 'Tablet', '30 Tablets', 35.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('1a1b08eb-f1b2-432a-82ad-7350160308f6', 'Motilium 10', 'Domperidone', '38aa8c76-24e9-4abb-aeff-340deff5a7ab', 'Domperidone 10mg', 'Janssen', '3004', 12.00, 'GENERAL', 'Tablet', '30 Tablets', 42.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('ecb6f717-fdee-4db9-b8d2-c3036860ca8a', 'Emeset 4mg', 'Ondansetron HCl', '5db455ba-ba5e-44df-917d-a6aebebfda44', 'Ondansetron 4mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 65.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('8241c239-b302-44c8-8294-ccd1be91c812', 'Ondem 4mg', 'Ondansetron HCl', '5db455ba-ba5e-44df-917d-a6aebebfda44', 'Ondansetron 4mg', 'Alkem', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 62.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('dc6c4a0b-9e21-4dc2-8c2e-1fb0d0c275af', 'Allegra 120mg', 'Fexofenadine HCl', 'd7a717d9-52d2-44fb-9afa-b561e86958a7', 'Fexofenadine 120mg', 'Sanofi', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 74.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('727bc654-411c-496e-800e-2d3226384a79', 'Allegra 180mg', 'Fexofenadine HCl', 'd7a717d9-52d2-44fb-9afa-b561e86958a7', 'Fexofenadine 180mg', 'Sanofi', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 98.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('ff6f96d8-83c9-4efa-a092-4a6cff17fd6a', 'Cetrizine 10mg', 'Cetirizine HCl', '41fdbeae-ec17-41cc-84ba-040b488a70dd', 'Cetirizine 10mg', 'Cipla', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 18.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('989ddc13-247a-488e-ba9c-6a60a95a406b', 'Okacet 10mg', 'Cetirizine HCl', '41fdbeae-ec17-41cc-84ba-040b488a70dd', 'Cetirizine 10mg', 'Cipla', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 16.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('b613f3fd-2d11-4136-bf38-f29dd888e12c', 'Xyzal 5mg', 'Levocetirizine HCl', '54071a12-7461-47d0-823f-c7c87773cf3d', 'Levocetirizine 5mg', 'UCB', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 55.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('4c2c98c7-53e3-4770-b29f-1e13f9a25ec0', 'Levocet 5mg', 'Levocetirizine HCl', '54071a12-7461-47d0-823f-c7c87773cf3d', 'Levocetirizine 5mg', 'Cipla', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 32.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('52302db2-6714-4033-84a1-a802fca02e4e', 'Lorfast 10', 'Loratadine', 'a89426bf-b02f-40c8-9832-a86b9c83b7a6', 'Loratadine 10mg', 'Sun Pharma', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 28.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('950493aa-6fa5-4d84-9a42-6841924d9f22', 'Clarityn 10', 'Loratadine', 'a89426bf-b02f-40c8-9832-a86b9c83b7a6', 'Loratadine 10mg', 'Bayer', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 38.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('03a03c2e-49f3-433a-ac78-4fffea01fa2e', 'Montair 10', 'Montelukast Sodium', '2209ba14-87ff-4abd-a090-9fbc51b540fd', 'Montelukast 10mg', 'Cipla', '3004', 12.00, 'GENERAL', 'Tablet', '15 Tablets', 95.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('03f3cbf0-b6d3-44e3-abb4-14d03c3f12bd', 'Singulair 10', 'Montelukast Sodium', '2209ba14-87ff-4abd-a090-9fbc51b540fd', 'Montelukast 10mg', 'MSD', '3004', 12.00, 'GENERAL', 'Tablet', '14 Tablets', 185.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('b88f8aac-3874-46e3-840a-f9deff4dbc26', 'Glycomet 500', 'Metformin HCl', '57223352-afb9-4116-9097-6438efcc8357', 'Metformin HCl 500mg', 'USV', '3004', 12.00, 'H', 'Tablet', '20 Tablets', 28.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('62d2f282-f2cb-49d5-9087-d74cca2aaaf9', 'Glucophage 500', 'Metformin HCl', '57223352-afb9-4116-9097-6438efcc8357', 'Metformin HCl 500mg', 'Merck', '3004', 12.00, 'H', 'Tablet', '20 Tablets', 32.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('01d3e81d-2ee8-4d36-b3fe-251440fe3d13', 'Glycomet 850', 'Metformin HCl', '57223352-afb9-4116-9097-6438efcc8357', 'Metformin HCl 850mg', 'USV', '3004', 12.00, 'H', 'Tablet', '20 Tablets', 38.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('c146b007-6919-40b3-8661-6508b875a279', 'Amaryl 1mg', 'Glimepiride', '075d8268-1a17-4ba8-831f-36e35331685a', 'Glimepiride 1mg', 'Sanofi', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 98.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('de510530-adfc-4f4c-ae85-5f930d2ba755', 'Amaryl 2mg', 'Glimepiride', '075d8268-1a17-4ba8-831f-36e35331685a', 'Glimepiride 2mg', 'Sanofi', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 145.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('de888bff-c0de-4f46-93d2-15d6467ecada', 'Glimer 1', 'Glimepiride', '075d8268-1a17-4ba8-831f-36e35331685a', 'Glimepiride 1mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 75.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('7496d055-1706-4164-87d9-93ec88de5c98', 'Gluconorm-G 1', 'Metformin+Glimepiride', '075d8268-1a17-4ba8-831f-36e35331685a', 'Metformin 500mg + Glimepiride 1mg', 'Ranbaxy', '3004', 12.00, 'H', 'Tablet', '20 Tablets', 95.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('c89b05b7-1494-4c19-a52a-bbd138f50ee6', 'Gluconorm-G 2', 'Metformin+Glimepiride', '075d8268-1a17-4ba8-831f-36e35331685a', 'Metformin 500mg + Glimepiride 2mg', 'Ranbaxy', '3004', 12.00, 'H', 'Tablet', '20 Tablets', 115.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('cb9285b3-b009-4492-a163-44caffe23cbb', 'Januvia 100', 'Sitagliptin Phosphate', '210364ff-948d-4721-adbc-e60f05a6e1f8', 'Sitagliptin 100mg', 'MSD', '3004', 12.00, 'H', 'Tablet', '14 Tablets', 485.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('e01e523e-9082-4c57-be94-4502b6d49501', 'Jalra 50', 'Vildagliptin', '562708f4-fc58-473c-8cd6-4cd482653130', 'Vildagliptin 50mg', 'Novartis', '3004', 12.00, 'H', 'Tablet', '14 Tablets', 395.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('c571651d-11fd-4b00-b8d0-9090af542cd9', 'Amlip 5', 'Amlodipine Besylate', '7d0d8df1-f7b3-448a-aed9-0ce83191dc76', 'Amlodipine 5mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 55.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('a7571101-34fe-42e9-8867-55f8ff61c072', 'Stamlo 5', 'Amlodipine Besylate', '7d0d8df1-f7b3-448a-aed9-0ce83191dc76', 'Amlodipine 5mg', 'Dr Reddy''s', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 52.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('a729a4b6-f440-4878-aa7e-f5fd02bc3c4a', 'Norvasc 5', 'Amlodipine Besylate', '7d0d8df1-f7b3-448a-aed9-0ce83191dc76', 'Amlodipine 5mg', 'Pfizer', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 185.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('484d1d3e-7022-4e9f-9e01-ba2632fb7d11', 'Aten 50', 'Atenolol', 'f5cfe193-a2ec-4c39-9314-921399f56932', 'Atenolol 50mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 35.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('7a6d4779-887c-4d30-b197-70614561cc82', 'Tenormin 50', 'Atenolol', 'f5cfe193-a2ec-4c39-9314-921399f56932', 'Atenolol 50mg', 'AstraZeneca', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 75.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('b16151c2-c8cd-4aa7-9a4a-326d95bd5d9f', 'Atenolol+Amlodipine 5', 'Atenolol+Amlodipine', 'f5cfe193-a2ec-4c39-9314-921399f56932', 'Atenolol 50mg + Amlodipine 5mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 85.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('48d05cb2-f915-4d5d-b2b1-f28176ca8c17', 'Losarvas 50', 'Losartan Potassium', 'bf96342a-4d7d-468c-be97-769b505b687c', 'Losartan 50mg', 'Ranbaxy', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 52.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('d4c22aec-967c-4d6f-8d2e-a07555839a0b', 'Cozaar 50', 'Losartan Potassium', 'bf96342a-4d7d-468c-be97-769b505b687c', 'Losartan 50mg', 'MSD', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 145.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('224364e7-50f0-4e99-ad74-ed767656492f', 'Telma 40', 'Telmisartan', '6fce570f-5ef1-4c2d-a5bc-6399c9f6a860', 'Telmisartan 40mg', 'Glenmark', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 78.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('a99f2a24-31cb-48c8-842b-c9bbcd308df8', 'Telmikind 40', 'Telmisartan', '6fce570f-5ef1-4c2d-a5bc-6399c9f6a860', 'Telmisartan 40mg', 'Mankind', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 65.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('93143898-6050-4ea3-945c-0163ddda7901', 'Envas 5', 'Enalapril Maleate', '44bebb2b-b61c-4ed1-8030-d49519455ece', 'Enalapril 5mg', 'Cadila', '3004', 12.00, 'H', 'Tablet', '20 Tablets', 35.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('37d1cd96-6f6b-4a51-a992-b6afee896b7a', 'Vasotec 5', 'Enalapril Maleate', '44bebb2b-b61c-4ed1-8030-d49519455ece', 'Enalapril 5mg', 'MSD', '3004', 12.00, 'H', 'Tablet', '20 Tablets', 85.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('3d289ef0-5044-4037-a6b3-df2211431e21', 'Cardace 5', 'Ramipril', 'e8c4a0a9-c28d-4e1d-9e9f-e110b89b5b1a', 'Ramipril 5mg', 'Sanofi', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 95.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('caf9923f-551b-408c-b33c-5bbd6bd36b3f', 'Hopace 5', 'Ramipril', 'e8c4a0a9-c28d-4e1d-9e9f-e110b89b5b1a', 'Ramipril 5mg', 'Lupin', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 85.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('a1885620-9381-4f70-8735-673729bbb33e', 'Cipril 5', 'Lisinopril', 'f335ae02-2f9a-4f27-8efe-f00409d19614', 'Lisinopril 5mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 65.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('ecc2c88d-cf3a-4410-aa0c-07fd87d039f5', 'Betaloc ZOK 50', 'Metoprolol Succinate', 'b674433c-92c7-432c-9fdd-b40825a7fc65', 'Metoprolol Succinate 50mg', 'AstraZeneca', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 185.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('cbb3c845-e1a7-4561-b580-9fbe241a8b5e', 'Met XL 50', 'Metoprolol Succinate', 'b674433c-92c7-432c-9fdd-b40825a7fc65', 'Metoprolol Succinate 50mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 125.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('24b70bac-6b5e-487e-a4c7-05dc440a8a26', 'Carvidon 6.25', 'Carvedilol', '79312bd6-d51f-492e-ba36-e62fc9ed5ddc', 'Carvedilol 6.25mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 95.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('d3f0e2e1-1d2b-4915-82f3-f02ed3823114', 'Nebi 5', 'Nebivolol HCl', 'f1af0779-8084-439b-bc9b-aef2a32583a8', 'Nebivolol 5mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 145.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('32a27420-8076-4473-ace1-66e2ef514c25', 'Lasix 40', 'Furosemide', '317d7b70-44c7-4292-b96f-15563327d4cc', 'Furosemide 40mg', 'Sanofi', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 22.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('059ab063-4ccd-40ed-8781-7b7e7931d9a6', 'Aldactone 25', 'Spironolactone', '29ee6163-5fdc-4a09-a9ba-5d57d02437ec', 'Spironolactone 25mg', 'Pfizer', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 55.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('411e1110-22ac-4be0-9eda-805c25f3765a', 'Benicar 20', 'Olmesartan Medoxomil', '67a80925-3242-46fb-b7f1-c1e6c5e6aba7', 'Olmesartan 20mg', 'Daiichi Sankyo', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 145.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('c7e98b01-f9ee-4d54-bbff-29bdb5874986', 'Olmy 20', 'Olmesartan Medoxomil', '67a80925-3242-46fb-b7f1-c1e6c5e6aba7', 'Olmesartan 20mg', 'Ajanta', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 115.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('9579e909-8fb0-4306-beb9-d0d0ce9e642b', 'Lipitor 10', 'Atorvastatin Calcium', '9db1715a-884c-40bd-8664-069a5d9a4d12', 'Atorvastatin 10mg', 'Pfizer', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 135.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('0b60ac6f-672a-4b87-b27d-0810638a8f92', 'Storvas 10', 'Atorvastatin Calcium', '9db1715a-884c-40bd-8664-069a5d9a4d12', 'Atorvastatin 10mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 95.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('de738e97-fb78-4d6e-b4c5-23ccae355aa9', 'Atorva 20', 'Atorvastatin Calcium', '9db1715a-884c-40bd-8664-069a5d9a4d12', 'Atorvastatin 20mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 115.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('97191d11-40f8-4e86-b7b2-6f581f4b67de', 'Crestor 10', 'Rosuvastatin Calcium', '92a4fcba-09e2-47c6-951f-d0d34865bcc5', 'Rosuvastatin 10mg', 'AstraZeneca', '3004', 12.00, 'H', 'Tablet', '14 Tablets', 198.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('56c95b73-9d6c-4e0a-819d-5fd533ad7c74', 'Rosulip 10', 'Rosuvastatin Calcium', '92a4fcba-09e2-47c6-951f-d0d34865bcc5', 'Rosuvastatin 10mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '14 Tablets', 145.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('924e0747-70ff-4cab-927e-b7af6ef93ca4', 'Zocor 10', 'Simvastatin', '8ca073fb-24ab-4ab4-8c21-e0edd9f63283', 'Simvastatin 10mg', 'MSD', '3004', 12.00, 'H', 'Tablet', '14 Tablets', 125.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('9e948ad5-51f9-4b8f-8fe1-de18c972e875', 'Tricor 145', 'Fenofibrate', '2827b69f-4f2c-47e5-ad56-e6e410659c40', 'Fenofibrate 145mg', 'Abbott', '3004', 12.00, 'H', 'Tablet', '14 Tablets', 195.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('289909dd-1b0d-4072-b192-8d92d3bee63a', 'Ezetrol 10', 'Ezetimibe', 'cd60d98f-5547-4812-a829-782de7aa5e50', 'Ezetimibe 10mg', 'MSD', '3004', 12.00, 'H', 'Tablet', '14 Tablets', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('49de4680-5009-404d-832a-ff0343330aeb', 'Asthalin 4mg', 'Salbutamol Sulphate', '577f9b1a-aafd-478f-88af-336775e97515', 'Salbutamol 4mg', 'Cipla', '3004', 12.00, 'GENERAL', 'Tablet', '30 Tablets', 25.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('ebd9892b-8c54-47eb-a3b9-6d26c1d9cc45', 'Ventolin 2mg', 'Salbutamol Sulphate', '577f9b1a-aafd-478f-88af-336775e97515', 'Salbutamol 2mg', 'GSK', '3004', 12.00, 'GENERAL', 'Tablet', '30 Tablets', 28.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('c12ad620-e4e4-4940-8804-0cc0cf19e427', 'Levolin 5mg', 'Levosalbutamol Sulphate', 'd8a95cbf-9aa0-4a98-9c5d-7adb4efbe90b', 'Levosalbutamol 1mg/5ml', 'Cipla', '3004', 12.00, 'GENERAL', 'Syrup', '60ml', 55.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('f2132798-1fe3-43ac-be2b-dcc7dcf538b1', 'Duolin', 'Ipratropium+Salbutamol', '431611a5-5f6a-4237-b233-1320daa6a712', 'Ipratropium 20mcg + Levosalbutamol 50mcg', 'Cipla', '3004', 12.00, 'H', 'Inhaler', '200 doses', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('5ecbf648-1c52-46cd-90cc-2589c1a9f12d', 'Pulmicort', 'Budesonide', '85714ca0-1b46-4dc8-a526-54d3b5b6ab26', 'Budesonide 0.5mg/2ml', 'AstraZeneca', '3004', 12.00, 'H', 'Respules', '2ml x 5', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('25adbec5-75d4-40c1-999a-a02d6f189671', 'Seretide 25/50', 'Fluticasone+Salmeterol', '799ea644-fcb3-453e-870b-80cbb4b5bb76', 'Fluticasone 25mcg + Salmeterol 50mcg', 'GSK', '3004', 12.00, 'H', 'Inhaler', '120 doses', 850.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('0cb4803a-ea51-4bf6-8e25-49881d509f86', 'Foracort 200', 'Formoterol+Budesonide', '799ea644-fcb3-453e-870b-80cbb4b5bb76', 'Formoterol 6mcg + Budesonide 200mcg', 'Cipla', '3004', 12.00, 'H', 'Inhaler', '120 doses', 650.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('dc647f7f-be3c-4efa-bcad-1066d8cafb22', 'Mucinac 600', 'Acetylcysteine', '87f74373-223d-426d-9746-19aef4917961', 'Acetylcysteine 600mg', 'Cipla', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 72.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('dc6d58bc-3683-4038-99d2-d621887d503c', 'Ambrolite 30', 'Ambroxol HCl', '87f74373-223d-426d-9746-19aef4917961', 'Ambroxol 30mg', 'Lupin', '3004', 12.00, 'GENERAL', 'Tablet', '20 Tablets', 35.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('55a873ff-2a11-4e8b-a282-d033f3f29e40', 'Benadryl Cough', 'Diphenhydramine+Ammonium', '91c83c5b-a1e9-4f4a-bc29-fc5224015440', 'Diphenhydramine 14.08mg + Ammonium Chloride 138mg', 'Johnson', '3004', 12.00, 'GENERAL', 'Syrup', '100ml', 78.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('71f335ca-dd21-4c88-8ce8-3fecfd3264e9', 'Theobid 200', 'Theophylline', '78e333e9-0baf-40f7-8d28-e22f3b939e3e', 'Theophylline 200mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 55.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('491c47dd-274d-477b-a1b8-6a396a21d544', 'Shelcal 500', 'Calcium Carbonate', 'c7fed11e-4c7e-49b3-aacc-ef5ff4edd1d0', 'Calcium Carbonate 1250mg (Calcium 500mg)', 'Torrent', '2106', 18.00, 'GENERAL', 'Tablet', '15 Tablets', 88.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('43153206-ff3d-4aea-8a3e-f6dab7e0460e', 'Calcimax 500', 'Calcium Carbonate+D3', 'c7fed11e-4c7e-49b3-aacc-ef5ff4edd1d0', 'Calcium Carbonate 1250mg + Vitamin D3 250IU', 'Meyer', '2106', 18.00, 'GENERAL', 'Tablet', '15 Tablets', 95.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('53e732ec-68ac-4be2-8195-6855acbe3e4f', 'Vitamin D3 60K', 'Vitamin D3', 'b6093fab-b202-413a-ad74-b2c042eca734', 'Cholecalciferol 60000IU', 'Various', '2106', 18.00, 'GENERAL', 'Sachet', '1 Sachet', 35.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('a19bb984-9924-44ec-91f1-cd95509220c8', 'Uprise D3 60K', 'Vitamin D3', 'b6093fab-b202-413a-ad74-b2c042eca734', 'Cholecalciferol 60000IU', 'Pfizer', '2106', 18.00, 'GENERAL', 'Sachet', '4 Sachets', 148.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('568065bd-0821-4a4b-82ca-851b84ae1ed9', 'Methylcobal 500', 'Vitamin B12', '0bf94773-d112-4adc-b183-121deeb13dc2', 'Methylcobalamin 500mcg', 'Sun Pharma', '2106', 18.00, 'GENERAL', 'Tablet', '10 Tablets', 65.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('1c3fc2fe-dfa9-47b6-ad90-23902c38751a', 'Cobadex CZS', 'Vitamin B12+Zinc', '0bf94773-d112-4adc-b183-121deeb13dc2', 'Methylcobalamin 750mcg + Zinc 22.5mg', 'Sun Pharma', '2106', 18.00, 'GENERAL', 'Capsule', '10 Capsules', 95.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('33882a08-d6f0-4b39-a397-092a01ee8342', 'Folvite 5mg', 'Folic Acid', 'b20dd2a8-554a-44e2-9ac1-304f43b04310', 'Folic Acid 5mg', 'Pfizer', '2106', 18.00, 'GENERAL', 'Tablet', '30 Tablets', 25.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('e13690fb-e222-4fd4-b599-0e0bb666e689', 'Fersolate 200', 'Ferrous Sulphate', '19632a2d-6c8a-46a9-a168-9c396eb66add', 'Ferrous Sulphate 200mg', 'Stadmed', '2106', 18.00, 'GENERAL', 'Tablet', '30 Tablets', 28.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('96e13774-1e43-4489-8cd0-764c6c679f57', 'Zincovit', 'Multivitamin+Zinc', 'de969ab3-bdd8-4833-9e56-c7c7e9843d78', 'Zinc 10mg + Multivitamins', 'Apex', '2106', 18.00, 'GENERAL', 'Tablet', '15 Tablets', 95.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('1e924e06-cb95-4e79-9317-1e1bebbd2dbb', 'Becosules', 'Multivitamin', 'de969ab3-bdd8-4833-9e56-c7c7e9843d78', 'Vitamin B-complex + Vitamin C', 'Pfizer', '2106', 18.00, 'GENERAL', 'Capsule', '20 Capsules', 55.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('884b9e9e-5fac-49bc-83c5-8184d54a235a', 'Limcee 500', 'Vitamin C', 'c78c0b09-38e9-4379-b0d8-608f20d46fc4', 'Ascorbic Acid 500mg', 'Abbott', '2106', 18.00, 'GENERAL', 'Tablet', '30 Tablets', 35.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('ce04e3a0-e21a-4c5a-9583-da424b45e358', 'Electral Powder', 'ORS', 'de969ab3-bdd8-4833-9e56-c7c7e9843d78', 'ORS Powder', 'Franco-Indian', '2106', 18.00, 'GENERAL', 'Sachet', '21.8g', 18.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('267a8265-d283-44f6-8a17-1ed1c2e46d5e', 'Lyrica 75', 'Pregabalin', 'e6aaaf85-0dc1-432a-9c08-8c18dbadec9a', 'Pregabalin 75mg', 'Pfizer', '3004', 12.00, 'H', 'Capsule', '14 Capsules', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('99c712c3-c2a6-465a-b668-451b447f5f8a', 'Pregalin 75', 'Pregabalin', 'e6aaaf85-0dc1-432a-9c08-8c18dbadec9a', 'Pregabalin 75mg', 'Sun Pharma', '3004', 12.00, 'H', 'Capsule', '14 Capsules', 185.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('1d545716-1450-458f-a4a2-54a8d45c8dda', 'Gabapin 300', 'Gabapentin', 'afc84440-84d7-48f0-96e0-86a3283aefe6', 'Gabapentin 300mg', 'Intas', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 145.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('947b3e00-6047-4323-bb57-abfec7f4bf5d', 'Gabantin 300', 'Gabapentin', 'afc84440-84d7-48f0-96e0-86a3283aefe6', 'Gabapentin 300mg', 'Sun Pharma', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 135.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('bc11dd97-ec4d-4985-bb34-386c557ef8aa', 'Keppra 500', 'Levetiracetam', '07e7589d-98d9-492c-937c-5efba3c2869c', 'Levetiracetam 500mg', 'UCB', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 485.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('03adf56b-8b33-4b95-83ff-6e8b3b329f0e', 'Levipil 500', 'Levetiracetam', '07e7589d-98d9-492c-937c-5efba3c2869c', 'Levetiracetam 500mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('fd8d27e0-033c-4857-b040-8bcf6d28eee9', 'Eptoin 100', 'Phenytoin Sodium', '97444490-d399-4fcf-b4f9-dd167b30efaa', 'Phenytoin 100mg', 'Abbott', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 22.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('433906ef-efbf-4836-87da-11750599f99c', 'Mazetol 200', 'Carbamazepine', 'b33f8db2-edfb-4f1f-862c-6bce037d8fc3', 'Carbamazepine 200mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 38.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('0aa1bc6d-2ffe-49c3-8da3-3afac212044f', 'Valparin 200', 'Valproate Sodium', '0a7b5d29-41ca-4211-ab7e-a50a70446184', 'Sodium Valproate 200mg', 'Sanofi', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 55.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('f25ee6cb-60ba-4f4a-8c62-ee20ff0fa46e', 'Lamitor 50', 'Lamotrigine', '8513cabc-3f29-49e2-ae95-7e154749cd61', 'Lamotrigine 50mg', 'Torrent', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 185.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('9393b019-42dd-4298-90fa-56f28633054a', 'Clonotril 0.5', 'Clonazepam', '0eef57f8-85d6-4e0e-9b68-676992b33de2', 'Clonazepam 0.5mg', 'Sun Pharma', '3004', 12.00, 'H1', 'Tablet', '30 Tablets', 28.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('c9e705c3-5cf3-48b5-af4d-ac66d66fa3b5', 'Alprax 0.25', 'Alprazolam', '3d6b896e-e659-4170-975b-b10e7dcf0010', 'Alprazolam 0.25mg', 'Pfizer', '3004', 12.00, 'H1', 'Tablet', '30 Tablets', 55.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('48333442-b810-492e-96fb-8cdb38ce2408', 'Restyl 0.5', 'Alprazolam', '3d6b896e-e659-4170-975b-b10e7dcf0010', 'Alprazolam 0.5mg', 'Torrent', '3004', 12.00, 'H1', 'Tablet', '30 Tablets', 62.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('8ea8534a-8e3b-4242-9150-7fbecc93dfc7', 'Valium 5', 'Diazepam', '7c1b6b21-fe5b-4c50-8652-447457a60e74', 'Diazepam 5mg', 'Roche', '3004', 12.00, 'H1', 'Tablet', '10 Tablets', 38.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('836506c4-963f-4c9f-b72c-b84dee3c524f', 'Zoldem 10', 'Zolpidem Tartrate', '9a1e08c1-210a-48d1-b249-20262b56a4fd', 'Zolpidem 10mg', 'Sun Pharma', '3004', 12.00, 'H1', 'Tablet', '10 Tablets', 85.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('c1436b04-72f9-4bb1-bb76-0066bfb7a04f', 'Zoloft 50', 'Sertraline HCl', '853ad850-1b55-472e-9add-d94726df11c5', 'Sertraline 50mg', 'Pfizer', '3004', 12.00, 'H', 'Tablet', '14 Tablets', 195.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('5927a49a-9f53-4234-915b-6da1eae14935', 'Serta 50', 'Sertraline HCl', '853ad850-1b55-472e-9add-d94726df11c5', 'Sertraline 50mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '14 Tablets', 125.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('cfead435-a4f4-4458-a6dd-8d257a602c42', 'Nexito 10', 'Escitalopram Oxalate', '585511b8-6bef-4e18-b785-c831b7fd74c8', 'Escitalopram 10mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 145.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('3022ccda-11ca-4531-96a7-ba3bd6f232c0', 'Cipralex 10', 'Escitalopram Oxalate', '585511b8-6bef-4e18-b785-c831b7fd74c8', 'Escitalopram 10mg', 'Lundbeck', '3004', 12.00, 'H', 'Tablet', '14 Tablets', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('fcc6c3b1-29b8-4640-ba55-c99c1c092732', 'Flunil 20', 'Fluoxetine HCl', '6f1093bf-058b-4fe2-bd29-08a43eae0512', 'Fluoxetine 20mg', 'Intas', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 75.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('fec2f6cb-0771-413a-aa6a-2507fad0a070', 'Prozac 20', 'Fluoxetine HCl', '6f1093bf-058b-4fe2-bd29-08a43eae0512', 'Fluoxetine 20mg', 'Eli Lilly', '3004', 12.00, 'H', 'Capsule', '14 Capsules', 195.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('1e468cd5-94c8-4863-a0e5-193e0e2343e1', 'Tryptomer 10', 'Amitriptyline HCl', 'c21a5d90-1c4a-4602-ae5f-90c88d500ed4', 'Amitriptyline 10mg', 'Merck', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 22.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('d3fa9cff-8fc6-49e5-a3a1-dcfea7f451a3', 'Venlor 75', 'Venlafaxine HCl', '07011b9a-4cee-4305-a003-8a45b14cc81c', 'Venlafaxine 75mg', 'Cipla', '3004', 12.00, 'H', 'Capsule', '14 Capsules', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('7d872424-cb17-4e9e-9b08-a6f7bb0bd564', 'Cymbalta 60', 'Duloxetine HCl', 'd39a574e-45cb-4fad-90d4-67ed9fa6559f', 'Duloxetine 60mg', 'Eli Lilly', '3004', 12.00, 'H', 'Capsule', '14 Capsules', 385.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('fbe55c95-3d5a-4145-adab-0f633d44ae40', 'Duzela 30', 'Duloxetine HCl', 'd39a574e-45cb-4fad-90d4-67ed9fa6559f', 'Duloxetine 30mg', 'Sun Pharma', '3004', 12.00, 'H', 'Capsule', '14 Capsules', 245.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('cb7cef23-2f7c-40b5-b55b-5183125327b0', 'Mirtaz 15', 'Mirtazapine', '58d0c587-a7d0-4523-af7b-31c009e79552', 'Mirtazapine 15mg', 'Torrent', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 145.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('be751f5f-f7a6-46da-8917-19fbdd1b2fa3', 'Thyronorm 50', 'Levothyroxine Sodium', '228a3503-9b4d-4cab-977f-784f6b7e3956', 'Levothyroxine 50mcg', 'Abbott', '3004', 12.00, 'H', 'Tablet', '120 Tablets', 165.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('d423a093-e5ca-410d-bfb1-373725d49b56', 'Thyrox 50', 'Levothyroxine Sodium', '228a3503-9b4d-4cab-977f-784f6b7e3956', 'Levothyroxine 50mcg', 'Cadila', '3004', 12.00, 'H', 'Tablet', '120 Tablets', 135.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('44605b93-930d-456c-b2ae-c3785b44af70', 'Thyronorm 100', 'Levothyroxine Sodium', '228a3503-9b4d-4cab-977f-784f6b7e3956', 'Levothyroxine 100mcg', 'Abbott', '3004', 12.00, 'H', 'Tablet', '120 Tablets', 195.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('3df44f83-0589-413c-a3e7-53230a6bc9c7', 'Neomercazole 5', 'Carbimazole', '27dc64ea-bc85-4524-900f-82dd6c7dc21b', 'Carbimazole 5mg', 'Roche', '3004', 12.00, 'H', 'Tablet', '100 Tablets', 145.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('94d81376-45f6-41ff-824d-d4dffd9be318', 'Forcan 150', 'Fluconazole', '9f7d7d83-a473-4af7-a876-4cdf34436ddf', 'Fluconazole 150mg', 'Cipla', '3004', 12.00, 'H', 'Capsule', '1 Capsule', 28.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('d0191b35-ac73-4f7b-b0f6-b459c16ff4b7', 'Diflucan 150', 'Fluconazole', '9f7d7d83-a473-4af7-a876-4cdf34436ddf', 'Fluconazole 150mg', 'Pfizer', '3004', 12.00, 'H', 'Capsule', '1 Capsule', 65.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('bb825613-74a6-466d-b37d-b726426ed333', 'Itrazole 100', 'Itraconazole', '5fbb8d2f-1cd2-40d4-b103-fecc0094e201', 'Itraconazole 100mg', 'Sun Pharma', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 185.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('bbf41f5a-c7f9-4e87-aef4-bac331bc85da', 'Canesten 1%', 'Clotrimazole', 'bdcf6ffd-b6e4-489e-9669-16bb5107f39a', 'Clotrimazole 1% w/w', 'Bayer', '3004', 12.00, 'GENERAL', 'Cream', '20g', 85.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('843dd4d5-656f-417d-90b7-0ef9242f2250', 'Candid B', 'Clotrimazole+Beclomethasone', 'bdcf6ffd-b6e4-489e-9669-16bb5107f39a', 'Clotrimazole 1% + Beclomethasone 0.025%', 'Glenmark', '3004', 12.00, 'H', 'Cream', '20g', 95.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('546df96c-02df-4a76-ba2b-987c0a9048d6', 'Terbicip 250', 'Terbinafine HCl', 'f53f6906-8c24-4336-9701-5661f3ab73e7', 'Terbinafine 250mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '14 Tablets', 125.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('07d9c8b5-6030-40ac-a809-c2ac7018a8fd', 'Lamisil 250', 'Terbinafine HCl', 'f53f6906-8c24-4336-9701-5661f3ab73e7', 'Terbinafine 250mg', 'Novartis', '3004', 12.00, 'H', 'Tablet', '14 Tablets', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('7d42bd43-3cb5-4602-999d-e5a79f584a8f', 'Nizral 2%', 'Ketoconazole', 'bd959c95-82bc-41eb-978f-a343b9876603', 'Ketoconazole 2% w/v', 'J B Chemicals', '3004', 12.00, 'H', 'Shampoo', '75ml', 148.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('6b0ef31f-56fa-48f9-9ebe-665e5251b7b7', 'Zovirax 400', 'Acyclovir', '62f9c66e-e0c1-4e9d-ba62-e743730a94c2', 'Acyclovir 400mg', 'GSK', '3004', 12.00, 'H', 'Tablet', '25 Tablets', 145.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('3336ef8d-27cf-4a1f-b5a6-8f2e5d948f1a', 'Acivir 400', 'Acyclovir', '62f9c66e-e0c1-4e9d-ba62-e743730a94c2', 'Acyclovir 400mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '25 Tablets', 98.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('dcafca9c-205a-428b-9a93-e77c78eb1df8', 'Tamiflu 75', 'Oseltamivir Phosphate', '99e2d843-d4aa-48db-aa1a-124789517e7b', 'Oseltamivir 75mg', 'Roche', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 895.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('dd5d7d9c-877d-4a39-8f90-81eaeb042a83', 'Antivir 150', 'Lamivudine', '50b530c2-5668-4a0e-b969-8cb35f5c7734', 'Lamivudine 150mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '60 Tablets', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('96574509-2b68-4772-ad17-5c66b87acfaf', 'Betnovate', 'Betamethasone Valerate', 'ebb5e645-f162-47c4-8732-51f3b680fb68', 'Betamethasone Valerate 0.1%', 'GSK', '3004', 12.00, 'H', 'Cream', '20g', 55.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('e6dee617-8b26-4267-b447-dae51054f330', 'Bactroban', 'Mupirocin', '0ee2978b-8d47-4138-a690-47286ab67d1a', 'Mupirocin 2%', 'GSK', '3004', 12.00, 'H', 'Cream', '5g', 85.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('8128d6dd-62be-4a9a-a3a5-068823f19513', 'Lacto Calamine', 'Calamine', '3a909368-8099-4b38-88c6-56aa7a6e27f1', 'Calamine Lotion', 'Piramal', '3004', 12.00, 'GENERAL', 'Lotion', '120ml', 95.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('f959bfd4-1939-4271-bab8-4e132f939415', 'Scabitor', 'Permethrin', '4e429052-13c3-4a07-881c-0b799675ff2e', 'Permethrin 5%', 'Hegde & Hegde', '3004', 12.00, 'H', 'Cream', '30g', 85.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('bd2032a0-6f37-4e21-8bcb-87b9abbbfea8', 'Hydrocortisone 1%', 'Hydrocortisone', '6301e7bc-280c-4e8b-8c83-4676c259a5cd', 'Hydrocortisone 1%', 'GSK', '3004', 12.00, 'H', 'Cream', '15g', 45.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('72fe90f8-21f1-40a2-b813-c5395291c265', 'Tenovate', 'Clobetasol Propionate', 'c6fad96a-dcc4-4b0b-a82c-db844f866379', 'Clobetasol Propionate 0.05%', 'GSK', '3004', 12.00, 'H', 'Cream', '30g', 65.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('9b7422d2-dddc-48ca-a2cd-3dcdf0c8a8ba', 'Elocon', 'Mometasone Furoate', 'ee4111f7-677f-4e17-ba04-363aed1ca179', 'Mometasone Furoate 0.1%', 'MSD', '3004', 12.00, 'H', 'Cream', '15g', 125.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('27396b97-2b8d-4e78-acbc-708868bac482', 'Lomotil', 'Loperamide HCl', '61698832-44a1-4b79-ac47-14e5936a4477', 'Loperamide 2mg', 'Pfizer', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 22.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('cea11816-00ef-40a7-b461-86c661f73e3f', 'Zentel 400', 'Albendazole', '9302b66a-60c8-4228-884c-f74772c635db', 'Albendazole 400mg', 'GSK', '3004', 12.00, 'GENERAL', 'Tablet', '1 Tablet', 18.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('04ff38ff-deed-4aae-bac6-bd37274be8c3', 'Bendex 400', 'Albendazole', '9302b66a-60c8-4228-884c-f74772c635db', 'Albendazole 400mg', 'Cipla', '3004', 12.00, 'GENERAL', 'Tablet', '1 Tablet', 15.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('02f6dbf5-b725-4aba-b217-27f4014f57d4', 'Vermox 100', 'Mebendazole', '6a61bc46-db31-4eb1-87b2-18cceecff61e', 'Mebendazole 100mg', 'Janssen', '3004', 12.00, 'GENERAL', 'Tablet', '6 Tablets', 28.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('5a6b4507-5a50-4dfa-a36f-48e87641577e', 'Ivecop 12', 'Ivermectin', '6814eda8-ddcb-44a7-a4b0-de0ff4c9b6a8', 'Ivermectin 12mg', 'Menarini', '3004', 12.00, 'H', 'Tablet', '1 Tablet', 38.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('f1124624-2af0-4923-904f-8800a620d27c', 'Purgeron', 'Lactulose', 'b431f7cb-2621-4c68-9eed-520c4bc20c01', 'Lactulose 10g/15ml', 'Cipla', '3004', 12.00, 'GENERAL', 'Syrup', '200ml', 95.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('af952b53-355b-40c3-9271-96071421e6f2', 'Dulcolax 5', 'Bisacodyl', '45fba3d0-5369-49eb-946e-e418219cd89d', 'Bisacodyl 5mg', 'Boehringer', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 38.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('6348b7cc-5163-4966-b493-7d6fcf4ee02c', 'Urimax 0.4', 'Tamsulosin HCl', 'b9f19970-f33d-4042-a4ab-8474270ad0a1', 'Tamsulosin 0.4mg', 'Cipla', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 95.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('4827c87c-d4ae-4ad9-8ed8-6f85d42605b2', 'Flomax 0.4', 'Tamsulosin HCl', 'b9f19970-f33d-4042-a4ab-8474270ad0a1', 'Tamsulosin 0.4mg', 'Boehringer', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 145.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('1673f703-1d01-41cd-a4e7-9dfb43fc36be', 'Manforce 50', 'Sildenafil Citrate', 'ad1dfcb0-d8af-437b-be8b-610b80596a52', 'Sildenafil 50mg', 'Mankind', '3004', 12.00, 'H', 'Tablet', '4 Tablets', 145.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('36c625c8-8094-4eb2-ba18-7cc0c377f992', 'Viagra 50', 'Sildenafil Citrate', 'ad1dfcb0-d8af-437b-be8b-610b80596a52', 'Sildenafil 50mg', 'Pfizer', '3004', 12.00, 'H', 'Tablet', '4 Tablets', 495.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('cd544e50-7acf-4fde-804a-6c39cebcd83a', 'Tadalis 20', 'Tadalafil', '3d962846-5816-4499-a8df-b3473a270524', 'Tadalafil 20mg', 'Ajanta', '3004', 12.00, 'H', 'Tablet', '4 Tablets', 185.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('f7f0e995-716a-4300-bb5c-3dea2f919ad7', 'Megalis 20', 'Tadalafil', '3d962846-5816-4499-a8df-b3473a270524', 'Tadalafil 20mg', 'Macleods', '3004', 12.00, 'H', 'Tablet', '4 Tablets', 165.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('521fb7c6-59e2-4468-8a1e-8fb579def683', 'Susten 200', 'Progesterone', '34ecc33d-50cd-45a1-8602-37cda5dc07a4', 'Progesterone 200mg', 'Sun Pharma', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('97363bc9-8d53-4c65-ae46-e9e68af1301c', 'Mifeprin 200', 'Mifepristone', 'd18b2e10-c952-4647-b339-b42bc0cc17b1', 'Mifepristone 200mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '1 Tablet', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('f8ad429a-8660-4ed1-9ab9-9d1010199273', 'Medrol 4', 'Methylprednisolone', '603c53c9-8623-4714-baac-98cc89810efe', 'Methylprednisolone 4mg', 'Pfizer', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 55.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('d1a8777e-d88c-4502-8c4d-b6cf25c8c0f3', 'Wysolone 5', 'Prednisolone', '9c7482a4-45b2-420a-b30a-24939765b139', 'Prednisolone 5mg', 'Pfizer', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 35.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('6a6cf7e1-48df-455e-b622-69c2ba691620', 'Omnacortil 5', 'Prednisolone', '9c7482a4-45b2-420a-b30a-24939765b139', 'Prednisolone 5mg', 'Macleods', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 28.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('5c652113-181a-4a8d-a712-f7f1f761d141', 'Dexona 0.5', 'Dexamethasone', '0448b341-175c-4ae7-a72e-31f7ee94e0e5', 'Dexamethasone 0.5mg', 'Samarth', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 15.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('74c38b0b-6257-4476-b5cd-316352c55deb', 'Decadron 0.5', 'Dexamethasone', '0448b341-175c-4ae7-a72e-31f7ee94e0e5', 'Dexamethasone 0.5mg', 'MSD', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 22.00, true, true, '2026-06-12 15:36:21.616872+00');
INSERT INTO public.drug_master VALUES
	('175e0260-d118-4eff-85a0-a552ea000fbb', 'Colchicine 0.5', 'Colchicine', 'ef21308e-1514-49dd-8cc4-134a249a7426', 'Colchicine 0.5mg', 'Intas', '3004', 12.00, 'H', 'Tablet', '20 Tablets', 55.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('1e8cf065-5ba5-4061-ac5f-f0f418ea0dc7', 'Zyloric 100', 'Allopurinol', 'ce950b2e-6659-4808-8dca-ecb5fc6898ba', 'Allopurinol 100mg', 'GSK', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 22.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('fde38517-4c43-454a-b45f-025357cfdef8', 'Hcqs 200', 'Hydroxychloroquine Sulphate', 'bd475a71-c35d-49c5-9227-dcbc47bfe925', 'Hydroxychloroquine 200mg', 'Ipca', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 95.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('d627f909-b596-4127-bb40-5542fab5c984', 'Plaquenil 200', 'Hydroxychloroquine Sulphate', 'bd475a71-c35d-49c5-9227-dcbc47bfe925', 'Hydroxychloroquine 200mg', 'Sanofi', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 145.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('42e7a9c3-1123-4d82-9ef0-1f6cb6c0df7c', 'Aspirin 75', 'Aspirin', '7e59ef70-d4ca-4fb9-901e-b1ea60b695ad', 'Aspirin 75mg', 'Bayer', '3004', 12.00, 'GENERAL', 'Tablet', '30 Tablets', 18.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('c7cefbd7-0249-45af-83eb-4dac396929a8', 'Ecosprin 75', 'Aspirin', '7e59ef70-d4ca-4fb9-901e-b1ea60b695ad', 'Aspirin 75mg', 'USV', '3004', 12.00, 'GENERAL', 'Tablet', '30 Tablets', 15.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('c68bdb03-e128-4c0c-ab3f-0e0b97c57f3a', 'Disprin 350', 'Aspirin', '7e59ef70-d4ca-4fb9-901e-b1ea60b695ad', 'Aspirin 350mg', 'Reckitt', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 18.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('6cbf2976-f1cc-4beb-b7d1-5366d55701a3', 'Toradol 10', 'Ketorolac Tromethamine', '52aea09d-29f2-43fb-a2b6-f8ef278a96c7', 'Ketorolac 10mg', 'Roche', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 65.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('4fb32878-8608-4deb-91a0-837abcf1d33f', 'Naprosyn 250', 'Naproxen', '1934bc66-459d-425d-bd67-e9a86670fe2d', 'Naproxen 250mg', 'Roche', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 38.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('fffb24e6-ef8c-488c-b341-1c30b4286ffd', 'Ponstan 500', 'Mefenamic Acid', '0864800f-581b-4296-a5a5-3a6ceba38049', 'Mefenamic Acid 500mg', 'Pfizer', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 28.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('ce604b88-15cc-4379-859d-4780c1b87718', 'Clindac A', 'Clindamycin', 'd8132646-dd0e-4611-8af5-83cf1c3c0c77', 'Clindamycin Phosphate 1%', 'Galderma', '3004', 12.00, 'H', 'Gel', '15g', 95.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('05aa2799-a562-4a9b-b07f-39ee211b8b7c', 'Dalacin C 150', 'Clindamycin', 'd8132646-dd0e-4611-8af5-83cf1c3c0c77', 'Clindamycin 150mg', 'Pfizer', '3004', 12.00, 'H', 'Capsule', '16 Capsules', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('88b64a1b-6cf9-42da-a24b-0c7fe6036f62', 'Althrocin 250', 'Erythromycin', 'a5264fd9-3597-41e9-b954-c199a82a0618', 'Erythromycin 250mg', 'Abbott', '3004', 12.00, 'H', 'Tablet', '20 Tablets', 45.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('2418ed99-b14c-473d-a725-dd02bbaa781e', 'Vantin 200', 'Cefpodoxime', 'd3ff35b2-7d28-430e-addf-d3da8be37e00', 'Cefpodoxime 200mg', 'Pfizer', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 195.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('e8a66b37-5720-4761-b556-b9f25d7c34eb', 'Cefoprox 200', 'Cefpodoxime', 'd3ff35b2-7d28-430e-addf-d3da8be37e00', 'Cefpodoxime 200mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 145.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('16eeb6a9-8bc8-4a27-b50d-5c3131409669', 'Zinnat 250', 'Cefuroxime', 'c59ece1a-28e2-4a51-86f1-00db1a684c35', 'Cefuroxime 250mg', 'GSK', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 295.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('92314721-a3f5-4d4e-9e27-f9eda72a02f9', 'Bactrim', 'Co-trimoxazole', '1d528045-2e25-446a-af77-425c4120a71b', 'Trimethoprim 80mg + Sulfamethoxazole 400mg', 'Roche', '3004', 12.00, 'H', 'Tablet', '20 Tablets', 35.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('28076900-0e87-49f5-be62-ddc765b267e1', 'Sucralfate 1g', 'Sucralfate', 'e9c58cb4-58c0-4dd2-959a-b2a73dab0205', 'Sucralfate 1g', 'Chemo Drug', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 25.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('99b3d51a-c24e-4ade-8fa8-cb8df02d3daf', 'Deslorat 5', 'Desloratadine', '3c7084d2-edf1-4689-8501-1f576f0973b4', 'Desloratadine 5mg', 'MSD', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 85.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('2da4f8ce-6859-4b18-b381-a74bdd8a1bdc', 'Atarax 25', 'Hydroxyzine HCl', '3774c1bd-293b-4881-94f7-edd952cfae2a', 'Hydroxyzine 25mg', 'UCB', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 45.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('2b5927d3-751f-41f2-9cbd-c3932f45b745', 'Glipizide 5', 'Glipizide', '797e4470-13db-467e-a7d7-29230bf4ea53', 'Glipizide 5mg', 'Pfizer', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 42.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('6af8cb3b-6cc8-4836-bf08-5cf2cc93388f', 'Gliclazide MR 30', 'Gliclazide', 'a5524af1-ff29-442b-858b-837562592572', 'Gliclazide 30mg Modified Release', 'Servier', '3004', 12.00, 'H', 'Tablet', '15 Tablets', 85.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('29b92fbd-f515-4d5c-980e-f9088e90ca04', 'Daonil 5', 'Glibenclamide', '38456591-4a1b-4cff-abca-311663f965a0', 'Glibenclamide 5mg', 'Sanofi', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 22.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('5a7c1e63-7d92-4743-af83-07ce1d301cff', 'Jardiance 10', 'Empagliflozin', '8a6de9cf-49b4-454b-b512-228222d1ae5a', 'Empagliflozin 10mg', 'Boehringer', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 485.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('de4d9953-1d26-462f-a88e-8182df03a360', 'Forxiga 10', 'Dapagliflozin', '087a9468-d100-4d84-8ce6-296825765f6c', 'Dapagliflozin 10mg', 'AstraZeneca', '3004', 12.00, 'H', 'Tablet', '14 Tablets', 485.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('4b9ec02e-8a50-4239-bc43-8ccc7d9a9b68', 'Hytaz 12.5', 'Hydrochlorothiazide', '465cd109-27d5-45e8-930e-b2384de7dcb5', 'Hydrochlorothiazide 12.5mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 18.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('bc515b0e-c012-4eed-abe7-6fd8d67e9219', 'Valsartan 80', 'Valsartan', '7cef8659-5c84-4e2d-9d6f-a7e2df9214cd', 'Valsartan 80mg', 'Novartis', '3004', 12.00, 'H', 'Tablet', '14 Tablets', 145.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('4b2d5f8c-113c-4e27-bd5b-194a5869547c', 'Tiova', 'Tiotropium Bromide', '54e2afd1-aeff-44c3-b455-894d235839a6', 'Tiotropium 18mcg', 'Cipla', '3004', 12.00, 'H', 'Inhaler', '30 doses', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('5d781c5d-a64e-4f1c-990f-af552d29e6ad', 'Alex Cough', 'Dextromethorphan HBr', '91c83c5b-a1e9-4f4a-bc29-fc5224015440', 'Dextromethorphan 10mg/5ml', 'Glenmark', '3004', 12.00, 'GENERAL', 'Syrup', '100ml', 68.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('840a126e-b919-4def-aaec-134f94f81754', 'Cobavit', 'Vitamin B12', '0bf94773-d112-4adc-b183-121deeb13dc2', 'Cyanocobalamin 1000mcg/ml', 'East India', '2106', 18.00, 'GENERAL', 'Injection', '1ml Amp', 25.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('189e89fb-7d73-423f-afb9-324929bde06b', 'Thiamine 100', 'Thiamine HCl', '80f3f3dd-0ec6-4c5e-9f21-5a1650b13259', 'Thiamine 100mg', 'Samarth', '2106', 18.00, 'GENERAL', 'Tablet', '30 Tablets', 18.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('ff228228-139d-463a-995b-546613fa4c5d', 'Propylthiouracil 50', 'Propylthiouracil', '934c5ff6-1f76-450c-88d9-f28668196713', 'Propylthiouracil 50mg', 'Astellas', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 65.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('56e862e1-7d8e-4e68-91f1-d9828b88c41c', 'Tenofovir 300', 'Tenofovir', '7eaa1370-98d3-4f74-a2a3-b884f466aa4a', 'Tenofovir Disoproxil Fumarate 300mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('bcdea100-2c5a-44ab-88cc-ba411cfa8280', 'Bromhexine 8', 'Bromhexine HCl', '80a3a1b1-48c5-48bf-bfd7-0bec1f51630e', 'Bromhexine 8mg', 'Boehringer', '3004', 12.00, 'GENERAL', 'Tablet', '20 Tablets', 18.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('6717fa86-7470-4739-8c3f-aee9959ce0b5', 'Riboflavin 5', 'Riboflavin', 'd4d149c9-4aeb-4c40-9e22-a544063b1879', 'Riboflavin 5mg', 'Intas', '2106', 18.00, 'GENERAL', 'Tablet', '30 Tablets', 12.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('059d00fe-1822-4dcd-b51a-6ab4442882c8', 'Pyridoxine 40', 'Pyridoxine HCl', '0854317e-d5ec-4369-a2b2-a59996ffe38e', 'Pyridoxine 40mg', 'Sun Pharma', '2106', 18.00, 'GENERAL', 'Tablet', '30 Tablets', 15.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('0e34c923-f39a-4142-b7bb-c7a44c9e60a3', 'Famocid 20', 'Famotidine', 'da51b2a4-5340-4cd7-bcf1-ec001e01dc1c', 'Famotidine 20mg', 'Sun Pharma', '3004', 12.00, 'GENERAL', 'Tablet', '30 Tablets', 28.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('f6ecd913-3ffa-442b-8ab4-1cacefcd8706', 'Pepcid 20', 'Famotidine', 'da51b2a4-5340-4cd7-bcf1-ec001e01dc1c', 'Famotidine 20mg', 'J B Chemicals', '3004', 12.00, 'GENERAL', 'Tablet', '30 Tablets', 32.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('b422e0b8-1661-4d63-82fd-1472df088c62', 'Lansoprazole 30', 'Lansoprazole', '56dd655b-5099-41ce-b172-f5bff7222269', 'Lansoprazole 30mg', 'Wyeth', '3004', 12.00, 'GENERAL', 'Capsule', '15 Capsules', 95.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('f6e73cf7-1453-42ee-918f-8744fb32e051', 'Metoclopramide 10', 'Metoclopramide HCl', 'f730c971-2443-4a5b-abbf-5a65a3e1a56d', 'Metoclopramide 10mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '30 Tablets', 18.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('3e8d77ad-1008-4319-b4a9-f949d86e5e24', 'Sporanox 100', 'Itraconazole', '5fbb8d2f-1cd2-40d4-b103-fecc0094e201', 'Itraconazole 100mg', 'Janssen', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('b55b7440-ef88-46fd-8c19-b382e9d1a6a3', 'Ferrous Sulphate Plus', 'Ferrous Sulphate', '19632a2d-6c8a-46a9-a168-9c396eb66add', 'Ferrous Sulphate 60mg elemental iron', 'Piramal', '2106', 18.00, 'GENERAL', 'Tablet', '30 Tablets', 22.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('b7984238-c306-4156-a2ea-938140d8e458', 'Zinc Plus', 'Zinc Sulphate', 'd1c96ba6-6df3-4582-a80d-136234a7be8c', 'Zinc Sulphate 20mg elemental zinc', 'Aristo', '2106', 18.00, 'GENERAL', 'Tablet', '30 Tablets', 18.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('501eca51-eabb-4937-a1c9-afad5f04b6ba', 'Bilaxten 20', 'Bilastine', '5d627610-1267-4dea-87de-a51197c1d0a4', 'Bilastine 20mg', 'Menarini', '3004', 12.00, 'GENERAL', 'Tablet', '10 Tablets', 185.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('8a3543ea-b263-4088-828e-3afbcaa41bca', 'Teneligliptin 20', 'Teneligliptin', 'df8f5e3c-3d0b-41eb-8d3d-21d3383fbd1b', 'Teneligliptin 20mg', 'Glenmark', '3004', 12.00, 'H', 'Tablet', '10 Tablets', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('e43331ee-745c-4e55-b34b-7a11912b5287', 'Ampicillin 500', 'Ampicillin', '065c9a10-7775-423c-8c02-53232694932a', 'Ampicillin 500mg', 'Alkem', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 35.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('2b4dd557-5664-445d-9bca-b8e10ba96825', 'Tetracycline 500', 'Tetracycline', 'f6e815a4-6df7-4ce4-b251-570794fba009', 'Tetracycline 500mg', 'Pfizer', '3004', 12.00, 'H', 'Capsule', '10 Capsules', 22.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('cf15f195-01b8-43ec-908a-27c12a6876b8', 'Chlorphenamine 4', 'Chlorpheniramine Maleate', 'eca21dc9-6ffb-4354-894c-829a66755e3b', 'Chlorpheniramine 4mg', 'Sun Pharma', '3004', 12.00, 'GENERAL', 'Tablet', '20 Tablets', 12.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('690a8b9b-121b-437c-bc0c-d8de1ccad576', 'Piriton 4mg', 'Chlorpheniramine Maleate', 'eca21dc9-6ffb-4354-894c-829a66755e3b', 'Chlorpheniramine 4mg', 'GSK', '3004', 12.00, 'GENERAL', 'Tablet', '20 Tablets', 15.00, false, true, '2026-06-12 15:36:21.616872+00'),
	('f9bc580c-da3c-444c-b17b-94c4b2ae2f4c', 'Lantus', 'Insulin Regular', 'a842f80d-9441-4a30-8c01-d24efad8d4cf', 'Insulin Glargine 100IU/ml', 'Sanofi', '3004', 12.00, 'H', 'Injection', '10ml Vial', 895.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('441567eb-52e8-4c7f-9d19-6af2dbae609b', 'Actrapid', 'Insulin Regular', 'a842f80d-9441-4a30-8c01-d24efad8d4cf', 'Insulin Regular 100IU/ml', 'Novo Nordisk', '3004', 12.00, 'H', 'Injection', '10ml Vial', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('f1181734-ad21-4380-9353-274cfb126922', 'Insulatard', 'Insulin NPH', '5f479137-3b83-4383-b26d-8c479158d5a7', 'Insulin NPH 100IU/ml', 'Novo Nordisk', '3004', 12.00, 'H', 'Injection', '10ml Vial', 285.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('a2355c48-7a16-456d-8611-0c1efc8dfa1f', 'Insugen N', 'Insulin NPH', '5f479137-3b83-4383-b26d-8c479158d5a7', 'Insulin NPH 100IU/ml', 'Biocon', '3004', 12.00, 'H', 'Injection', '10ml Vial', 245.00, true, true, '2026-06-12 15:36:21.616872+00'),
	('c946cfac-528d-40c7-a4c2-36daf8275ddf', 'Clocip Anti-Fungal Dusting Powder', 'Clotrimazole (1% w/w)', 'bdcf6ffd-b6e4-489e-9669-16bb5107f39a', 'Clotrimazole (1% w/w)', 'Cipla Health Ltd', '3004', 12.00, 'GENERAL', 'Powder', NULL, NULL, false, true, '2026-06-12 15:36:22.208871+00'),
	('c2f3d5ec-d395-4ccf-a4cc-342ab9883eb4', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 3X', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '1 Box of 1 Pack', 155.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('7a98a2c6-d694-4bd6-9f30-8b807f25625b', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 50M', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '1 Box of 1 Pack', 195.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('64b49d3f-a56c-4a7e-8914-eb0eca731de1', 'Cipcal 500 Tablet', 'Calcium carbonate from an organic source (Oyester Shell) Equivalent to Elemental Calcium 500mg, Chloecalciferol IP(Vitamin D3)', 'e26904f6-91a3-447c-830a-e0438654d681', 'Calcium carbonate from an organic source (Oyester Shell) Equivalent to Elemental Calcium 500mg, Chloecalciferol IP(Vitamin D3)', 'Cipla Ltd', '3004', 12.00, 'GENERAL', 'Tablet', NULL, 431.68, false, true, '2026-06-12 15:36:22.208871+00'),
	('7e11627a-8b45-461d-b952-fd9adf8bbe47', 'St. Georges Bach Flower Crab Apple', 'Crab Apple', '07c1490b-a3a5-4a45-b8d1-4219f95246eb', 'Crab Apple', 'St. George''s Homoeopathy', '3004', 12.00, 'GENERAL', 'Other', '1 Bottle of 100 ml', 350.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('b90bfdb3-c091-473b-9143-fdf8d6c3cf02', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 6 CH', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '1 Box of 1 Pack', 106.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('3273dd1a-e604-4dc0-9ca5-29531048803f', 'Adven D-Stress Drop', 'Eschscholtzia Cali.,Lupulus Q,Passiflora Incarnata Q,ZincumMetallicum 6x,Purified water q.s', '466886a0-ec19-4e57-9a90-4f8e6799e6ac', 'Eschscholtzia Cali.,Lupulus Q,Passiflora Incarnata Q,ZincumMetallicum 6x,Purified water q.s', 'Adven Biotech Pvt Ltd', '3004', 12.00, 'GENERAL', 'Drop', '1 Bottle of 30 ml', 220.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('1171739c-7f08-4a79-a1ed-be4c6296615b', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 3X', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 310.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('58051e4d-f525-4b49-88e4-412236007317', 'Saridon Woman, Fast Action Against Abdominal, Body Pain and Headaches Tablet', 'Hyoscine butylbromide 10 mg,Paracetamol 500 mg', '94d3b646-c136-47f8-9eb4-4b054507cc69', 'Hyoscine butylbromide 10 mg,Paracetamol 500 mg', 'Bayer', '3004', 12.00, 'GENERAL', 'Tablet', '1 Strip of 5 tablets', 46.88, false, true, '2026-06-12 15:36:22.208871+00'),
	('734205ae-6398-45f6-803e-fab5acb8aed4', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 50M', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 390.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('6676b5eb-dc3e-49e8-b41c-a093874af223', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 6 CH', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 212.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('e41392e3-4db4-4472-a0b2-1cf9e3f7a904', 'Calodin Eye Drop', 'Potassium iodide,Sodium chloride,Calcium chloride', '5280f048-3a33-4c2b-8408-f80b89292054', 'Potassium iodide,Sodium chloride,Calcium chloride', 'Syntho Pharmaceuticals Pvt Ltd', '3004', 12.00, 'GENERAL', 'Drop', '1 Bottle of 10 ml', 85.31, false, true, '2026-06-12 15:36:22.208871+00'),
	('d77496f0-0226-4984-ad4e-7c62bcda31e5', 'Meditek Diclotek Super Spray (55gm Each)', 'Diclofenac diethylamine Methyl salicylate Menthol', 'db2ebda2-724b-43b8-af24-62703becf893', 'Diclofenac diethylamine Methyl salicylate Menthol', 'Meditek Lifesciences Pvt. Ltd', '3004', 12.00, 'GENERAL', 'Spray', '55gm', 206.25, false, true, '2026-06-12 15:36:22.208871+00'),
	('4580b3d2-3cf6-4da0-a75e-0411d3905e18', 'Gemsoline Soft Gelatin Capsule from Medley for Bone, Joint and Muscle Care', 'Calcitriol (0.25mcg) + Calcium Carbonate (500mg) + Zinc Sulfate (7.5mg)', '33768dba-848a-4366-9705-341393302716', 'Calcitriol (0.25mcg) + Calcium Carbonate (500mg) + Zinc Sulfate (7.5mg)', 'Medley Pharmaceuticals', '3004', 12.00, 'GENERAL', 'Softgel', NULL, 276.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('bd5e24a1-aa15-4719-b4de-43065b0ee407', 'Adven Hemotone Iron Tonic', 'Ferrum lacticum 1X, Ammonium acetate 1X, Natrum phosphoricum 1X, Kalium phosphoricum 1X, Citric acid 1X, Acid phosphoricum 1X', 'b59913b3-89d7-49f9-8ebb-0c4b948e4d35', 'Ferrum lacticum 1X, Ammonium acetate 1X, Natrum phosphoricum 1X, Kalium phosphoricum 1X, Citric acid 1X, Acid phosphoricum 1X', 'Adven Biotech Pvt Ltd', '3004', 12.00, 'GENERAL', 'Syrup', '1 Bottle of 100 ml', 118.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('58c47efd-03bc-4fae-917e-0e92ae5b76aa', 'Lactolook Oral Solution Sugar Free', 'Lactulose (10gm/15ml)', 'b431f7cb-2621-4c68-9eed-520c4bc20c01', 'Lactulose (10gm/15ml)', 'Knoll Healthcare Pvt Ltd', '3004', 12.00, 'GENERAL', 'Oral Solution', '100.0 ml', 129.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('b8f90405-7b0e-47f9-9221-c3bdfdc3e98b', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 3 CH', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '1 Box of 1 Pack', 106.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('53c095cc-316f-468d-a07d-5b8abd81f41d', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 10M', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '1 Box of 1 Pack', 175.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('9ebdc4ba-54b1-4ba9-a761-b0ba18191c3c', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) CM', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 430.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('80f570f6-b6d1-48c6-a6cb-8cfc8e2950d3', 'St. Georges Bach Flower Crab Apple', 'Crab Apple', '07c1490b-a3a5-4a45-b8d1-4219f95246eb', 'Crab Apple', 'St. George''s Homoeopathy', '3004', 12.00, 'GENERAL', 'Other', '1 Bottle of 30 ml', 185.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('5ae0676e-f87d-4ae7-a3e0-f62fa96116de', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 12 CH', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '1 Box of 1 Pack', 106.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('ff6f0834-cde9-41bd-91c3-253a4aff0655', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 1M', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 310.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('8e10c0d8-c8cf-4762-9a01-cd397e82a4c0', 'Easylax L Oral Solution Lemon Sugar Free', 'Lactulose (10gm/15ml)', 'b431f7cb-2621-4c68-9eed-520c4bc20c01', 'Lactulose (10gm/15ml)', 'Cipla Ltd', '3004', 12.00, 'GENERAL', 'Oral Solution', '100.0 ml', 129.15, false, true, '2026-06-12 15:36:22.208871+00'),
	('a419688d-ca62-4b83-8267-58a7c9fb3a11', 'Dr Willmar Schwabe India Sabal Pentarkan Drop', 'Sabal Serrulata,Echinacea Purpurea,Passiflora Incarnata,Cantharis,Mercurius Biliodatus,Excipients,Alcohol', 'd6235bd5-460c-4f82-9054-c6826b06e89c', 'Sabal Serrulata,Echinacea Purpurea,Passiflora Incarnata,Cantharis,Mercurius Biliodatus,Excipients,Alcohol', 'Dr Willmar Schwabe India Pvt Ltd', '3004', 12.00, 'GENERAL', 'Drop', NULL, 430.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('b34ff524-9b27-4dc0-91d5-69bb88d4ea93', 'Easylax L Oral Solution Lemon Sugar Free', 'Lactulose (10gm/15ml)', 'b431f7cb-2621-4c68-9eed-520c4bc20c01', 'Lactulose (10gm/15ml)', 'Cipla Ltd', '3004', 12.00, 'GENERAL', 'Oral Solution', '200.0 ml', 258.30, false, true, '2026-06-12 15:36:22.208871+00'),
	('27f1c91f-b819-4417-bfde-5f020b911697', 'Khadi Pure Herbal Rose Water Natural Skin Toner (210ml Each)', 'Demineralised Water Rose Petals', 'a6d88451-781e-4cdb-8167-96dfe48aba2d', 'Demineralised Water Rose Petals', 'Khadi Pure Gramodyog', '3004', 12.00, 'GENERAL', 'Other', '210ml', 240.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('3b2dde82-c31a-4389-9977-9913cb382ae7', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 30 CH', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 106.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('d1468c53-2960-4c03-afc1-c5ade379d677', 'Khadi Pure Herbal Cucumber Water Natural Skin Toner (210ml Each)', 'Cucumber Demineralised Water', 'afdf697d-a213-42c9-90d6-cae10ca69f16', 'Cucumber Demineralised Water', 'Khadi Pure Gramodyog', '3004', 12.00, 'GENERAL', 'Other', '210ml', 240.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('d3d91a27-241e-45a4-9a64-72c5c4ec03c0', 'Alloes Alodust Antifungal Clotrimazole Absorbent Powder (100gm Each)', 'Clotrimazole', 'bdcf6ffd-b6e4-489e-9669-16bb5107f39a', 'Clotrimazole', 'Alloes Pharmaceuticals', '3004', 12.00, 'GENERAL', 'Powder', '100gm', 240.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('a63a349a-fc53-43fe-b0c3-c475f938a12b', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 1M', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '1 Box of 1 Pack', 155.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('4b4d4cdc-5c97-4cf4-84db-581b2f79e0a2', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 200 CH', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 160.31, false, true, '2026-06-12 15:36:22.208871+00'),
	('9a201f30-ab6a-4bd8-b25c-323ccd47c906', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 3 CH', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 212.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('9168bb23-d187-400a-91f6-9511c19c07fe', 'Canesten Antifungal Dusting Powder', 'Clotrimazole IP 1% w/w,Talc 52.25 - 65.0 w/w,Starch 35.0-50.0,Cabosil 0.15-0.22,Perfume 0.75-1.0', '4e52e18f-9f9f-4653-83b9-192e3e66c1ac', 'Clotrimazole IP 1% w/w,Talc 52.25 - 65.0 w/w,Starch 35.0-50.0,Cabosil 0.15-0.22,Perfume 0.75-1.0', 'Bayer Pharmaceuticals Pvt Ltd', '3004', 12.00, 'GENERAL', 'Powder', '1 Box of 50 gm', 75.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('2efd9e84-cc73-4bc4-9c00-24f49104b9e7', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) CM', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '1 Box of 1 Pack', 215.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('7c1e4bda-46bb-4ad7-92f8-c4b72676f6fd', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 10M', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 350.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('8f99200d-01f2-4977-a766-ca5dc9d47816', 'Dr. Majumder Homeo World Calcarea Picrata Dilution(30ml Each) 12 CH', 'Calcarea Picrata', '1bb68353-8309-4a76-911b-e4b938d0c9eb', 'Calcarea Picrata', 'Boericke Homoeo Pharmacy', '3004', 12.00, 'GENERAL', 'Dilution', '30ml', 212.00, false, true, '2026-06-12 15:36:22.208871+00'),
	('2c625793-864b-4949-a9e4-5d9ab5d6ebb1', 'Jardiance 25', 'Empagliflozin', '8a6de9cf-49b4-454b-b512-228222d1ae5a', 'Empagliflozin 25mg', 'Boehringer Ingelheim', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('3000dafe-7ce0-46f4-9cca-8106f2dc2833', 'Crocin 500', 'Paracetamol', '5f40d97e-0c74-4d38-895a-645462f6558c', 'Paracetamol 500mg', 'GSK', '3004', 12.00, 'GENERAL', 'Tablet', '15 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('f87ce436-45f3-48b1-8a3a-97cac998d2e4', 'Pan-D', 'Pantoprazole + Domperidone', '6e3de9c9-00e1-475a-9098-2fd98b81989e', 'Pantoprazole 40mg + Domperidone 30mg SR', 'Alkem Laboratories', '3004', 12.00, 'H', 'Capsule', '15 capsules', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('a78cbb60-cc30-47c9-b07f-e9f41164671d', 'Clavam 625', 'Amoxicillin + Clavulanic Acid', 'c4dfd4d3-bbe3-4b67-9927-fd6f6a72deef', 'Amoxicillin 500mg + Clavulanic Acid 125mg', 'Alkem Laboratories', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('2e796e6d-f878-4e52-a362-1b046f9965ee', 'Pyrigesic 500', 'Paracetamol', '5f40d97e-0c74-4d38-895a-645462f6558c', 'Paracetamol 500mg', 'East India Pharmaceutical Works', '3004', 12.00, 'GENERAL', 'Tablet', '10 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('cc3ddd0f-b918-4a52-9ee1-761d7ff8ec80', 'Calpol 500', 'Paracetamol', '5f40d97e-0c74-4d38-895a-645462f6558c', 'Paracetamol 500mg', 'GSK', '3004', 12.00, 'GENERAL', 'Tablet', '15 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('35992c22-0285-4673-a36d-09e5ffacbace', 'Flexon', 'Ibuprofen + Paracetamol', '99c076f9-4df1-4935-8aa9-660e9cde228e', 'Ibuprofen 400mg + Paracetamol 325mg', 'Aristo Pharmaceuticals', '3004', 12.00, 'GENERAL', 'Tablet', '15 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('ef4c393f-c3b6-4994-9aa2-080632576971', 'Hifenac 100', 'Aceclofenac', 'a82353e4-bd5c-4235-8d8a-c1395385c995', 'Aceclofenac 100mg', 'Intas Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('ed835022-fefa-4eb4-b97f-fdf4ba42e16f', 'Omez 20', 'Omeprazole', '766a6b24-4ed1-458e-9c8c-0e62b5f3e2be', 'Omeprazole 20mg', 'Dr. Reddy''s Laboratories', '3004', 12.00, 'H', 'Capsule', '20 capsules', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('a694406c-e9a1-4d8b-b496-ab37cbf50b60', 'Ecosprin AV 75/20', 'Aspirin + Atorvastatin', 'cd19d245-9f95-4910-9ac4-68703152d1e3', 'Aspirin 75mg + Atorvastatin 20mg', 'USV', '3004', 12.00, 'H', 'Capsule', '15 capsules', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('bbe18364-64db-49a8-8db5-2527ca57dcd0', 'Betadine Ointment', 'Povidone Iodine', '6e773639-c8b7-4fa4-b4fb-0d95f0640bd3', 'Povidone Iodine 10% w/w', 'Win Medicare', '3004', 12.00, 'GENERAL', 'Ointment', '20g', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('bd86fb60-4cc8-486c-a705-792a3e2e3e1e', 'Eptoin 100', 'Phenytoin', '492921a9-5a0c-44d7-8ca1-fffca80913c3', 'Phenytoin Sodium 100mg', 'Abbott', '3004', 12.00, 'H', 'Tablet', '120 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('6c007092-905f-42e1-ad7b-f26d2fc1df0a', 'Norilet 400', 'Norfloxacin', '813ed4ce-4190-4c3e-b04d-3a969ff59a85', 'Norfloxacin 400mg', 'Dr. Reddy''s Laboratories', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('7fb28a3b-b78b-49f1-bbab-a248d8d30b8d', 'Pantop 40', 'Pantoprazole', '60d19b93-31bc-473a-886a-88bb35e0fee0', 'Pantoprazole 40mg', 'Aristo Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('8a9e6150-60dd-4284-b79a-cf7cceefd173', 'Lantus Solostar', 'Insulin Glargine', '73df2700-c750-4315-bef4-cb6cd321e446', 'Insulin Glargine 100IU/ml', 'Sanofi', '3004', 12.00, 'H', 'Injection', '3ml prefilled pen', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('edffc6d7-fbea-4411-96e6-40c9a4c68acf', 'Calcimax 500', 'Calcium + Vitamin D3 + Minerals', '1fd4003f-fd34-46d8-9255-75e606d28fc9', 'Calcium + Vitamin D3 + mineral combination', 'Meyer Organics', '3004', 12.00, 'GENERAL', 'Tablet', '30 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('62243a2d-dc34-4414-b92d-2c7c0675fe1b', 'Thyronorm 25', 'Levothyroxine', '6ed65d04-ccc7-4872-bc71-63ed7ec6da6b', 'Levothyroxine Sodium 25mcg', 'Abbott', '3004', 12.00, 'H', 'Tablet', '120 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('02aa2306-2580-410f-8118-a1fb39cb234b', 'Repace 50', 'Losartan', '53c602b9-ed49-4be3-ae74-c5e0090cf05c', 'Losartan Potassium 50mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('a6aba330-2adc-4591-86f1-14563b8184e6', 'Razo 20', 'Rabeprazole', 'a219f111-9720-400f-bc9a-c95650a699b8', 'Rabeprazole 20mg', 'Dr. Reddy''s Laboratories', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('1556ba7f-afcf-4b54-8ad0-1889ab962e77', 'Reactin 50', 'Diclofenac Sodium', 'ae12d15c-14c1-4aad-a976-daad630ac9b3', 'Diclofenac Sodium 50mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('f1da87be-1948-427c-9fc7-fab1f2ae2cb2', 'Oflomac 200', 'Ofloxacin', 'b35104c9-3bc7-4789-b3ca-fba6ec95a2c9', 'Ofloxacin 200mg', 'Macleods Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('e8fcea33-d636-467f-a7de-10a0ea3305c8', 'Doxy-1 L-DR Forte', 'Doxycycline', 'a8860914-3b3e-4bd1-9340-dca77aec5331', 'Doxycycline 100mg', 'USV', '3004', 12.00, 'H', 'Capsule', '10 capsules', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('c7c5c671-0b3d-4353-b4bd-463adb5a4ae9', 'Cremaffin Plus', 'Liquid Paraffin + Milk of Magnesia + Sodium Picosulfate', '0c070287-aa36-4466-83bf-bc8c36c8bb71', 'Laxative combination', 'Abbott', '3004', 12.00, 'GENERAL', 'Syrup', '225ml', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('d9366655-d357-4641-aec4-bcba9d1e4ee9', 'Glimestar 2', 'Glimepiride', '075d8268-1a17-4ba8-831f-36e35331685a', 'Glimepiride 2mg', 'Mankind Pharma', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('d49b39ab-61ff-4414-a23a-4a767aca9cac', 'D-Rise 60K', 'Cholecalciferol', '42cc45e6-b6a9-4eae-b20f-53ec37d24f5a', 'Vitamin D3 60000IU', 'USV', '3004', 12.00, 'GENERAL', 'Capsule', '4 capsules', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('0655b9ef-5635-4789-8dec-75c965674447', 'D-Cold Total', 'Paracetamol + Phenylephrine + Caffeine + Chlorpheniramine', '6d9475ab-9094-4f59-8942-651057cdfe19', 'Cold combination', 'Paras Pharmaceuticals', '3004', 12.00, 'GENERAL', 'Tablet', '10 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('4e829faa-2d79-41b4-9c2a-c48fa9f3aca4', 'Prodep 20', 'Fluoxetine', 'd97e1cde-9d53-4177-8fae-357e7d8bc9b6', 'Fluoxetine 20mg', 'Sun Pharma', '3004', 12.00, 'H', 'Capsule', '10 capsules', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('68696d80-9115-4398-bb34-8a05b532e30a', 'Voveran SR 100', 'Diclofenac Sodium', 'ae12d15c-14c1-4aad-a976-daad630ac9b3', 'Diclofenac Sodium 100mg SR', 'Novartis', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('5e3722a5-f1b7-4b8c-be31-24af3d898dc6', 'Clopilet 75', 'Clopidogrel', '05e120ad-38d9-4f9e-9b25-8ff0c353af22', 'Clopidogrel 75mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('a534fb8a-0f7c-4b60-84b3-33125eba8df8', 'Becosules Z', 'Vitamin B Complex + Zinc', '9f1971c0-cce6-4bfb-9f84-1cfdda77ed38', 'B-complex vitamins + Zinc', 'Pfizer', '3004', 12.00, 'GENERAL', 'Capsule', '20 capsules', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('ab747ac7-7a01-4d8e-9b02-d638a0d54374', 'Glycomet SR 500', 'Metformin', 'fcee7b74-2cf6-4080-88a7-5c22e0442b02', 'Metformin 500mg SR', 'USV', '3004', 12.00, 'H', 'Tablet', '20 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('f2d4a336-4dae-4583-9fb9-18b74f12195c', 'Sompraz-D 40', 'Esomeprazole + Domperidone', '897e58f6-545c-47ed-9635-ade5f8ef05de', 'Esomeprazole 40mg + Domperidone 30mg SR', 'Sun Pharma', '3004', 12.00, 'H', 'Capsule', '15 capsules', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('c56695cb-1dda-468e-b1c0-e66bdb14a76d', 'Zinnat 500', 'Cefuroxime Axetil', '70a52747-40b9-4f67-a111-ff699c9d0fcb', 'Cefuroxime Axetil 500mg', 'GSK', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('3b7ab72a-4881-411e-a6e1-762c1748b548', 'Jardiance 10', 'Empagliflozin', '8a6de9cf-49b4-454b-b512-228222d1ae5a', 'Empagliflozin 10mg', 'Boehringer Ingelheim', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('ce81164b-5a42-4166-a088-0b4893e961a0', 'Lulifin Cream', 'Luliconazole', '6283618f-76ab-4f91-80c4-0aa4e360aae5', 'Luliconazole 1% w/w', 'Sun Pharma', '3004', 12.00, 'H', 'Cream', '30g', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('69403326-7c08-4fff-baa1-8c40531b497f', 'Ascoril LS', 'Ambroxol + Levosalbutamol + Guaifenesin', '4b9cda13-aec8-4704-9860-eacaaf623410', 'Ambroxol 30mg + Levosalbutamol 1mg + Guaifenesin 50mg/5ml', 'Glenmark Pharmaceuticals', '3004', 12.00, 'H', 'Syrup', '100ml', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('19308d61-072a-49aa-a889-85af061b7b01', 'Pregaba 75', 'Pregabalin', 'e6aaaf85-0dc1-432a-9c08-8c18dbadec9a', 'Pregabalin 75mg', 'Torrent Pharmaceuticals', '3004', 12.00, 'H', 'Capsule', '15 capsules', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('a4a07914-65a2-41dd-8320-50da9ed77d2a', 'Istamet 50/500', 'Sitagliptin + Metformin', 'db3931a3-385a-4a57-af1d-dfcc4f98c95d', 'Sitagliptin 50mg + Metformin 500mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('2eb857fa-117b-4ab5-8ea9-99d03ed73634', 'Amlokind-AT', 'Amlodipine + Atenolol', 'b271a586-8f80-4831-994c-639964809050', 'Amlodipine 5mg + Atenolol 50mg', 'Mankind Pharma', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('f5d3174b-2c26-404b-a412-0405f8b2e807', 'Telmikind 40', 'Telmisartan', '6fce570f-5ef1-4c2d-a5bc-6399c9f6a860', 'Telmisartan 40mg', 'Mankind Pharma', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('2d6ea0e3-2f80-4d9d-ae1f-b1f5161961a5', 'Asthalin Syrup', 'Salbutamol', 'c8711728-0ae5-40b3-8ffc-740e99738766', 'Salbutamol 2mg/5ml', 'Cipla', '3004', 12.00, 'H', 'Syrup', '100ml', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('1d51835f-3c5b-4c03-9013-76953866300b', 'Omez-D', 'Omeprazole + Domperidone', '2c9956c1-6ea0-4b37-8152-575593f66970', 'Omeprazole 20mg + Domperidone 10mg', 'Dr. Reddy''s Laboratories', '3004', 12.00, 'H', 'Capsule', '20 capsules', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('e62c9ea1-a9ea-4ba7-bd8f-3e48a5101a03', 'LCZ 5', 'Levocetirizine', '5e16b0cc-ee58-43d7-9304-61c152048b02', 'Levocetirizine 5mg', 'Rapross Pharmaceuticals', '3004', 12.00, 'GENERAL', 'Tablet', '10 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('eb5af7ba-cee2-497a-8282-c9728195aa67', 'Zerodol-P', 'Aceclofenac + Paracetamol', 'b6074f7c-a938-45b3-922d-286471279413', 'Aceclofenac 100mg + Paracetamol 500mg', 'Ipca Laboratories', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('87fc453d-6bd4-4948-8ef3-b751d0137417', 'Sinarest', 'Paracetamol + Phenylephrine + Chlorpheniramine', 'ec06ced4-83bd-462d-9bab-09100bb4c1f5', 'Paracetamol 500mg + Phenylephrine 10mg + Chlorpheniramine 2mg', 'Centaur Pharmaceuticals', '3004', 12.00, 'GENERAL', 'Tablet', '10 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('cd5772b3-22d1-4681-aa78-ce5bf38ac1ef', 'Glycomet GP 1', 'Glimepiride + Metformin', 'c6c0c4be-30d4-408c-80cb-4fe583cddea7', 'Glimepiride 1mg + Metformin 500mg SR', 'USV', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('e522ef90-f3bc-4340-b7e5-f026276cc9b6', 'Uprise-D3 60K', 'Cholecalciferol', '42cc45e6-b6a9-4eae-b20f-53ec37d24f5a', 'Vitamin D3 60000IU', 'Alkem Laboratories', '3004', 12.00, 'GENERAL', 'Capsule', '4 capsules', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('c3ceebdf-af03-440b-a254-c52f8007a9d3', 'Glevo 500', 'Levofloxacin', '8b1fcf6e-cee6-479e-af5d-c28060b7ac56', 'Levofloxacin 500mg', 'Glenmark Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('3bd27891-504c-47d6-ad06-d26884031eda', 'Drotin', 'Drotaverine', 'a5f7674f-e9f2-4361-bf89-6979c7b780c7', 'Drotaverine 40mg', 'Walter Bushnell', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('e91eca3e-495a-4789-b37e-e4e75879de1d', 'Ceftum 500', 'Cefuroxime Axetil', '70a52747-40b9-4f67-a111-ff699c9d0fcb', 'Cefuroxime Axetil 500mg', 'GSK', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('b6198fe2-0fb0-484c-8a6b-88dbae257574', 'Cel-C 500', 'Vitamin C', 'c78c0b09-38e9-4379-b0d8-608f20d46fc4', 'Ascorbic Acid 500mg', 'Cipla', '3004', 12.00, 'GENERAL', 'Tablet', '15 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('0355afdf-62e3-4ddf-9aee-f6b658a53ac2', 'Terbinaforce 250', 'Terbinafine', '92681c2b-2d9d-46bc-89f2-10f77d1c036d', 'Terbinafine 250mg', 'Mankind Pharma', '3004', 12.00, 'H', 'Tablet', '7 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('6c952269-7ffd-4cc0-82f8-7049f666ed4a', 'Trajenta 5', 'Linagliptin', 'ba86f5aa-702f-4d7a-a8e2-0463c9174445', 'Linagliptin 5mg', 'Boehringer Ingelheim', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('20ff2dc5-baaf-4e71-8ad5-777c078ecfd4', 'Taxim-O 200', 'Cefixime', '4265bc8f-d41d-4449-9a59-d2ddb69e3664', 'Cefixime 200mg', 'Alkem Laboratories', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('5e3c43c4-bf01-4e69-b753-6eb500670f4e', 'Zolfresh 10', 'Zolpidem', '038108ac-ac6e-4ab9-8ee9-b6e9a7b1dee0', 'Zolpidem Tartrate 10mg', 'Abbott', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('909fcd48-66c9-446d-a055-b263b502e2a3', 'Okacet 10', 'Cetirizine', '0dcd188e-6623-4c22-a94a-98edfcb6ac79', 'Cetirizine 10mg', 'Cipla', '3004', 12.00, 'GENERAL', 'Tablet', '10 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('9c4425ad-8505-4fca-b38a-c3de2abbdad4', 'Eldoper', 'Loperamide', '1a8f8a58-9619-4366-9791-5b1aac21abaa', 'Loperamide 2mg', 'Micro Labs', '3004', 12.00, 'H', 'Capsule', '10 capsules', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('1b2be990-61d7-4dd4-a538-5f2debe879f4', 'Gelusil MPS', 'Aluminium Hydroxide + Magnesium Hydroxide + Simethicone', '56183e12-c728-4081-b459-f3ec9016ab12', 'Antacid/antiflatulent combination', 'Pfizer', '3004', 12.00, 'GENERAL', 'Tablet', '10 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('6578bb79-a40c-44f7-9c48-22dbafc19cd2', 'Pantocid 40', 'Pantoprazole', '60d19b93-31bc-473a-886a-88bb35e0fee0', 'Pantoprazole 40mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('f0edb870-efab-4485-a2d3-b66ad01986ef', 'Pan 40', 'Pantoprazole', '60d19b93-31bc-473a-886a-88bb35e0fee0', 'Pantoprazole 40mg', 'Alkem Laboratories', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('50bd2826-5c89-4d61-a075-2ba26197ee30', 'Januvia 100', 'Sitagliptin', 'fd0ca9bb-3771-4f92-87dc-4937957051d7', 'Sitagliptin 100mg', 'MSD Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '7 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('afffd721-d8ef-4aa3-86b1-3f349c8ab05b', 'Razo-D', 'Rabeprazole + Domperidone', '4bfec7d4-2e2c-4dae-a571-3e37e9801909', 'Rabeprazole 20mg + Domperidone 30mg SR', 'Dr. Reddy''s Laboratories', '3004', 12.00, 'H', 'Capsule', '15 capsules', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('4e829a11-cf24-4f16-b0c5-d8a9415d4df6', 'Zerodol-SP', 'Aceclofenac + Paracetamol + Serratiopeptidase', '3c8e9eb0-94aa-45b3-929c-43a7a728e982', 'Aceclofenac 100mg + Paracetamol 325mg + Serratiopeptidase 15mg', 'Ipca Laboratories', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('0af5f637-a1b9-467d-8c0e-f6420ec65ebb', 'Nimulid 100', 'Nimesulide', 'd76bccf6-4b49-4017-b3bb-9204060d03c4', 'Nimesulide 100mg', 'Panacea Biotec', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('47bfb28d-7cb0-4980-97b7-4c6d1d58114c', 'Emeset 4', 'Ondansetron', '6d55247f-c9ee-45be-8cf2-65f30c4a32af', 'Ondansetron 4mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('a01e3ae8-2bac-4c1a-820d-e466e1d62aed', 'Dulcoflex 5', 'Bisacodyl', '45fba3d0-5369-49eb-946e-e418219cd89d', 'Bisacodyl 5mg', 'Boehringer Ingelheim', '3004', 12.00, 'GENERAL', 'Tablet', '10 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('8aa32da3-0d9b-4bff-86bd-ae4bbbf4f8ca', 'Concor 5', 'Bisoprolol', '1d085bc1-7e85-4dce-bd01-860abfd134ec', 'Bisoprolol 5mg', 'Merck', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('7a11c4da-b305-4bd1-b29c-814bfb8d3771', 'Metrogyl 400', 'Metronidazole', '5145eac4-9a7e-4c87-ae4b-b07d92c4b0bb', 'Metronidazole 400mg', 'J.B. Chemicals', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('3ebdd485-c70f-46fd-8da1-a1b45f21be05', 'Gabapin 300', 'Gabapentin', 'afc84440-84d7-48f0-96e0-86a3283aefe6', 'Gabapentin 300mg', 'Intas Pharmaceuticals', '3004', 12.00, 'H', 'Capsule', '15 capsules', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('8fdf9826-3c0e-43e4-9968-bc893282260f', 'Augmentin 625 Duo', 'Amoxicillin + Clavulanic Acid', 'c4dfd4d3-bbe3-4b67-9927-fd6f6a72deef', 'Amoxicillin 500mg + Clavulanic Acid 125mg', 'GSK', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('71447f2b-8347-4928-a83c-4902de3d9b15', 'Zerodol 100', 'Aceclofenac', 'a82353e4-bd5c-4235-8d8a-c1395385c995', 'Aceclofenac 100mg', 'Ipca Laboratories', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('d72eb00e-a499-465d-aa3b-5fbb022dee6b', 'Betaloc 50', 'Metoprolol Tartrate', 'b25104c2-ad9a-40c2-a986-31c1d8974eff', 'Metoprolol Tartrate 50mg', 'AstraZeneca', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('3158f0e2-6d5d-4b2c-9a5f-528b46a83db3', 'Asthalin Inhaler', 'Salbutamol', 'c8711728-0ae5-40b3-8ffc-740e99738766', 'Salbutamol 100mcg/dose', 'Cipla', '3004', 12.00, 'H', 'Inhaler', '200 metered doses', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('81299831-68ab-4899-a0a3-f3c662d00240', 'Neurobion Forte', 'Vitamin B Complex', '863a90d7-7ce4-449f-af45-c7c3e3655c1c', 'Thiamine + Riboflavin + Pyridoxine + Cyanocobalamin + Niacinamide', 'Procter & Gamble', '3004', 12.00, 'GENERAL', 'Tablet', '30 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('8d9df851-f514-421c-b27a-0a0d2f8c1019', 'Galvus 50', 'Vildagliptin', '562708f4-fc58-473c-8cd6-4cd482653130', 'Vildagliptin 50mg', 'Novartis', '3004', 12.00, 'H', 'Tablet', '14 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('559f8c04-03e8-4785-ada6-f134bc295f6d', 'Cetzine 10', 'Cetirizine', '0dcd188e-6623-4c22-a94a-98edfcb6ac79', 'Cetirizine 10mg', 'GSK', '3004', 12.00, 'GENERAL', 'Tablet', '10 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('ef2ef3a4-9065-40ac-9106-72a60cc6838b', 'Olmezest 20', 'Olmesartan', '72f68a43-6616-452d-886b-b1c4be9bfc54', 'Olmesartan Medoxomil 20mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('ac1fc4d9-3895-45ce-8a8e-1270f461550e', 'Clonotril 0.5', 'Clonazepam', '0eef57f8-85d6-4e0e-9b68-676992b33de2', 'Clonazepam 0.5mg', 'Torrent Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('d8e2e51e-a31d-49f1-9695-c314d92677e3', 'Telma 80', 'Telmisartan', '6fce570f-5ef1-4c2d-a5bc-6399c9f6a860', 'Telmisartan 80mg', 'Glenmark Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('8dc8aa4e-0ae0-4df6-9c13-5af3d0a363ff', 'Autrin', 'Ferrous Fumarate + Folic Acid + Vitamin B12', 'c9f353c9-882e-439d-a405-8ef356b67b4c', 'Iron, folic acid and B12 combination', 'Pfizer', '3004', 12.00, 'GENERAL', 'Capsule', '30 capsules', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('cdd53c67-92cd-452b-a5da-fb211d44224e', 'Glycomet GP 2', 'Glimepiride + Metformin', 'c6c0c4be-30d4-408c-80cb-4fe583cddea7', 'Glimepiride 2mg + Metformin 500mg SR', 'USV', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('f6b0149b-1b0f-4560-9828-a9bfb3c609b3', 'A to Z Gold', 'Multivitamin + Multimineral', 'e2118331-d3d7-4e88-9979-b9ce3901edd3', 'Multivitamin and multimineral combination', 'Alkem Laboratories', '3004', 12.00, 'GENERAL', 'Capsule', '15 capsules', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('fb9933be-4167-4834-9bae-4704af566abc', 'Allegra 180', 'Fexofenadine', 'f67beb26-1ebd-434c-9811-f5a7fdfe359e', 'Fexofenadine 180mg', 'Sanofi', '3004', 12.00, 'GENERAL', 'Tablet', '10 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('7b3f92d8-e3ee-4fb6-97fc-a02cf7defcd6', 'Mahacef 200', 'Cefixime', '4265bc8f-d41d-4449-9a59-d2ddb69e3664', 'Cefixime 200mg', 'Mankind Pharma', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('02cf44b8-a5ba-40e3-a763-79655d9524ad', 'Drotin-M', 'Drotaverine + Mefenamic Acid', '20aa9ddb-4fdf-4039-92a1-041eeaf83dab', 'Drotaverine 80mg + Mefenamic Acid 250mg', 'Walter Bushnell', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('6de8b46c-7503-44e1-9e4b-f788fe6954d5', 'Zifi 200', 'Cefixime', '4265bc8f-d41d-4449-9a59-d2ddb69e3664', 'Cefixime 200mg', 'FDC', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('70c8047a-cd6c-45c9-9f57-68f9b6752450', 'Budecort 200 Inhaler', 'Budesonide', '85714ca0-1b46-4dc8-a526-54d3b5b6ab26', 'Budesonide 200mcg/dose', 'Cipla', '3004', 12.00, 'H', 'Inhaler', '200 metered doses', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('5d761b0b-ca23-4a55-aa85-59f01596f1c4', 'Becosules', 'Vitamin B Complex', '863a90d7-7ce4-449f-af45-c7c3e3655c1c', 'B-complex vitamins', 'Pfizer', '3004', 12.00, 'GENERAL', 'Capsule', '20 capsules', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('2bc4067b-d475-4895-98d9-141816d2b420', 'Alex Syrup', 'Dextromethorphan + Phenylephrine + Chlorpheniramine', '85264d95-fae4-4e00-b721-371ee88c33e1', 'Cough/cold combination', 'Glenmark Pharmaceuticals', '3004', 12.00, 'H', 'Syrup', '100ml', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('b4d9523f-3a6b-4936-b75f-8d01003bee3b', 'Metolar XR 50', 'Metoprolol Succinate', 'b674433c-92c7-432c-9fdd-b40825a7fc65', 'Metoprolol Succinate 50mg ER', 'Cipla', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('5f447e7a-d3bd-4f30-8a1e-c600e9ce7502', 'Solvin Cold', 'Paracetamol + Phenylephrine + Chlorpheniramine', 'ec06ced4-83bd-462d-9bab-09100bb4c1f5', 'Paracetamol 500mg + Phenylephrine 10mg + Chlorpheniramine 2mg', 'Ipca Laboratories', '3004', 12.00, 'GENERAL', 'Tablet', '10 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('0ffb79db-7127-4e69-bc81-68033238442d', 'Cepodem 200', 'Cefpodoxime Proxetil', '180e84dd-6f1a-46d9-9125-068d9905f5dd', 'Cefpodoxime Proxetil 200mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('26f725be-feb4-43eb-80bd-351bea2e6d09', 'Sysron-N', 'Norethisterone', '347e4fa3-b6cf-4747-948d-50604cd9880a', 'Norethisterone 5mg', 'Systopic Laboratories', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('3aeb5c66-05cb-43fc-b9c0-c3a47fdb36d6', 'Amaryl 1', 'Glimepiride', '075d8268-1a17-4ba8-831f-36e35331685a', 'Glimepiride 1mg', 'Sanofi', '3004', 12.00, 'H', 'Tablet', '30 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('b621e852-66b7-45f4-9836-00fa7ea23126', 'Linezolid 600', 'Linezolid', '2f77b0b9-eef7-460a-9f44-5229e4195a22', 'Linezolid 600mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('03d4262b-95e9-4622-b8c5-d675a4dbd60d', 'Pregalin 75', 'Pregabalin', 'e6aaaf85-0dc1-432a-9c08-8c18dbadec9a', 'Pregabalin 75mg', 'Torrent Pharmaceuticals', '3004', 12.00, 'H', 'Capsule', '15 capsules', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('28f8b9d3-0b3d-4fc5-a489-284d630e9932', 'Cefpodox 200', 'Cefpodoxime Proxetil', '180e84dd-6f1a-46d9-9125-068d9905f5dd', 'Cefpodoxime Proxetil 200mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('ba4ee202-9083-4efd-a3d5-bc0a01aeefbe', 'Domstal 10', 'Domperidone', '38aa8c76-24e9-4abb-aeff-340deff5a7ab', 'Domperidone 10mg', 'Torrent Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('bc5ee438-74a7-4971-9dd8-6594bee66210', 'Teneligliptin 20', 'Teneligliptin', 'df8f5e3c-3d0b-41eb-8d3d-21d3383fbd1b', 'Teneligliptin 20mg', 'Glenmark Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('42234bdc-3be6-4978-9b6f-ab334d8c0b78', 'Nise 100', 'Nimesulide', 'd76bccf6-4b49-4017-b3bb-9204060d03c4', 'Nimesulide 100mg', 'Dr. Reddy''s Laboratories', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('6ea6ecdd-92e4-4c74-b5ae-07e7325e858f', 'Serta 50', 'Sertraline', '41f774df-d1de-4ac4-b57f-02ae05d4dd52', 'Sertraline 50mg', 'Torrent Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('2b5afcac-03ee-4c7d-a2e9-d4ed996a0d15', 'Orofer XT', 'Ferrous Ascorbate + Folic Acid', '9e2e820f-6469-4334-9170-8f7553287223', 'Ferrous Ascorbate + Folic Acid', 'Emcure Pharmaceuticals', '3004', 12.00, 'GENERAL', 'Tablet', '10 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('1d672f5e-9f4d-419c-8106-f697443a8ae6', 'Dexorange', 'Iron + Folic Acid + Vitamin B12', '4d3159b5-b5a0-44c1-9e27-0e7c0d8bfc1c', 'Ferric Ammonium Citrate + Folic Acid + Vitamin B12', 'Franco-Indian Pharmaceuticals', '3004', 12.00, 'GENERAL', 'Syrup', '200ml', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('ef6d58cd-d997-44d9-9837-6697362817e4', 'Pacimol 500', 'Paracetamol', '5f40d97e-0c74-4d38-895a-645462f6558c', 'Paracetamol 500mg', 'Ipca Laboratories', '3004', 12.00, 'GENERAL', 'Tablet', '10 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('d310552a-9961-447a-a34c-7c33b9f4e2cc', 'Meftal 500', 'Mefenamic Acid', '0864800f-581b-4296-a5a5-3a6ceba38049', 'Mefenamic Acid 500mg', 'Blue Cross Laboratories', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('7f1edacd-b451-4931-9f09-336c56fc9bd0', 'Almox 500', 'Amoxicillin', '75543c99-1ff5-41f7-b7a1-94b8a0656c37', 'Amoxicillin 500mg', 'Alkem Laboratories', '3004', 12.00, 'H', 'Capsule', '15 capsules', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('3db822c1-c3aa-441c-b4f0-5c8177f48b1d', 'Janumet 50/500', 'Sitagliptin + Metformin', 'db3931a3-385a-4a57-af1d-dfcc4f98c95d', 'Sitagliptin 50mg + Metformin 500mg', 'MSD Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('40769b8c-7d7e-4568-b3e9-e8f1066c0eb5', 'Levoflox 500', 'Levofloxacin', '8b1fcf6e-cee6-479e-af5d-c28060b7ac56', 'Levofloxacin 500mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('72eef6ae-9a53-4c21-8d28-539c14430d33', 'Avil 25', 'Pheniramine Maleate', 'ec998f03-1caf-409a-b81d-9143b6d17123', 'Pheniramine Maleate 25mg', 'Sanofi', '3004', 12.00, 'GENERAL', 'Tablet', '15 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('1feed6ca-f3ba-4833-8359-b203be153a49', 'Telekast-L', 'Montelukast + Levocetirizine', 'f9765289-2c90-422f-8072-cb331321ba0a', 'Montelukast 10mg + Levocetirizine 5mg', 'Lupin', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('cf2edb82-899b-4a73-ace8-812ee196691a', 'TusQ-DX', 'Dextromethorphan + Chlorpheniramine + Phenylephrine', '5b62efa7-8650-4340-9d2e-08fee0a66f75', 'Cough/cold combination', 'Blue Cross Laboratories', '3004', 12.00, 'H', 'Syrup', '100ml', NULL, true, true, '2026-06-12 15:36:22.323271+00');
INSERT INTO public.drug_master VALUES
	('f7068e66-54f1-41ab-a442-e7456db1a43d', 'Zincovit', 'Multivitamin + Zinc', '10439d5f-ce04-464a-8911-31d4149c89e9', 'Multivitamin, multimineral and zinc combination', 'Apex Laboratories', '3004', 12.00, 'GENERAL', 'Tablet', '15 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('9ef1a74c-0f75-4f1a-966e-941bbc7a1042', 'Pantocid DSR', 'Pantoprazole + Domperidone', '6e3de9c9-00e1-475a-9098-2fd98b81989e', 'Pantoprazole 40mg + Domperidone 30mg SR', 'Sun Pharma', '3004', 12.00, 'H', 'Capsule', '15 capsules', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('1d330be9-baf4-482d-943d-132064393542', 'Meftal-Spas', 'Dicyclomine + Mefenamic Acid', '57c9c9f4-4944-4870-bc61-68712b84442f', 'Dicyclomine 10mg + Mefenamic Acid 250mg', 'Blue Cross Laboratories', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('dc199e59-d85f-4052-90b7-fffdd781952f', 'Ondem 4', 'Ondansetron', '6d55247f-c9ee-45be-8cf2-65f30c4a32af', 'Ondansetron 4mg', 'Alkem Laboratories', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('c208074c-f0f9-4e74-9ddf-ec7e868154e2', 'Telma-AM', 'Telmisartan + Amlodipine', 'fb07adf3-6c18-4934-a2cf-2e2010f245de', 'Telmisartan 40mg + Amlodipine 5mg', 'Glenmark Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('7598e1e6-f43a-465c-9b6f-477dca82dc44', 'Moov Cream', 'Methyl Salicylate + Menthol + Eucalyptus Oil', '4a6cb36f-5be1-4018-b38f-1b9cf33aaf72', 'Topical counter-irritant combination', 'Reckitt', '3004', 12.00, 'GENERAL', 'Cream', '30g', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('2b853287-c217-407b-bd4a-5532708cfcb7', 'Montek LC', 'Montelukast + Levocetirizine', 'f9765289-2c90-422f-8072-cb331321ba0a', 'Montelukast 10mg + Levocetirizine 5mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('af4a187b-59aa-477e-988f-b23e36307fb2', 'Candid-B Cream', 'Clotrimazole + Beclomethasone', '2783099c-9120-4419-a4e5-4660dde50139', 'Clotrimazole 1% + Beclomethasone Dipropionate 0.025%', 'Glenmark Pharmaceuticals', '3004', 12.00, 'H', 'Cream', '20g', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('735ec66d-72f6-4d06-a1b5-4f90553c7400', 'Grilinctus', 'Dextromethorphan + Chlorpheniramine + Ammonium Chloride + Guaifenesin', '29fe22f9-8534-4049-b817-51231edf9fe8', 'Cough syrup combination', 'Franco-Indian Pharmaceuticals', '3004', 12.00, 'H', 'Syrup', '100ml', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('dc566c93-5867-4465-9c20-28510deb5c3a', 'Duphalac', 'Lactulose', 'b431f7cb-2621-4c68-9eed-520c4bc20c01', 'Lactulose 10g/15ml', 'Abbott', '3004', 12.00, 'GENERAL', 'Solution', '100ml', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('53742c7a-73e7-454e-a0a8-51443e39a7d0', 'Rosuvas 10', 'Rosuvastatin', 'd4a03a5a-3952-4c41-be0c-04dc4a4842a8', 'Rosuvastatin 10mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('dcb0f285-0f52-4f14-94c3-137a8cabd49e', 'Amlopres 5', 'Amlodipine', '3cf74858-7993-4111-ba00-865a0f1323f8', 'Amlodipine 5mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '30 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('f214f027-f456-4a4c-a4ea-0b0df2ce5a00', 'Deriphyllin Retard 150', 'Etofylline + Theophylline', '2bf7029a-8ebe-434f-9191-94bc08fb17ae', 'Etofylline 115mg + Theophylline 35mg', 'Zydus Healthcare', '3004', 12.00, 'H', 'Tablet', '30 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('4924ff92-a563-45de-a296-47ebb0aede6d', 'Cabgolin 0.5', 'Cabergoline', 'd318bb07-5ae5-4377-9087-2d0a1cb29156', 'Cabergoline 0.5mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '4 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('f81382fe-3223-4212-89aa-58f163b52541', 'Candid Cream', 'Clotrimazole', 'bdcf6ffd-b6e4-489e-9669-16bb5107f39a', 'Clotrimazole 1% w/w', 'Glenmark Pharmaceuticals', '3004', 12.00, 'GENERAL', 'Cream', '30g', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('b0d3c454-4534-43dc-8672-a7eaae38c802', 'Glimestar 1', 'Glimepiride', '075d8268-1a17-4ba8-831f-36e35331685a', 'Glimepiride 1mg', 'Mankind Pharma', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('bfe49d18-9a7b-4d1b-8850-9141f14e3ff0', 'Ketorol-DT', 'Ketorolac', 'af382bb9-1b07-48d1-9cfc-3302297651b2', 'Ketorolac Tromethamine 10mg', 'Dr. Reddy''s Laboratories', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('f38685db-81e4-4c12-b387-0db6c6731487', 'Mox 500', 'Amoxicillin', '75543c99-1ff5-41f7-b7a1-94b8a0656c37', 'Amoxicillin 500mg', 'Sun Pharma', '3004', 12.00, 'H', 'Capsule', '15 capsules', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('d33490a9-2d63-4aee-b2e1-87063b27c515', 'Canesten Cream', 'Clotrimazole', 'bdcf6ffd-b6e4-489e-9669-16bb5107f39a', 'Clotrimazole 1% w/w', 'Bayer', '3004', 12.00, 'GENERAL', 'Cream', '30g', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('72550e4f-9dfa-4f56-8adb-b999ca2103eb', 'Eltroxin 50', 'Levothyroxine', '6ed65d04-ccc7-4872-bc71-63ed7ec6da6b', 'Levothyroxine Sodium 50mcg', 'GSK', '3004', 12.00, 'H', 'Tablet', '100 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('f7511de2-db81-4f18-9db2-83a409868b23', 'Febrinil 650', 'Paracetamol', '5f40d97e-0c74-4d38-895a-645462f6558c', 'Paracetamol 650mg', 'Alkem Laboratories', '3004', 12.00, 'GENERAL', 'Tablet', '15 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('bbf34cc0-a949-4d3b-adae-e934af13a3aa', 'Ibugesic 400', 'Ibuprofen', '71642ef1-fb08-4b96-89c7-e0e85fd55a1c', 'Ibuprofen 400mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('1516310a-6768-4a88-9abf-1e2980b12af4', 'Soframycin Skin Cream', 'Framycetin', 'd7940fdb-ccd8-4e12-8c96-e7b43a715d06', 'Framycetin 1% w/w', 'Sanofi', '3004', 12.00, 'H', 'Cream', '30g', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('cdd5debb-caac-4f00-8f44-fe6f546377af', 'Thyronorm 100', 'Levothyroxine', '6ed65d04-ccc7-4872-bc71-63ed7ec6da6b', 'Levothyroxine Sodium 100mcg', 'Abbott', '3004', 12.00, 'H', 'Tablet', '120 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('1dfc6308-3a2b-4360-a0bd-83430781fed1', 'Foracort 200 Inhaler', 'Budesonide + Formoterol', '59c099d6-677a-4452-abd0-79aa1139480d', 'Budesonide 200mcg + Formoterol 6mcg/dose', 'Cipla', '3004', 12.00, 'H', 'Inhaler', '120 metered doses', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('e47317b3-2f7b-4d68-9022-e46bb2a577d4', 'Revital H', 'Multivitamin + Ginseng + Minerals', '48cd9338-164d-48bf-9640-33737ff5450c', 'Multivitamin, minerals and ginseng combination', 'Sun Pharma', '3004', 12.00, 'GENERAL', 'Capsule', '30 capsules', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('88f7ad75-670f-495e-954a-ca23cf181d35', 'Tenglyn 20', 'Teneligliptin', 'df8f5e3c-3d0b-41eb-8d3d-21d3383fbd1b', 'Teneligliptin 20mg', 'Zydus Healthcare', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('9d858d61-cf3c-443f-a1eb-bac3ecee4dd3', 'Amaryl 2', 'Glimepiride', '075d8268-1a17-4ba8-831f-36e35331685a', 'Glimepiride 2mg', 'Sanofi', '3004', 12.00, 'H', 'Tablet', '30 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('5af03506-0c80-44b8-92b0-c5d1564a2b89', 'Duolin Inhaler', 'Levosalbutamol + Ipratropium', '002395ac-99bd-456a-a601-1dc82e58d0af', 'Levosalbutamol + Ipratropium Bromide', 'Cipla', '3004', 12.00, 'H', 'Inhaler', '200 metered doses', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('5fd66514-ffa1-4af7-978d-f42a6414b5bc', 'Shelcal HD', 'Calcium + Vitamin D3', 'c727bdc3-32af-4200-b6b7-6afbb31f3163', 'Calcium Carbonate 500mg + Vitamin D3 500IU', 'Torrent Pharmaceuticals', '3004', 12.00, 'GENERAL', 'Tablet', '15 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('6a42e3f4-e0ef-47f5-96ae-b7d39754805d', 'Telma 40', 'Telmisartan', '6fce570f-5ef1-4c2d-a5bc-6399c9f6a860', 'Telmisartan 40mg', 'Glenmark Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('fa5deb41-9239-44f7-be16-eff97491b00f', 'Ganaton OD', 'Itopride', 'a496e3ba-02c1-42a0-8cd4-5cb4d98f5fe1', 'Itopride 150mg SR', 'Abbott', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('b491e6ec-2b6e-4d8a-b850-824679eb5916', 'Thyronorm 50', 'Levothyroxine', '6ed65d04-ccc7-4872-bc71-63ed7ec6da6b', 'Levothyroxine Sodium 50mcg', 'Abbott', '3004', 12.00, 'H', 'Tablet', '120 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('758cd551-33eb-40ee-a2a6-ddbd4fa1108d', 'Aldactone 25', 'Spironolactone', '29ee6163-5fdc-4a09-a9ba-5d57d02437ec', 'Spironolactone 25mg', 'RPG Life Sciences', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('fce1c7df-6d36-449f-8c7f-b1112a09d7f2', 'Volini Gel', 'Diclofenac Diethylamine', '1bc9ba5e-24b3-42e3-98cd-bb282f57d42d', 'Diclofenac Diethylamine 1.16% w/w', 'Sun Pharma', '3004', 12.00, 'GENERAL', 'Gel', '30g', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('3774dc16-91ff-48c8-b0b8-6d40a8dffea7', 'Ecosprin 75', 'Aspirin', '7e59ef70-d4ca-4fb9-901e-b1ea60b695ad', 'Aspirin 75mg EC', 'USV', '3004', 12.00, 'H', 'Tablet', '14 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('5d2b34f3-ca99-4657-a23f-b76f1ea1c57b', 'Stamlo 5', 'Amlodipine', '3cf74858-7993-4111-ba00-865a0f1323f8', 'Amlodipine 5mg', 'Dr. Reddy''s Laboratories', '3004', 12.00, 'H', 'Tablet', '30 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('15db29ab-f48d-426a-8d60-1b589ba246d7', 'Benadryl Cough Formula', 'Diphenhydramine + Ammonium Chloride + Sodium Citrate', '58e1745a-4b7c-4b40-a671-ef40baf7c8b4', 'Cough syrup combination', 'J&J', '3004', 12.00, 'GENERAL', 'Syrup', '150ml', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('7640a393-7db3-4599-94b5-6ae76a801af8', 'Corex DX', 'Chlorpheniramine + Dextromethorphan', 'be54a07a-6ae0-4c96-b3d1-88637d4fd897', 'Chlorpheniramine Maleate + Dextromethorphan Hydrobromide', 'Pfizer', '3004', 12.00, 'H', 'Syrup', '100ml', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('2c355bea-c9fe-4e78-9cba-a4d3d926c654', 'Alprax 0.25', 'Alprazolam', '3d6b896e-e659-4170-975b-b10e7dcf0010', 'Alprazolam 0.25mg', 'Torrent Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('e026f1b1-b390-4350-bde1-a5ee1c3f9b3a', 'T-Bact Ointment', 'Mupirocin', '0ee2978b-8d47-4138-a690-47286ab67d1a', 'Mupirocin 2% w/w', 'GSK', '3004', 12.00, 'H', 'Ointment', '5g', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('8460d0b7-f791-4790-a093-21ad19ca47d1', 'Galvus Met 50/500', 'Vildagliptin + Metformin', '7a2e72ce-8104-458c-ad34-51ab5174bbfb', 'Vildagliptin 50mg + Metformin 500mg', 'Novartis', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('edea2df7-aa43-470c-9116-a5bd101f7517', 'Montair LC', 'Montelukast + Levocetirizine', 'f9765289-2c90-422f-8072-cb331321ba0a', 'Montelukast 10mg + Levocetirizine 5mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('31e7f328-1aa4-4ab7-8162-0d5bfaae1068', 'Glycomet 500', 'Metformin', 'fcee7b74-2cf6-4080-88a7-5c22e0442b02', 'Metformin 500mg', 'USV', '3004', 12.00, 'H', 'Tablet', '20 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('58c737a5-90fb-4146-90d7-040449d9368c', 'Ostocalcium', 'Calcium + Vitamin D3', 'c727bdc3-32af-4200-b6b7-6afbb31f3163', 'Calcium + Vitamin D3 supplement', 'GSK', '3004', 12.00, 'GENERAL', 'Tablet', '30 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('5396da8b-08c5-4cf1-b11b-68c720d6b703', 'Levocet 5', 'Levocetirizine', '5e16b0cc-ee58-43d7-9304-61c152048b02', 'Levocetirizine 5mg', 'Hetero Drugs', '3004', 12.00, 'GENERAL', 'Tablet', '10 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('531d9969-19a2-46a7-9236-478ef8b7fe8a', 'Tayo 60K', 'Cholecalciferol', '42cc45e6-b6a9-4eae-b20f-53ec37d24f5a', 'Vitamin D3 60000IU', 'Eris Lifesciences', '3004', 12.00, 'GENERAL', 'Tablet', '4 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('103dea15-7a2b-4526-bdac-75c05ec74c44', 'Ascoril D Plus', 'Phenylephrine + Chlorpheniramine + Dextromethorphan', 'd50e3b83-4dc1-4a43-bab8-85c416bab58f', 'Cough/cold combination', 'Glenmark Pharmaceuticals', '3004', 12.00, 'H', 'Syrup', '100ml', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('24a8c734-6fe4-4002-8dc5-57cca9a9befb', 'Azithral 500', 'Azithromycin', '55786ce1-26ae-4847-b5a6-ae94bf0322fb', 'Azithromycin 500mg', 'Alembic Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '3 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('dc5d7fb4-0e6a-427d-b1af-923deb92ec6f', 'Telmikind-AM', 'Telmisartan + Amlodipine', 'fb07adf3-6c18-4934-a2cf-2e2010f245de', 'Telmisartan 40mg + Amlodipine 5mg', 'Mankind Pharma', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('f5943b91-c326-4942-a15e-94679c6906c3', 'Atorva 20', 'Atorvastatin', '2df96ef9-44b6-4ac8-a0da-89c3933e8bc7', 'Atorvastatin 20mg', 'Zydus Healthcare', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('40c81485-e6a9-47b6-9795-cd9d3da09598', 'Sompraz 40', 'Esomeprazole', 'c3780c63-1e02-49c3-ac9b-ccad1f725c4c', 'Esomeprazole 40mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('bb260f56-fec8-4179-9206-1ae17fc279da', 'Losar 50', 'Losartan', '53c602b9-ed49-4be3-ae74-c5e0090cf05c', 'Losartan Potassium 50mg', 'Unichem Laboratories', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('d673d7ba-3f8b-4d0b-ae2d-a10460f5f3a2', 'Supradyn Daily', 'Multivitamin + Multimineral', 'e2118331-d3d7-4e88-9979-b9ce3901edd3', 'Multivitamin and multimineral combination', 'Bayer', '3004', 12.00, 'GENERAL', 'Tablet', '15 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('2c236451-b3f5-4bdb-b494-4b60dcc6a0f8', 'Allegra 120', 'Fexofenadine', 'f67beb26-1ebd-434c-9811-f5a7fdfe359e', 'Fexofenadine 120mg', 'Sanofi', '3004', 12.00, 'GENERAL', 'Tablet', '10 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('412be7de-f327-4b83-b61b-f6db2ee659b4', 'Stalopam 10', 'Escitalopram', 'ad7a2639-7a86-43ef-b778-f593ad761b8b', 'Escitalopram 10mg', 'Lundbeck', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('b1f554cd-3e11-414e-be14-4ee9cb63ba6b', 'Doxicip 100', 'Doxycycline', 'a8860914-3b3e-4bd1-9340-dca77aec5331', 'Doxycycline 100mg', 'Cipla', '3004', 12.00, 'H', 'Capsule', '10 capsules', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('141497d6-af78-4c8f-9d78-369e1deef86a', 'Zady 500', 'Azithromycin', '55786ce1-26ae-4847-b5a6-ae94bf0322fb', 'Azithromycin 500mg', 'Mankind Pharma', '3004', 12.00, 'H', 'Tablet', '3 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('03e19b00-e60c-431a-a20d-533fef4de2f2', 'Brufen 400', 'Ibuprofen', '71642ef1-fb08-4b96-89c7-e0e85fd55a1c', 'Ibuprofen 400mg', 'Abbott', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('8edfe627-eccd-4174-af75-68dc8539a9a2', 'Norflox-TZ', 'Norfloxacin + Tinidazole', '0a7fa8d7-aef0-4888-b6cc-44ec6e8f7ae3', 'Norfloxacin 400mg + Tinidazole 600mg', 'Cipla', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('3db5c059-4b84-4e21-872a-8aea70719d27', 'Deplatt 75', 'Clopidogrel', '05e120ad-38d9-4f9e-9b25-8ff0c353af22', 'Clopidogrel 75mg', 'Torrent Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('eac0b156-8545-427a-b62e-340275f4ac52', 'Folvite 5', 'Folic Acid', 'b20dd2a8-554a-44e2-9ac1-304f43b04310', 'Folic Acid 5mg', 'Pfizer', '3004', 12.00, 'GENERAL', 'Tablet', '45 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('9d2b5ac3-b49d-4731-9739-ebe092b33189', 'Shelcal 500', 'Calcium + Vitamin D3', 'c727bdc3-32af-4200-b6b7-6afbb31f3163', 'Calcium Carbonate 500mg + Vitamin D3 250IU', 'Torrent Pharmaceuticals', '3004', 12.00, 'GENERAL', 'Tablet', '15 tablets', NULL, false, true, '2026-06-12 15:36:22.323271+00'),
	('0a19aafd-e013-4d99-939c-bb76fa0f5c81', 'Hifenac-P', 'Aceclofenac + Paracetamol', 'b6074f7c-a938-45b3-922d-286471279413', 'Aceclofenac 100mg + Paracetamol 500mg', 'Intas Pharmaceuticals', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('fbf6a384-76a5-49ee-b5e0-ea58f9ff82bd', 'Moxikind-CV 625', 'Amoxicillin + Clavulanic Acid', 'c4dfd4d3-bbe3-4b67-9927-fd6f6a72deef', 'Amoxicillin 500mg + Clavulanic Acid 125mg', 'Mankind Pharma', '3004', 12.00, 'H', 'Tablet', '10 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('6dbffc19-575c-4b74-afa0-eadc87085b1d', 'Rozavel 10', 'Rosuvastatin', 'd4a03a5a-3952-4c41-be0c-04dc4a4842a8', 'Rosuvastatin 10mg', 'Sun Pharma', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00'),
	('08337519-c1e6-4759-a5cd-7a612308aa82', 'Atorva 10', 'Atorvastatin', '2df96ef9-44b6-4ac8-a0da-89c3933e8bc7', 'Atorvastatin 10mg', 'Zydus Healthcare', '3004', 12.00, 'H', 'Tablet', '15 tablets', NULL, true, true, '2026-06-12 15:36:22.323271+00');

--
-- Data for Name: einvoice; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: email_template; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: email_verification_token; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: employee; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: employee_salary_structure; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: salary_component; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: employee_salary_component; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: entity_attachment; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: entity_comment; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: entry_number_sequence; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: estimate_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: eway_bill; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: exchange_rate; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: expense; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: field_allowance_claim; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: field_attendance; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: field_location_ping; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: field_sales_assignment; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: field_sample_txn; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: field_visit; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: fiscal_period; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: generic_substitution; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.generic_substitution VALUES
	('f2fab693-676b-485b-9670-d56aa4830c67', '7505d73f-5f01-4074-8345-4374e171dab0', '60adbc31-d6a4-41eb-96f3-496cc6d48466', 'Same active ingredient (Paracetamol 500mg). Calpol may be substituted for Crocin at lower cost.', 2.00, true, '2026-06-12 15:36:22.398527+00'),
	('47408444-242c-4c74-8f0a-b15fe407e8bb', '60adbc31-d6a4-41eb-96f3-496cc6d48466', '7505d73f-5f01-4074-8345-4374e171dab0', 'Same active ingredient (Paracetamol 500mg). Crocin may be substituted for Calpol.', 2.00, true, '2026-06-12 15:36:22.398527+00'),
	('6363318f-3f26-4df2-a646-98e236644efe', '7505d73f-5f01-4074-8345-4374e171dab0', '15757225-fbf3-43a4-a49b-7891454c6a00', 'Same active ingredient (Paracetamol 500mg). Paracip is a cost-effective alternative.', 2.00, true, '2026-06-12 15:36:22.398527+00'),
	('fd728e7f-560b-42a8-a670-0cfd42bab5ea', '053b799f-18ad-4e42-9921-8fbefe85f2f0', '868379e0-60ea-42dd-a332-ed08f5c9b370', 'Same active ingredient (Ibuprofen 400mg). Ibugesic is a lower-cost alternative to Brufen.', 3.00, true, '2026-06-12 15:36:22.398527+00'),
	('347a7f6a-8719-4b5b-baf0-6b54ab993963', '868379e0-60ea-42dd-a332-ed08f5c9b370', '053b799f-18ad-4e42-9921-8fbefe85f2f0', 'Same active ingredient (Ibuprofen 400mg). Brufen may be substituted for Ibugesic.', 3.00, true, '2026-06-12 15:36:22.398527+00'),
	('c5b0b1e9-6594-4bb4-a44c-6fe8ccab52f4', 'dc49b93c-2e54-4bba-be85-17f8e7d4c691', 'e33acd72-306b-482b-8d8b-7e11e74784bd', 'Same active ingredient (Omeprazole 20mg). Ocid is a lower-cost bioequivalent alternative.', 4.00, true, '2026-06-12 15:36:22.398527+00'),
	('89f87398-6a2b-4329-b958-4a8dd5af772d', 'ed835022-fefa-4eb4-b97f-fdf4ba42e16f', 'e33acd72-306b-482b-8d8b-7e11e74784bd', 'Same active ingredient (Omeprazole 20mg). Ocid is a lower-cost bioequivalent alternative.', 4.00, true, '2026-06-12 15:36:22.398527+00'),
	('c4af2f2d-1b0b-4a7a-adc5-0c4ce45c3bd8', 'e33acd72-306b-482b-8d8b-7e11e74784bd', 'dc49b93c-2e54-4bba-be85-17f8e7d4c691', 'Same active ingredient (Omeprazole 20mg). Omez may be substituted for Ocid.', 4.00, true, '2026-06-12 15:36:22.398527+00'),
	('c6a4e507-9da8-4215-8757-2915205a185a', 'e33acd72-306b-482b-8d8b-7e11e74784bd', 'ed835022-fefa-4eb4-b97f-fdf4ba42e16f', 'Same active ingredient (Omeprazole 20mg). Omez may be substituted for Ocid.', 4.00, true, '2026-06-12 15:36:22.398527+00'),
	('824052e2-cb51-46b6-89aa-ad6e2005c8e1', '749ec0de-e27c-45a9-8f86-0c6fe285c135', '92ba4c34-f12b-41d3-a09a-e6bf9dda37cc', 'Same active ingredient (Azithromycin 500mg). Azee is a cost-effective alternative to Azithral.', 4.00, true, '2026-06-12 15:36:22.398527+00'),
	('6e9ab0b9-b0e7-4dd8-9c4d-7a54785fc5c4', '24a8c734-6fe4-4002-8dc5-57cca9a9befb', '92ba4c34-f12b-41d3-a09a-e6bf9dda37cc', 'Same active ingredient (Azithromycin 500mg). Azee is a cost-effective alternative to Azithral.', 4.00, true, '2026-06-12 15:36:22.398527+00'),
	('b5c6b750-3402-4a0d-aa4a-fbc048fa23ae', '749ec0de-e27c-45a9-8f86-0c6fe285c135', '9f460619-a048-4128-a9e4-e4f0d21a2763', 'Same active ingredient (Azithromycin 500mg). Zady is a cost-effective alternative to Azithral.', 10.00, true, '2026-06-12 15:36:22.398527+00'),
	('18a5db53-2339-4966-b664-8b3fe7e624ab', '749ec0de-e27c-45a9-8f86-0c6fe285c135', '141497d6-af78-4c8f-9d78-369e1deef86a', 'Same active ingredient (Azithromycin 500mg). Zady is a cost-effective alternative to Azithral.', 10.00, true, '2026-06-12 15:36:22.398527+00'),
	('0013c7d9-24bd-49b6-85d3-9ea71df0a6c3', '24a8c734-6fe4-4002-8dc5-57cca9a9befb', '9f460619-a048-4128-a9e4-e4f0d21a2763', 'Same active ingredient (Azithromycin 500mg). Zady is a cost-effective alternative to Azithral.', 10.00, true, '2026-06-12 15:36:22.398527+00'),
	('20e322c1-e3a2-4b03-93eb-83988175b7df', '24a8c734-6fe4-4002-8dc5-57cca9a9befb', '141497d6-af78-4c8f-9d78-369e1deef86a', 'Same active ingredient (Azithromycin 500mg). Zady is a cost-effective alternative to Azithral.', 10.00, true, '2026-06-12 15:36:22.398527+00'),
	('4e9585d4-19f5-4cd3-80c8-ef97642b5f4f', '3d745fce-ca62-46a6-a5b3-ca137feffa99', 'a6e219c3-1c02-4b87-a151-7f135e13a444', 'Same active ingredient (Pantoprazole 40mg). Pantodac is a lower-cost alternative to Pan 40.', 3.00, true, '2026-06-12 15:36:22.398527+00'),
	('f112cb3d-1e2c-4619-97bc-b03dc0b70f3a', 'f0edb870-efab-4485-a2d3-b66ad01986ef', 'a6e219c3-1c02-4b87-a151-7f135e13a444', 'Same active ingredient (Pantoprazole 40mg). Pantodac is a lower-cost alternative to Pan 40.', 3.00, true, '2026-06-12 15:36:22.398527+00'),
	('6dfa494f-a51e-4245-a206-cf3fa580388c', 'a6e219c3-1c02-4b87-a151-7f135e13a444', '3d745fce-ca62-46a6-a5b3-ca137feffa99', 'Same active ingredient (Pantoprazole 40mg). Pan 40 may be substituted for Pantodac 40.', 3.00, true, '2026-06-12 15:36:22.398527+00'),
	('1d18f465-4707-4c59-8406-76ab9b4baf46', 'a6e219c3-1c02-4b87-a151-7f135e13a444', 'f0edb870-efab-4485-a2d3-b66ad01986ef', 'Same active ingredient (Pantoprazole 40mg). Pan 40 may be substituted for Pantodac 40.', 3.00, true, '2026-06-12 15:36:22.398527+00'),
	('9e4674d2-ce13-4eed-bb27-6e62c62aa9df', 'b49a64dc-c0ad-456b-9f68-8c689c6fd674', '0e523495-674a-4a84-9e98-43660a2f427b', 'Same active ingredient (Ciprofloxacin 500mg). Cifran is a lower-cost alternative to Ciplox.', 4.00, true, '2026-06-12 15:36:22.398527+00'),
	('5c850b79-50a5-484a-a34e-fc91c006c73a', '0e523495-674a-4a84-9e98-43660a2f427b', 'b49a64dc-c0ad-456b-9f68-8c689c6fd674', 'Same active ingredient (Ciprofloxacin 500mg). Ciplox may be substituted for Cifran.', 4.00, true, '2026-06-12 15:36:22.398527+00'),
	('5f8ebac7-01cc-4b51-a048-1399c7bc9a7b', '06692c68-44ec-4106-85be-b1ce51dd9255', '904e212c-eb48-4f92-9e96-d98fe1d39e0a', 'Same active ingredient (Cefixime 200mg). Cefix is a significantly cheaper alternative to Taxim-O.', 20.00, true, '2026-06-12 15:36:22.398527+00'),
	('d7ad37a9-2951-4fa0-8d40-783e8eac4650', '20ff2dc5-baaf-4e71-8ad5-777c078ecfd4', '904e212c-eb48-4f92-9e96-d98fe1d39e0a', 'Same active ingredient (Cefixime 200mg). Cefix is a significantly cheaper alternative to Taxim-O.', 20.00, true, '2026-06-12 15:36:22.398527+00'),
	('af87044a-18c5-49a7-b2dc-64589beab3e3', '904e212c-eb48-4f92-9e96-d98fe1d39e0a', '06692c68-44ec-4106-85be-b1ce51dd9255', 'Same active ingredient (Cefixime 200mg). Taxim-O may be substituted for Cefix 200.', 20.00, true, '2026-06-12 15:36:22.398527+00'),
	('8dabbc49-54ce-45f3-8d9c-2c6da976a5ce', '904e212c-eb48-4f92-9e96-d98fe1d39e0a', '20ff2dc5-baaf-4e71-8ad5-777c078ecfd4', 'Same active ingredient (Cefixime 200mg). Taxim-O may be substituted for Cefix 200.', 20.00, true, '2026-06-12 15:36:22.398527+00');

--
-- Data for Name: gstr2b_entry; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: hsn_gst_master; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.hsn_gst_master VALUES
	('ab4d311c-1b06-4a25-8cbc-f63c79705748', '3002', 'Human blood, vaccines, toxins and cultures', 'PHARMA', 5.00, true, '2026-06-12 15:36:21.716257+00'),
	('5a85ff5d-209b-4e83-9dfe-55b10b120ecf', '3003', 'Medicaments not put up for retail sale', 'PHARMA', 12.00, true, '2026-06-12 15:36:21.716257+00'),
	('25608268-1426-4835-8b1a-a7fb285b75bf', '3004', 'Medicaments put up for retail sale', 'PHARMA', 12.00, true, '2026-06-12 15:36:21.716257+00'),
	('af3500e0-472c-423b-8fa0-940884461551', '3005', 'Wadding, gauze, bandages and similar medical articles', 'PHARMA', 12.00, true, '2026-06-12 15:36:21.716257+00'),
	('262ef23f-adb1-49e1-9b48-673c13058661', '3006', 'Pharmaceutical goods specified in note 4', 'PHARMA', 12.00, true, '2026-06-12 15:36:21.716257+00'),
	('f087928f-5680-4f1b-b9da-54e083229bac', '2106', 'Food preparations and supplements', 'SUPPLEMENT', 18.00, true, '2026-06-12 15:36:21.716257+00'),
	('7d7e11ec-164b-4a21-9e96-88c7b9637508', '9018', 'Medical instruments and appliances', 'MEDICAL_DEVICE', 12.00, true, '2026-06-12 15:36:21.716257+00');

--
-- Data for Name: industry_template; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: industry_feature_config; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: industry_sub_category; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: integration_config; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: integration_sync_log; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: invoice_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: invoice_number_sequence; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: item_supplier; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: item_unit_price; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: workstation; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: operation; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: work_order; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: job_card; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: job_work_order; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: job_work_order_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: journal_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: leave_request; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: manufacturer_master; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.manufacturer_master VALUES
	('77b06faa-55a4-4123-bceb-f498a027163d', 'Abbott', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('24e570e4-1665-455c-87e5-4f6890595e9f', 'Samarth', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('ca2c2e15-da41-47d6-9179-bdf82bb8b066', 'Galderma', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('f7459179-a1e7-49d7-8afc-6274fdca7f34', 'Novo Nordisk', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('a658589f-ce3d-444c-b4ed-18006563cfe5', 'Apex', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('bd3b2089-ebf2-4f5a-a7f3-330861205474', 'UCB', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('c0a671a8-ba1a-4286-86e7-e5825cbb21ec', 'Meyer', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('821691e0-db77-43ef-b9d5-deb4aedc130e', 'Cipla', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('4d0585f2-2c63-46bc-a984-d63ca4e6b488', 'Eli Lilly', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('9ee569d3-a96d-402d-8506-0dbb02d2bd3b', 'Sanofi', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('172030b9-3c13-42da-9f88-1d9256e4e5f6', 'Franco-Indian', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('a9387f8a-9d1f-403e-9419-f31949009245', 'Novartis', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('ea31dbf2-34b6-4f11-a735-9cabb49c29cd', 'Sun Pharma', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('ff1cfaf0-a986-433c-8582-efb91a327252', 'Dr Reddy''s', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('097f337b-e45b-4135-a5d6-d3635a216765', 'Alkem', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('9d3bc2eb-cd82-4fd6-81f4-4fa6bf4916fd', 'Win Medicare', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('33f18499-a78f-4d2d-87da-642751740926', 'J B Chemicals', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('213f6c2a-fea2-47ab-b33c-1e505b10f4da', 'East India', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('c66fb6f0-8bd7-41d5-80a6-17f2ecf9ee6d', 'Johnson', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('e1432394-65fb-40e5-bef1-fe8b2f6f80be', 'Menarini', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('a9d5272b-3cff-4d8f-a54d-77e35a089cdc', 'Reckitt', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('21f2c676-4f19-47d9-b11b-767e32f4778b', 'Macleods', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('67a5861a-789e-4ed1-bed3-f8779e0dc713', 'Micro Labs', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('9687cc7e-ade4-436a-b54c-94648648b7b4', 'Servier', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('71c4c700-f93a-4538-ac8c-d16b73a92984', 'Cadila', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('7bd4b2df-b6fd-4a57-8be8-98027ca2adde', 'Merck', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('524316c0-9079-49b6-a65c-e531f8125f47', 'USV', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('78dbac97-7b5c-4b8c-9399-b3e636f7ac68', 'Piramal', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('e7d0a330-f90e-4630-b588-ed109aa54bdb', 'Panacea', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('00ed6fc7-e20d-4e90-841f-cde88cf7151f', 'Wyeth', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('272271af-eab2-41c8-94a0-e6cf8649d2ec', 'Zydus', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('00c1a53b-57f8-4381-9ff1-ac2a8ea3d158', 'Chemo Drug', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('2e51ea0c-2394-4330-8bd9-c90fdf8d8346', 'Ipca', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('a8957b0c-f8ad-43da-ba2f-cab1703f8e86', 'Aristo', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('947058b7-3eee-43c5-993e-5d404571d708', 'Astellas', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('d4b846b1-27ed-42ad-8e40-79aa928abe1a', 'AstraZeneca', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('d5b711c3-76b2-4890-8fb4-fcf4870f8d1b', 'Lupin', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('663569fe-294f-4453-b0db-7bd6553ebc4a', 'Ajanta', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('f27a9cf3-f210-4da6-b20b-0f19ef636342', 'Mankind', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('ef82136e-6bc1-4ba9-b4c1-10ef328634e8', 'GSK', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('321f1181-118e-44a3-9f06-c725434b92a2', 'Alembic', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('e65b813e-78d9-4776-907a-7b226f809cec', 'Bayer', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('23c33501-97c8-4985-8555-b6101927bd78', 'Boehringer', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('97779cab-badb-49f1-81cb-090a90004b73', 'Torrent', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('1a5eee40-1af3-4352-a0d2-0a950af6a2a4', 'Various', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('03d6a414-d9de-4599-b792-88b62b9f7831', 'Hegde & Hegde', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('a8c7c4af-4181-414c-841f-ba07b78b0558', 'Biocon', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('ba4f7797-8248-4a8c-9d19-9d420241f093', 'Ranbaxy', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('fe38c0c2-06e6-4f0d-8e9a-4afd158a51e4', 'Lundbeck', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('a97c3a03-47b9-46a3-a30d-0caff2a49e13', 'Glenmark', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('337a2412-89e4-4f32-9e3e-d4b5017904d7', 'Roche', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('dc0ba084-8920-4403-a5c4-a91f249f2e9c', 'Daiichi Sankyo', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('6974e8cf-3999-4a28-bdd9-72b5017436fb', 'Janssen', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('128e5e54-93d7-4510-90c1-9ebdf78f1aa2', 'Pfizer', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('b51745f9-598f-47a5-a3f3-4592f23bd030', 'MSD', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('abed31cb-2e14-431f-a71f-baf674517832', 'Intas', NULL, NULL, true, '2026-06-12 15:36:21.716257+00'),
	('909f7175-8d96-4f57-b3f3-6546b68b414c', 'Stadmed', NULL, NULL, true, '2026-06-12 15:36:21.716257+00');

--
-- Data for Name: mrp_run; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: mrp_demand; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: mrp_supply; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: trading_partner; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: network_order; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: network_order_event; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: published_catalog_item; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: network_order_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: qc_template; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: qc_inspection; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: non_conformance_report; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: notification; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: org_ai_settings; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: org_bootstrap_status; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: org_default_account; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: org_feature_flag; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: org_settings; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: password_reset_token; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: payment_match; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: payroll_audit_log; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: payroll_run; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: payroll_document_snapshot; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: payroll_payment; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: payroll_settings; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: payslip; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: payslip_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: period_balance; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: picklist; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: picklist_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: planned_order; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: platform_admin; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: platform_admin_audit; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: pos_cash_register; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: pos_cash_expense; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: posted_document_snapshot; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: prescription_record; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: prescription_record_item; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: price_list_item; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: production_cost_summary; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: scrap_reason_code; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: production_scrap; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: purchase_bill; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: purchase_bill_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: purchase_orders; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: purchase_order_lines; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: purchase_requisition; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: purchase_requisition_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: push_token; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: qc_parameter; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: qc_inspection_result; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: recurring_invoice; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: recurring_invoice_generation; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: refresh_token; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: reminder_log; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: reorder_policy; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: return_order; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: return_order_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: route_beat; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: routing; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: routing_operation; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: sales_receipt; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: stock_movement; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: sales_receipt_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: salesman_target; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: schemes; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: serial_number; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: shipment; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: shipment_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: statutory_payment; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: stock_balance; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: stock_batch_balance; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: stock_count; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: stock_count_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: stock_receipt; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: stock_receipt_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: stock_reservation; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: supplier_performance; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: supply_chain_alert; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: tax_configuration; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: tax_rate; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: tax_group_rate; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: tax_line_item; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: tour_plan; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: tour_plan_entry; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: transfer_order; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: transfer_order_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: uom_conversion; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: user_invitation; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: van_stock_balance; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: van_stock_transfer; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: van_stock_transfer_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: vendor_credit; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: vendor_credit_application; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: vendor_credit_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: vendor_payment; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: vendor_payment_allocation; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: visit_product_log; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: wallet_transaction; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: warehouse_zone; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: whatsapp_message; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: work_order_line; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Data for Name: workflow_step; Type: TABLE DATA; Schema: public; Owner: -
--

--
-- Name: debit_note_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.debit_note_seq', 1001, false);

--
-- PostgreSQL database dump complete
--
