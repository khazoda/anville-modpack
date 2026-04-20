# GitHub Actions

Automation scripts run by GitHub Actions.

## workflows/publish.yml

Main workflow: builds modpack, creates release, publishes to Modrinth.

## scripts/

- `extract-changelog.sh` - Extracts version section from CHANGELOG.md

## test-workflow-locally.ps1

Tests workflow steps locally: `npm run test`
