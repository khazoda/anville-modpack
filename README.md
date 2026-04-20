# Glade Modpack

## Manage Modpack

```powershell
npm run manage
```

Interactive menu for:
1. Add mod
2. Remove mod
3. Set new version
4. Prepare release
5. Exit

## Workflow

1. Run `npm run manage`
2. Add/remove mods as needed (auto-updates CHANGELOG.md)
3. Set new version (creates new changelog section)
4. Prepare release (detects updated mods, builds .mrpack)
5. Commit and push
6. Run GitHub Actions workflow

All changelog updates happen automatically through the manager
