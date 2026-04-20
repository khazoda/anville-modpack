# Local Scripts

## ManageModpack.ps1

Interactive modpack manager with menu:

```powershell
.\ManageModpack.ps1
```

Or use: `npm run manage`

Options:
1. Add mod
2. Remove mod
3. Set new version
4. Prepare release
5. Exit

All operations auto-update CHANGELOG.md.

## Update-Changelog.ps1

Helper function used by ManageModpack.ps1 to append mod names to CHANGELOG.md sections.

## BuildRelease.ps1

Quick build with current version:

```powershell
.\BuildRelease.ps1
```
