# Extended Feature Roadmap Tracker (Post-Core Expansion)

Living tracking document for the specialized extensions beyond the standard ERP core.

| # | Package | Scope | Complexity | Status |
|---|---|---|:---:|:---:|
| **1** | **Single-Entry Voucher Mode** | Tally-style Payment/Receipt/Contra fast voucher screen with auto-balanced double-entry GL generation. | Medium | **[x] COMPLETE** |
| **2** | **Cash-Basis Financial Reporting** | Real-time cash basis vs. accrual basis toggle across Trial Balance, P&L, and Balance Sheet. | Medium | **[x] COMPLETE** |
| **3** | **PDF Visual Template Customizer** | Visual design customizer for invoice & document PDFs (Themes, Colors, QR codes, Column toggles). | Medium | **[x] COMPLETE** |
| **4** | **Direct ZPL / EPL Thermal Barcode Designer** | Visual thermal label layout editor & direct raw ZPL/EPL command stream generator for Zebra/TSC printers. | Medium | **[x] COMPLETE** |
| **5** | **Multi-Step Warehouse Putaway & Bin Routes** | Bin-to-bin staging movements (Receive -> Inspect -> Stage -> Putaway to Bin) with location rules. | Large | **[x] COMPLETE** |
| **6** | **Automated Bank Statement Feeds & AI Auto-Match** | Multi-criteria fuzzy scoring engine (UTR, Amount/Date, Party) for automated statement reconciliations. | Medium | **[x] COMPLETE** |
| **7** | **Inter-Branch Stock In-Transit Tracking & GPS** | Dispatched transfer order tracking with vehicle assignment, driver details, and live GPS telemetry pin map. | Medium | **[x] COMPLETE** |
| **8** | **Recurring Invoices & Subscriptions Engine** | Automated recurring subscription billing with configurable frequencies, cycles, and auto invoice creation. | Medium | **[x] COMPLETE** |
| **9** | **Kenya Statutory, M-Pesa Mobile Money & KRA eTIMS** | Full Kenyan statutory PAYE/SHIF/Housing Levy calculator, Daraja STK Push & M-Pesa collections, and KRA eTIMS fiscalization bridge. | Large | **[x] COMPLETE** |
| **10** | **Multi-Branch Franchising & Master Catalog Sync** | Store directory (COCO/FOFO), central catalog broadcast push, store-specific price overrides with margin floor validation, and monthly turnover royalty settlements. | Large | **[x] COMPLETE** |
| **11** | **Offline POS Visual Sync Inspector & Network Health Monitor** | Real-time HTTP round-trip latency probe, SQLite database health (`PRAGMA integrity_check`), and visual offline queue inspector with retry backoff logs. | Medium | **[x] COMPLETE** |
| **12** | **Financial Flux & Variance Commentary Agent** | Automated MoM, QoQ, YoY comparative GL variance auditing, material cost spike detection, and AI management briefing narrative. | Medium | **[x] COMPLETE** |
| **13** | **13-Week Rolling Cash Flow Runway & Working Capital Simulator** | Forward-looking 13-week rolling liquidity model, AR collection probability, AP due milestones, payroll, statutory tax dates, and interactive "What-If" scenario sandbox. | Large | **[x] COMPLETE** |

---

## Detailed Progress Log

### Package 1: Single-Entry Voucher Mode (Tally-Style Fast Entry)
- [x] Backend DTO: `SingleEntryVoucherRequest.java`
- [x] Backend Service: `SingleEntryVoucherService.java` (translates Payment/Receipt/Contra to balanced `JournalEntry`)
- [x] Backend REST Controller: `SingleEntryVoucherController.java` (`/api/v1/accounting/single-entry-vouchers`)
- [x] Backend Tests: `SingleEntryVoucherServiceTest.java` (100% tests passing)
- [x] Frontend DTO & Repository: `single_entry_voucher_repository.dart`
- [x] Frontend Screen: `single_entry_voucher_screen.dart` with keyboard shortcuts & live running balance
- [x] Routing & Navigation: Added to `app_router.dart` and `shell_screen.dart` under Accounting

### Package 2: Cash-Basis Financial Reporting
- [x] Backend Repository Queries: Cash-basis JPQL queries in `JournalLineRepository.java` (Trial Balance, P&L, Balance Sheet)
- [x] Backend Service: Updated `FinancialReportService.java` with `basis` parameter (`ACCRUAL` vs `CASH`)
- [x] Backend Controller: Updated `FinancialReportController.java` endpoints
- [x] Backend Tests: Added `shouldGenerateTrialBalanceCashBasis` and `shouldGenerateProfitLossCashBasis` in `FinancialReportServiceTest.java`
- [x] Frontend Repository: `report_repository.dart` updated with basis parameter
- [x] Frontend Screens: Added interactive Accrual vs Cash Basis toggle in `trial_balance_screen.dart`, `profit_loss_screen.dart`, and `balance_sheet_screen.dart`

