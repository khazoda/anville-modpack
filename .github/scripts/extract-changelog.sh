#!/bin/bash
# Extract only the current version's changelog from CHANGELOG.md
# This is used in the GitHub workflow to get version-specific changes

VERSION=$1
if [ -z "$VERSION" ]; then
    # Try to read from pack.toml
    VERSION=$(grep -oP 'version\s*=\s*"\K[^"]+' pack.toml)
fi

if [ -z "$VERSION" ]; then
    echo "Error: Could not determine version"
    exit 1
fi

echo "Extracting changelog for version $VERSION..."

# Extract everything from ## [$VERSION] until the next ## or end of file
awk -v version="$VERSION" '
    /^## \['"$VERSION"'\]/ { found=1; print; next }
    found && /^## \[/ { exit }
    found { print }
' CHANGELOG.md > current-changelog.md

if [ ! -s current-changelog.md ]; then
    echo "Warning: No changelog found for version $VERSION"
    echo "## Version $VERSION

No changelog provided." > current-changelog.md
fi

echo "✓ Extracted to current-changelog.md"
cat current-changelog.md
