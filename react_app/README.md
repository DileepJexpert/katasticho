# Katasticho React Web

The React web client runs in parallel with `flutter_app/` while ERP workflows
are migrated and accepted one at a time. It uses the same Spring Boot API,
database, roles, and organisation boundaries as Flutter.

## Local development

1. Start the Spring Boot backend on `http://localhost:8080` with the `local` profile.
2. Run `npm run dev` in this directory.
3. Open `http://127.0.0.1:5173`.

The Vite proxy keeps API requests same-origin in local development. Browser
refresh tokens use the HttpOnly `katasticho_web_refresh` cookie; access tokens
remain in memory and are never written to browser storage.

## Quality checks

```powershell
npm run lint
npm run test
npm run build
```

OpenAPI generation will be enabled after `/v3/api-docs` returns a valid
document. It is currently tracked as a backend contract issue.
