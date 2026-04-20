## Publishing

```powershell
npm run release -- -Version "x.x.x"
git add . && git commit -m "Release vx.x.x" && git push
```

Then: Actions → Build & Publish Modpack → Run workflow

## Commands

```powershell
npm run release -- -Version "x.x.x"  # Prepare release
npm run build                         # Build only
npm run test                          # Test workflow
```
