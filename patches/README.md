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

_No pending patches. 0001 (field app major upgrade) was applied and pushed on 2026-06-12._
