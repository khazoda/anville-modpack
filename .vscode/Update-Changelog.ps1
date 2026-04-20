param(
    [Parameter(Mandatory=$true)]
    [string]$ModName,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("Added", "Removed", "Updated")]
    [string]$Section
)

if (-not (Test-Path "CHANGELOG.md")) {
    Write-Host "Error: CHANGELOG.md not found" -ForegroundColor Red
    exit 1
}

$lines = Get-Content "CHANGELOG.md"
$updated = $false
$newLines = @()
$inTargetSection = $false
$inCodeBlock = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $newLines += $line
    
    # Detect if we're in the target section
    if ($line -match "^### $Section$") {
        $inTargetSection = $true
        continue
    }
    
    # If in target section and we hit the code block opener
    if ($inTargetSection -and $line -eq '```') {
        if (-not $inCodeBlock) {
            $inCodeBlock = $true
        } else {
            # Closing backticks - add mod before this line if not already added
            if (-not $updated) {
                $modLine = "- $ModName"
                # Remove the closing backticks we just added
                $newLines = $newLines[0..($newLines.Count - 2)]
                # Add the mod line
                $newLines += $modLine
                # Add closing backticks back
                $newLines += '```'
                $updated = $true
                Write-Host "Added '$ModName' to $Section section" -ForegroundColor Green
            }
            $inTargetSection = $false
            $inCodeBlock = $false
        }
    }
}

if ($updated) {
    $newLines | Out-File "CHANGELOG.md" -Encoding utf8
}