### Package 3: PDF Visual Template Customizer & Document Theme Studio
- [x] Flyway Migration: `V63__pdf_template_settings.sql`
- [x] Backend Domain: `PdfTemplateSetting.java`, `PdfTemplateSettingRepository.java`, DTOs, `PdfTemplateSettingService.java`, `PdfTemplateSettingController.java`
- [x] Backend Tests: `PdfTemplateSettingServiceTest.java`
- [x] Frontend Repository: `pdf_template_repository.dart`
- [x] Frontend Screen: `pdf_template_customizer_screen.dart` with live realistic document preview canvas, color palette, header layout switcher, and column toggles
- [x] Settings Integration: Added tile in `settings_screen.dart` and route in `app_router.dart`

### Package 4: Direct ZPL / EPL Industrial Thermal Barcode Designer & Generator
- [x] Backend DTOs: `BarcodeLabelRequest.java`, `BarcodeLabelResponse.java`
- [x] Backend Service: `ZplLabelGeneratorService.java` (generates ZPL II and EPL industrial command streams with DPI-to-dot conversions)
- [x] Backend Controller: `BarcodeLabelController.java` (`/api/v1/inventory/barcode-labels/generate`)
- [x] Backend Tests: `ZplLabelGeneratorServiceTest.java` (Code 128 & QR code test coverage)
- [x] Frontend Repository: `barcode_label_repository.dart`
- [x] Frontend Screen: `barcode_label_designer_screen.dart` with dimension presets (50x25mm, 100x50mm, 100x150mm), live simulated sticker preview, and raw ZPL clipboard copy
- [x] Routing & Navigation: Added to `app_router.dart` and `shell_screen.dart` under Inventory

### Package 5: Multi-Step Warehouse Putaway & Staging Optimization
- [x] Flyway Migration: `V64__warehouse_putaway_tasks.sql`
- [x] Backend Domain: `WarehousePutawayTask.java`, `WarehousePutawayLine.java`, Repositories, DTOs, `WarehousePutawayService.java`, `WarehousePutawayController.java`
- [x] Backend Tests: `WarehousePutawayServiceTest.java`
- [x] Frontend Repository: `putaway_repository.dart`
- [x] Frontend Screens: `warehouse_putaway_list_screen.dart` and `warehouse_putaway_detail_screen.dart` with bin confirmation modal and status progression
- [x] Routing & Navigation: Added to `app_router.dart` and `shell_screen.dart` under Inventory

### Package 6: Automated Bank Statement Feeds & AI Smart Auto-Match Reconciler
- [x] Flyway Migration: `V65__bank_auto_match_rules.sql`
- [x] Backend Domain: `BankReconciliationRule.java`, `BankAutoMatchSuggestion.java`, Repositories, DTOs, `BankSmartAutoMatchService.java`, `BankAutoMatchController.java`
- [x] Frontend Repository: `bank_auto_match_repository.dart`
- [x] Frontend Screen: `bank_smart_auto_match_screen.dart` with multi-criteria confidence scoring meter (95% UTR, 85% Date/Amount, 70% Party), one-click accept/reject, and bulk reconciliation
- [x] Routing & Navigation: Added to `app_router.dart` and `shell_screen.dart` under Banking

### Package 7: Inter-Branch Stock In-Transit Tracking & Vehicle GPS Live Map
- [x] Flyway Migration: `V66__stock_transfer_transit_telemetry.sql`
- [x] Backend Domain: `TransferOrderDispatch.java`, `TransferOrderTransitEvent.java`, Repositories, DTOs, `StockTransferTransitService.java`, `StockTransferTransitController.java`
- [x] Frontend Repository: `stock_transit_repository.dart`
- [x] Frontend Screen: `stock_transfer_transit_screen.dart` with driver calling, milestone progression, GPS map telemetry simulator, and checkpoint logging
- [x] Routing & Navigation: Added to `app_router.dart` and `shell_screen.dart` under Inventory

### Package 8: Automated Recurring Invoices, Subscriptions & Standing Billing Engine
- [x] Delivered by the established `com.katasticho.erp.recurring` module and baseline `recurring_invoice` schema.
- [x] Backend: templates, lifecycle controls, scheduled and manual generation, audit history, and generated-invoice history are exposed at `/api/v1/recurring-invoices`.
- [x] Flutter: `recurring_invoice_repository.dart` and the recurring invoice screens use that canonical API under Sales.
- [x] Architecture decision: no second `sales.recurring` profile model or `V67` schema is maintained; that duplicate implementation was removed before integration.

