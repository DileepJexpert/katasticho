# Database Migration Runbook

This runbook is mandatory before applying schema changes to a pilot or production database.

## Pre-Migration

1. Confirm the current commit SHA and migration list.
2. Run a backup:

```powershell
.\scripts\backup-postgres.ps1 -OutputDir .\backups
```

3. Verify a `.sha256` file was created next to the backup.
4. Confirm application health before the change:

```powershell
curl http://localhost:8080/actuator/health
```

5. Review the new Flyway migration:
   - It must be additive where possible.
   - It must not rewrite old migration files.
   - It must include a rollback note in the PR or deployment checklist.

## Apply Migration

Flyway runs on application startup. Deploy only one backend instance during the migration window.

```powershell
docker compose -f docker-compose.prod.yml up -d --build app
```

## Post-Migration Checks

1. Confirm app health:

```powershell
curl http://localhost:8080/actuator/health
```

2. Confirm Flyway version in DB:

```sql
select installed_rank, version, description, success, installed_on
from flyway_schema_history
order by installed_rank desc
limit 5;
```

3. Smoke test:
   - Login.
   - Open dashboard.
   - Create a draft invoice.
   - Open reports.

## Rollback

Flyway migrations are forward-only. If a migration breaks production:

1. Stop the application.
2. Restore the verified backup:

```powershell
.\scripts\restore-postgres.ps1 -BackupFile .\backups\<backup-file>.dump -Clean
```

3. Redeploy the previous application image/commit.
4. Confirm health and run smoke tests.

## Restore Drill

For pilot readiness, do one restore drill before go-live and then once per month.
