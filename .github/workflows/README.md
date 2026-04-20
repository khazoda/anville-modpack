# GitHub Workflow Setup

## Setup

### Modrinth API Token

1. Go to [Modrinth Settings](https://modrinth.com/settings/account)
2. Create token with scopes: `CREATE_VERSION`, `VERSION_WRITE`

### Add GitHub Secrets

Repository → Settings → Secrets and variables → Actions:
- `MODRINTH_TOKEN` - Your Modrinth API token
- `MODRINTH_PROJECT_ID` - Your project ID (from URL)

## Usage

After pushing changes: Actions → Build & Publish Modpack → Run workflow