### Package 9: Kenya Statutory, M-Pesa Mobile Money Suite & KRA eTIMS Bridge
- [x] Flyway Migration: `V68__kenya_statutory_and_mpesa.sql`
- [x] Backend Domain: `MpesaTransaction.java`, `KraEtimsInvoice.java`, Repositories, DTOs, `KenyaPayeCalculatorService.java`, `MpesaService.java`, `KraEtimsService.java`, Controllers
- [x] Backend Tests: `KenyaPayeCalculatorServiceTest.java`, `MpesaServiceTest.java` (100% tests passing)
- [x] Frontend Repository: `kenya_repository.dart`
- [x] Frontend Screens: `mpesa_dashboard_screen.dart` (collections feed, STK push modal, reconciliation), `kenya_paye_calculator_screen.dart` (PAYE, NSSF Tier I/II, SHIF, Housing Levy)
- [x] Routing & Navigation: Wired into `app_router.dart` and `shell_screen.dart` under Banking & Payroll

### Package 10: Multi-Branch Franchising & Central Master Catalog Sync
- [x] Flyway Migration: `V69__franchise_and_catalog_sync.sql`
- [x] Backend Domain: `FranchiseNode.java`, `FranchiseCatalogPolicy.java`, `BranchItemOverride.java`, `FranchiseRoyaltySettlement.java`, Repositories, DTOs, `FranchiseCatalogSyncService.java`, `FranchiseRoyaltyService.java`, `FranchiseController.java`
- [x] Backend Tests: `FranchiseCatalogSyncServiceTest.java`, `FranchiseRoyaltyServiceTest.java` (100% tests passing)
- [x] Frontend Repository: `franchise_repository.dart`
- [x] Frontend Screens: `franchise_dashboard_screen.dart` (node directory, network KPIs, 1-click catalog push), `branch_price_override_screen.dart` (pricing overrides with margin floor bounds checks), `franchise_royalty_screen.dart` (monthly turnover royalty calculator & invoicing)
- [x] Routing & Navigation: Wired into `app_router.dart` and `shell_screen.dart` under Partner Network

### Package 11: Offline POS Visual Sync Inspector & Network Health Monitor Console
- [x] Frontend Telemetry Service: `network_health_service.dart` (active round-trip HTTP ping probe, packet reliability tracking, sparkline latency history)
- [x] Frontend SQLite Diagnostics: Enhanced `offline_pos_service.dart` with `DatabaseStats`, `PRAGMA integrity_check`, `VACUUM`/`REINDEX`, and single-item `retrySingleReceipt(id)`
- [x] Frontend Inspector Console: `pos_sync_inspector_sheet.dart` (tabbed console with real-time ping telemetry, SQLite health gauges, and expandable offline sales queue inspector)
- [x] POS Counter Integration: Updated `pos_screen.dart` top-bar status chip to display live latency in ms and launch the slide-out inspector console
- [x] Frontend Tests: `offline_pos_test.dart` (5/5 unit tests passed)

### Package 12: Financial Flux & Variance Commentary Agent
- [x] Backend DTOs: `AccountFluxLine.java`, `FinancialFluxReportResponse.java`
- [x] Backend Service: `FluxCommentaryService.java` (MoM, QoQ, YoY comparative GL calculations, safe zero-division percentage shift math, material cost spike & saving classification, and natural language narrative synthesis)
- [x] Backend Controller: `FluxCommentaryController.java` (`/api/v1/reports/flux-commentary`)
- [x] Backend Tests: `FluxCommentaryServiceTest.java` (100% tests passing)
- [x] Frontend Repository: `flux_commentary_repository.dart`
- [x] Frontend Screen: `flux_commentary_screen.dart` (executive commentary card, copy briefing button, KPI delta indicators, top material shift drivers, and searchable ledger table)
- [x] Routing & Navigation: Wired into `reports_hub_screen.dart`, `app_router.dart`, and `shell_screen.dart` under Reports & Financials

### Package 13: 13-Week Rolling Cash Flow Runway & Working Capital Simulator
- [x] Backend DTOs: `CashRunwayWeeklyBucket.java`, `CashRunwayReportResponse.java`, `CashRunwaySimulationRequest.java`
- [x] Backend Service: `CashRunwayService.java` (live liquid cash querying from event-sourced GL, weighted AR collection probability, AP due milestones, PO pipeline, monthly payroll, statutory tax dates, compounding 13-week runway, and what-if simulation)
- [x] Backend Controller: `CashRunwayController.java` (`GET /api/v1/treasury/cash-runway/13-week`, `POST /simulate`)
- [x] Backend Tests: `CashRunwayServiceTest.java` (100% tests passing)
- [x] Frontend Repository: `cash_runway_repository.dart`
- [x] Frontend Screen: `cash_runway_screen.dart` (Runway KPI cards, Deficit alert banner, 13-week trajectory chart, expandable data matrix table, and interactive "What-If" scenario sandbox drawer)
- [x] Routing & Navigation: Wired into `reports_hub_screen.dart`, `app_router.dart`, and `shell_screen.dart` under Reports & Financials


