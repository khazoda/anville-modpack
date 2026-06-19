function Show-Menu {
    $version = (Select-String -Path .\pack.toml -Pattern 'version\s*=\s*"([^"]+)"').Matches.Groups[1].Value
    
    Clear-Host
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host "   Anville Modpack Manager" -ForegroundColor Cyan
    Write-Host "   Current Version: $version" -ForegroundColor Yellow
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Set New Version"
    Write-Host "2. Add Mod"
    Write-Host "3. Remove Mod"
    Write-Host "4. Update All Mods"
    Write-Host "5. Prepare Release"
    Write-Host "6. Exit"
    Write-Host ""
}

function Add-Mod {
    Write-Host "`nAdd Mod" -ForegroundColor Cyan
    
    $platform = Read-Host "Platform (mr/cf)"
    if ($platform -ne "mr" -and $platform -ne "cf") {
        Write-Host "Invalid platform" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }
    
    $modId = Read-Host "Mod ID or slug"
    if ([string]::IsNullOrWhiteSpace($modId)) {
        Write-Host "Mod ID cannot be empty" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }
    
    $cmd = if ($platform -eq "mr") { "packwiz mr add $modId" } else { "packwiz cf add $modId" }
    $output = & cmd /c $cmd 2>&1 | Out-String
    Write-Host $output
    
    if ($output -match 'Project "([^"]+)" successfully added') {
        $modName = $matches[1]
        packwiz refresh | Out-Null
        & "$PSScriptRoot\Update-Changelog.ps1" -ModName $modName -Section "Added"
        Write-Host "`nMod added and changelog updated!" -ForegroundColor Green
    } else {
        Write-Host "Failed to add mod" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to continue"
}

function Remove-Mod {
    Write-Host "`nRemove Mod" -ForegroundColor Cyan
    
    $modInput = Read-Host "Mod name or filename"
    if ([string]::IsNullOrWhiteSpace($modInput)) {
        Write-Host "Mod name cannot be empty" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }
    
    $modName = $modInput
    $metaPath = "mods\$modInput.pw.toml"
    
    if (Test-Path $metaPath) {
        $metaContent = Get-Content $metaPath -Raw
        if ($metaContent -match 'name = "([^"]+)"') {
            $modName = $matches[1]
        }
    } else {
        $metaPath = "resourcepacks\$modInput.pw.toml"
        if (Test-Path $metaPath) {
            $metaContent = Get-Content $metaPath -Raw
            if ($metaContent -match 'name = "([^"]+)"') {
                $modName = $matches[1]
            }
        }
    }
    
    $output = packwiz remove $modInput 2>&1 | Out-String
    Write-Host $output
    
    if ($LASTEXITCODE -eq 0) {
        packwiz refresh | Out-Null
        & "$PSScriptRoot\Update-Changelog.ps1" -ModName $modName -Section "Removed"
        Write-Host "`nMod removed and changelog updated!" -ForegroundColor Green
    } else {
        Write-Host "Failed to remove mod" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to continue"
}

function Set-Version {
    Write-Host "`nSet New Version" -ForegroundColor Cyan
    
    $currentVersion = (Select-String -Path .\pack.toml -Pattern 'version\s*=\s*"([^"]+)"').Matches.Groups[1].Value
    Write-Host "Current version: $currentVersion" -ForegroundColor Yellow
    
    $newVersion = Read-Host "New version"
    if ([string]::IsNullOrWhiteSpace($newVersion)) {
        Write-Host "Version cannot be empty" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }
    
    # Update pack.toml
    (Get-Content "pack.toml" -Raw) -replace 'version = "[^"]+"', "version = `"$newVersion`"" | Out-File "pack.toml" -Encoding utf8 -NoNewline
    
    # Create new changelog section
    $date = Get-Date -Format "yyyy-MM-dd"
    $newSection = @"
## [$newVersion] - $date

### Added
``````
``````

### Removed
``````
``````

### Updated
``````
``````

---

"@
    
    if (Test-Path "CHANGELOG.md") {
        $existingContent = Get-Content "CHANGELOG.md" -Raw
        if ($existingContent -match '# Changelog\s*\n') {
            $newContent = $existingContent -replace '(# Changelog\s*\n)', "`$1`n$newSection"
            $newContent | Out-File "CHANGELOG.md" -Encoding utf8 -NoNewline
        }
    }
    
    Write-Host "`nVersion updated to $newVersion and changelog section created!" -ForegroundColor Green
    Read-Host "`nPress Enter to continue"
}

function Get-TomlValue {
    param(
        [string]$Content,
        [string]$Key
    )
    
    $escapedKey = [regex]::Escape($Key)
    if ($Content -match "(?m)^\s*$escapedKey\s*=\s*`"([^`"]*)`"") {
        return $matches[1]
    }
    
    return $null
}

function Set-TomlValue {
    param(
        [string]$Content,
        [string]$Key,
        [string]$Value
    )
    
    $escapedKey = [regex]::Escape($Key)
    $escapedValue = $Value.Replace('\', '\\').Replace('"', '\"')
    $pattern = "(?m)^(\s*$escapedKey\s*=\s*)`"[^`"]*`""
    
    return [regex]::Replace($Content, $pattern, {
        param($match)
        return "$($match.Groups[1].Value)`"$escapedValue`""
    })
}

function Get-PackGameVersions {
    $packContent = Get-Content "pack.toml" -Raw
    $versions = @()
    
    $minecraftVersion = Get-TomlValue -Content $packContent -Key "minecraft"
    if (-not [string]::IsNullOrWhiteSpace($minecraftVersion)) {
        $versions += $minecraftVersion
    }
    
    if ($packContent -match 'acceptable-game-versions\s*=\s*\[([^\]]+)\]') {
        $versions += [regex]::Matches($matches[1], '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
    }
    
    return @($versions | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
}

function Get-AllowedVersionTypes {
    param([string]$CurrentType)
    
    switch ($CurrentType) {
        "alpha" { return @("release", "alpha") }
        "beta" { return @("release", "beta") }
        default { return @("release") }
    }
}

function Test-ArrayOverlap {
    param(
        [object[]]$Left,
        [object[]]$Right
    )
    
    foreach ($item in $Left) {
        if ($Right -contains $item) {
            return $true
        }
    }
    
    return $false
}

function Get-ModrinthVersionFile {
    param([object]$Version)
    
    $primaryFile = $Version.files | Where-Object { $_.primary } | Select-Object -First 1
    if ($null -ne $primaryFile) {
        return $primaryFile
    }
    
    return $Version.files | Select-Object -First 1
}

function Update-ModrinthMetaFile {
    param([string]$Path)
    
    $content = Get-Content $Path -Raw
    if ($content -notmatch '(?m)^\s*\[update\.modrinth\]\s*$') {
        Write-Host "Skipping non-Modrinth entry: $Path" -ForegroundColor Yellow
        return $null
    }
    
    $modName = Get-TomlValue -Content $content -Key "name"
    $oldFile = Get-TomlValue -Content $content -Key "filename"
    $modId = Get-TomlValue -Content $content -Key "mod-id"
    $currentVersionId = Get-TomlValue -Content $content -Key "version"
    
    if ([string]::IsNullOrWhiteSpace($modId) -or [string]::IsNullOrWhiteSpace($currentVersionId)) {
        Write-Host "Skipping incomplete Modrinth metadata: $Path" -ForegroundColor Yellow
        return $null
    }
    
    try {
        $currentVersion = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version/$currentVersionId"
        $projectVersions = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$modId/version"
    } catch {
        Write-Host "Failed to fetch Modrinth versions for $Path`: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
    
    $allowedTypes = Get-AllowedVersionTypes -CurrentType $currentVersion.version_type
    $packGameVersions = Get-PackGameVersions
    $currentLoaders = @($currentVersion.loaders)
    
    $candidate = $projectVersions |
        Where-Object {
            ($allowedTypes -contains $_.version_type) -and
            (Test-ArrayOverlap -Left @($_.game_versions) -Right $packGameVersions) -and
            (Test-ArrayOverlap -Left @($_.loaders) -Right $currentLoaders) -and
            ($null -ne (Get-ModrinthVersionFile -Version $_))
        } |
        Sort-Object { [datetime]$_.date_published } -Descending |
        Select-Object -First 1
    
    if ($null -eq $candidate -or $candidate.id -eq $currentVersionId) {
        return $null
    }
    
    $newFileInfo = Get-ModrinthVersionFile -Version $candidate
    $newHash = $newFileInfo.hashes.sha512
    $hashFormat = "sha512"
    
    if ([string]::IsNullOrWhiteSpace($newHash)) {
        $newHash = $newFileInfo.hashes.sha1
        $hashFormat = "sha1"
    }
    
    if ([string]::IsNullOrWhiteSpace($newFileInfo.filename) -or [string]::IsNullOrWhiteSpace($newFileInfo.url) -or [string]::IsNullOrWhiteSpace($newHash)) {
        Write-Host "Skipping update with incomplete file data for $Path" -ForegroundColor Yellow
        return $null
    }
    
    $newContent = $content
    $newContent = Set-TomlValue -Content $newContent -Key "filename" -Value $newFileInfo.filename
    $newContent = Set-TomlValue -Content $newContent -Key "url" -Value $newFileInfo.url
    $newContent = Set-TomlValue -Content $newContent -Key "hash-format" -Value $hashFormat
    $newContent = Set-TomlValue -Content $newContent -Key "hash" -Value $newHash
    $newContent = Set-TomlValue -Content $newContent -Key "version" -Value $candidate.id
    $newContent | Out-File $Path -Encoding utf8 -NoNewline
    
    return [PSCustomObject]@{
        ModName = $modName
        OldFile = $oldFile
        NewFile = $newFileInfo.filename
        VersionType = $candidate.version_type
    }
}

function Update-All-Mods {
    Write-Host "`nUpdate All Mods" -ForegroundColor Cyan
    
    Write-Host "Updating mods..."
    $metaFiles = Get-ChildItem -Path mods,resourcepacks,shaderpacks,basicweapons_materialpacks -Filter *.pw.toml -Recurse
    $updatedCount = 0
    
    foreach ($metaFile in $metaFiles) {
        $update = Update-ModrinthMetaFile -Path $metaFile.FullName
        if ($null -ne $update) {
            $updatedCount++
            $changeText = "$($update.ModName): $($update.OldFile) -> $($update.NewFile)"
            Write-Host $changeText
            & "$PSScriptRoot\Update-Changelog.ps1" -ModName $changeText -Section "Updated"
        }
    }
    
    packwiz refresh
    Write-Host "`n$updatedCount mods updated and changelog updated!" -ForegroundColor Green
    Read-Host "`nPress Enter to continue"
}

function Prepare-Release {
    Write-Host "`nPrepare Release" -ForegroundColor Cyan
    
    $version = (Select-String -Path .\pack.toml -Pattern 'version\s*=\s*"([^"]+)"').Matches.Groups[1].Value
    Write-Host "Preparing release for version $version..." -ForegroundColor Yellow
    
    packwiz refresh
    
    # Clean up empty sections in CHANGELOG.md
    Write-Host "`nCleaning up changelog..."
    $changelogLines = Get-Content "CHANGELOG.md"
    $cleanedLines = @()
    $skipSection = $false
    $inCodeBlock = $false
    $sectionLines = @()
    
    for ($i = 0; $i -lt $changelogLines.Count; $i++) {
        $line = $changelogLines[$i]
        
        # Detect section headers
        if ($line -match '^### (Added|Removed|Updated)$') {
            $skipSection = $false
            $sectionLines = @($line)
            $inCodeBlock = $false
            continue
        }
        
        # Handle code blocks
        if ($line -eq '```') {
            if (-not $inCodeBlock) {
                $inCodeBlock = $true
                $sectionLines += $line
            } else {
                # Closing code block - check if empty
                $sectionLines += $line
                $codeContent = $sectionLines | Where-Object { $_ -ne '```' -and $_ -notmatch '^###' }
                
                if ($codeContent.Count -eq 0 -or ($codeContent -join '').Trim() -eq '') {
                    # Empty section, skip it
                    $skipSection = $true
                } else {
                    # Has content, keep it
                    $cleanedLines += $sectionLines
                }
                
                $sectionLines = @()
                $inCodeBlock = $false
            }
            continue
        }
        
        # Accumulate section lines
        if ($sectionLines.Count -gt 0) {
            $sectionLines += $line
        } else {
            $cleanedLines += $line
        }
    }
    
    $cleanedLines | Out-File "CHANGELOG.md" -Encoding utf8
    
    $NAME = (Select-String -Path .\pack.toml -Pattern 'name\s*=\s*"([^"]+)"').Matches.Groups[1].Value -replace ' ', '-'
    $MC_VERSION = (Select-String -Path .\pack.toml -Pattern 'minecraft\s*=\s*"([^"]+)"').Matches.Groups[1].Value
    $OUTPUT_FILE = "${NAME}_${version}+${MC_VERSION}.mrpack"
    
    New-Item -ItemType Directory -Path "releases" -Force | Out-Null
    packwiz mr export -o "releases/$OUTPUT_FILE"
    
    if (Test-Path "releases/$OUTPUT_FILE") {
        $size = [math]::Round((Get-Item "releases/$OUTPUT_FILE").Length/1KB, 2)
        Write-Host "`nBuild complete: $OUTPUT_FILE ($size KB)" -ForegroundColor Green
        Write-Host "`nNext steps:" -ForegroundColor Cyan
        Write-Host "  1. Review CHANGELOG.md"
        Write-Host "  2. git add ."
        Write-Host "  3. git commit -m 'Release v$version'"
        Write-Host "  4. git push"
        Write-Host "  5. Run GitHub Actions workflow"
    } else {
        Write-Host "`nBuild failed" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to continue"
}

# Main loop
while ($true) {
    Show-Menu
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        "1" { Set-Version }
        "2" { Add-Mod }
        "3" { Remove-Mod }
        "4" { Update-All-Mods }
        "5" { Prepare-Release }
        "6" { 
            Write-Host "`nExiting..." -ForegroundColor Green
            exit 
        }
        default { 
            Write-Host "`nInvalid choice" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
