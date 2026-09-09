# OpenAPI Contract Artifacts

These files are generated from the running Spring Boot application's
`/v3/api-docs` endpoint. They are never hand-authored.

From `react_app`:

```powershell
npm run contract:sync
npm run contract:check
```

`contract:sync` validates the OpenAPI 3 document and writes:

- `openapi.json`: deterministic source snapshot.
- `openapi-metadata.json`: version, operation count, and SHA-256.
- `openapi-endpoints.csv`: generated endpoint/security ledger.
- `react_app/src/api/generated/schema.d.ts`: generated TypeScript contract.

`contract:check` fails when any generated artifact differs from the committed
snapshot. Override the source only when intentionally validating another
running server:

```powershell
$env:OPENAPI_URL='http://127.0.0.1:8080/v3/api-docs'
npm run contract:sync
```

Do not substitute a hand-written schema when Spring Boot is unavailable. Start
the real application and regenerate the artifacts instead.
