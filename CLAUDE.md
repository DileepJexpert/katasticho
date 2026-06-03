# CLAUDE.md

Reference for working in this repo efficiently. Read this first; avoid re-exploring what's already documented here.

## Stack
- **Backend:** Spring Boot 3.3.5, Java 21, JPA/Hibernate, Flyway, PostgreSQL. Build: Maven (`./mvnw`).
- **Frontend:** Flutter (`flutter_app/`) — Riverpod + GoRouter + Dio.
- **Root layout:** `src/` (backend), `flutter_app/` (mobile/web), `docs/`, `scripts/`, `samples/`, `test-data/`.

## Build & Test
```bash
# Backend compile / test (run from repo root)
./mvnw -q compile
./mvnw -q test
./mvnw -q test -Dtest=ClassName        # single test class

# Flutter
cd flutter_app && flutter analyze
cd flutter_app && flutter test
```

## Backend Architecture
- Package root: `com.katasticho.erp`. Modules by domain: `accounting, ap, ar, auth, banking, contact, dashboard, gst, inventory, loyalty, notification, pharma, pos, pricing, procurement, reporting, sales, tax, workflow`, plus `common` (shared) and `platform`/`admin`.
- **Multi-tenant:** every org-scoped query is filtered by `TenantContext.getCurrentOrgId()`. Org-scoped entities extend the BaseEntity pattern (`org_id`, `is_deleted`, audit timestamps).
- **Controllers** return `ApiResponse.ok(...)` wrapper. Guard with `@PreAuthorize("hasAnyRole(...)")`. Roles: `OWNER, ADMIN, ACCOUNTANT, OPERATOR, VIEWER`.
- **Exceptions:** `BusinessException.notFound("Entity", id)` or `new BusinessException(msg, "CODE", HttpStatus.X)`.
- **Platform-level reference tables** (NO org_id, NO BaseEntity): `salt_master`, `drug_master`, `manufacturer_master`, `hsn_gst_master`, `generic_substitution`, `drug_interaction`. `rack_location` IS org-scoped.

## Flyway Migrations
- Location: `src/main/resources/db/migration/`. Latest is **V36**. Next new migration = V37.
- Use `TIMESTAMPTZ` (not `TIMESTAMP`) for timestamp columns.
- Master tables seeded in V28 (drugs/salts), V29 (pharmacy refs), V34/V36 (drug master seeds).

## Flutter / API Conventions
- **Dio baseUrl = `http://localhost:8080` with NO `/api/v1` prefix** → every API path string must include `/api/v1/...`.
- Endpoint paths live in `flutter_app/lib/core/api/api_config.dart`.
- `apiClientProvider` cascades invalidation across providers.
- Features under `flutter_app/lib/features/<feature>/presentation/...`.

## Accounting Rules (important domain logic)
- **POS receipts** → Cash/Revenue journal, NOT Accounts Receivable.
- **Contact "outstanding"** = openingBalance + invoices − payments (AR only).
- **HSN → GST mapping:** 3004 = 12% (standard medicines), 2106 = 18% (supplements), 3002 = 5% (vaccines).
- **Payment lifecycle:** DRAFT → {POSTED | PENDING_APPROVAL}; PENDING_APPROVAL → {POSTED | VOIDED}.
- **Approval workflows:** seeded but `active=false` by default — nothing triggers until an admin activates.

## Git / Workflow
- Active feature branch: `claude/erp-requirements-doc-g0o1P`. Develop, commit, push here. Do NOT push elsewhere without permission.
- Push with `git push -u origin <branch>`; retry network failures with backoff.
- Do NOT create PRs unless explicitly asked.
- The bulk of existing history is the user's own Codex commits (`DileepJexpert@users.noreply.github.com`) — do not rebase/reauthor them.

## Known Pending Work (audit findings — fix only when asked, by number)
1. Payment over-collection: no cap vs invoice balance (HIGH)
2. Broken report date filter: SQL param mismatch (HIGH)
3. No posted-payment reversal path (HIGH)
4. Self-approval gap in workflows (HIGH)
5. Empty drug-interaction seeds — warfarin not in salt_master (HIGH)
6. Empty generic-substitution seeds (MEDIUM)
7. Delivery challan: no stock validation (MEDIUM)
8–18. Misc design/consistency issues (LOW–MEDIUM)

Also pending: Flutter UI for HSN/rack/substitution masters (backend exists, no screens); Customer Indent decision (removed by Codex, replaced by sales-order backorder).

## Pharmacy Masters (already implemented backend)
- `PharmacyMasterController` @ `/api/v1/pharmacy-masters`: manufacturers/search, hsn/search, hsn/{code}, rack-locations (GET/POST/seed-demo), substitutions, interactions/check.
- `DrugMasterController` @ `/api/v1/drug-master`: search, {id}, salts/search.
