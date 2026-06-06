# MR Salesman App — Backend Wiring Changes

These files wire the standalone MR salesman app (`katasticho-mr-salesman-app`)
to the real backend field-sales API endpoints built in the main katasticho repo.

## What changed (8 files)

| File | What |
|------|------|
| `lib/src/core/network/api_client.dart` | Full API client with all field-sales endpoints (auth, assignments, executions, visits, day-close, dashboard, targets) |
| `lib/src/features/dashboard/today_dashboard_screen.dart` | Real MTD metrics, today's routes, salesman targets with progress bars |
| `lib/src/features/visits/visits_screen.dart` | Full visit lifecycle: route start/complete, GPS check-in/out, skip, record order/collection |
| `lib/src/features/orders/orders_screen.dart` | Lists active visits, record order dialog with SO ID + value |
| `lib/src/features/collections/collections_screen.dart` | Lists active visits, record collection dialog with amount |
| `lib/src/features/sync/sync_screen.dart` | Live backend connectivity check, session info display |
| `lib/src/features/parties/parties_screen.dart` | Placeholder for future ERP contacts integration |
| `lib/src/features/home/home_shell.dart` | Changed `static const _pages` to `final _pages` for stateful widgets |

## How to apply

### Option A: Copy files directly
Copy each file from this directory into the corresponding path in your
`katasticho-mr-salesman-app` repo, replacing the existing files.

### Option B: Apply the patch
From the root of your `katasticho-mr-salesman-app` repo:
```bash
git apply ../katasticho/mr-salesman-app-backend-wiring.patch
```

## Backend endpoints used

All endpoints are at the main katasticho backend (`/api/v1/field-sales/...`):
- `POST /api/v1/auth/login` — login
- `GET /api/v1/auth/me` — verify session
- `GET /api/v1/field-sales/assignments/me` — salesman's assignments
- `GET /api/v1/field-sales/executions/me/today` — today's route executions
- `POST /api/v1/field-sales/executions` — start execution
- `POST /api/v1/field-sales/executions/{id}/start` — start route
- `POST /api/v1/field-sales/executions/{id}/complete` — complete route
- `GET /api/v1/field-sales/executions/{id}/visits` — visits for execution
- `POST /api/v1/field-sales/visits/{id}/check-in` — GPS check-in
- `POST /api/v1/field-sales/visits/{id}/check-out` — GPS check-out
- `POST /api/v1/field-sales/visits/{id}/skip` — skip visit
- `POST /api/v1/field-sales/visits/{id}/record-order` — record order
- `POST /api/v1/field-sales/visits/{id}/record-collection` — record collection
- `POST /api/v1/field-sales/day-close/initiate/{id}` — initiate day close
- `POST /api/v1/field-sales/day-close/{id}/submit` — submit day close
- `GET /api/v1/field-sales/dashboard` — secondary sales dashboard
- `GET /api/v1/field-sales/targets/me` — salesman targets
