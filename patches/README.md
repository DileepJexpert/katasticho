# Patches for katasticho-mr-salesman-app

Patches developed in Claude Code web sessions, which can only push to the
`katasticho` repo. Apply them to the field app repo locally:

```bash
cd katasticho-mr-salesman-app
git am ../katasticho/patches/0001-fieldapp-major-upgrade.patch
git push origin main
```

If `git am` complains about state, `git am --abort` first. After a patch is
applied and pushed, it can be deleted from this folder.

## 0001-fieldapp-major-upgrade.patch (2026-06-12, baseline aed9d7a)
13 files, +3647/-112: token-refresh interceptor, parties (live contact
search + detail), expenses (connected to /api/v1/expenses), day close
screen, van stock screen, offline sync queue, line-item order builder
(creates real Sales Orders), nav restructure (Day Close tab, Van tab,
Sync in app bar).

Pairs with two ERP-side fixes already on `claude/erp-requirements-doc-g0o1P`:
- OPERATOR may create draft van load/return requests (80c94f1)
- record-order accepts blank salesOrderId for quick-amount orders (5447b3f)
