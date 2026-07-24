<#
tools/build-release.ps1

Builds a verified bundle.zip for an OTA release of Les Grandes Sauces (Android/Capacitor).

Root cause this guards against (v1.4.1 incident): a bundle.zip was created from a
hand-picked partial set of changed files (css/app.js/data.js only), missing lang
files -> broken app -> CapacitorUpdater auto-rollback after failed notifyAppReady().

This script never lets you choose files by hand: it always zips the ENTIRE contents
of the given www/ folder, then re-opens the resulting zip and verifies every single
file that exists on disk is present inside it (by relative path, not just by count).
If anything is missing, the zip is deleted and the script exits with an error --
no partial bundle.zip is ever left behind.

USAGE (from PowerShell, in the Capacitor project):
  .\tools\build-release.ps1
  .\tools\build-release.ps1 -WwwPath "C:\path\to\Android\sauce-android\www" -OutputZip ".\bundle.zip"

If -WwwPath is omitted, it defaults to "..\Android\sauce-android\www" relative to
this script's location -- adjust $DefaultWwwPath below once to match your machine,
then you can just run the script with no arguments every time.
#>

param(
    [string]$WwwPath = "",
    [string]$OutputZip = ""
)

$ErrorActionPreference = "Stop"

# ---- Configure your local paths once here ----
$DefaultWwwPath = Join-Path $PSScriptRoot "..\..\Android\sauce-android\www"
$DefaultOutputZip = Join-Path (Get-Location) "bundle.zip"
# ------------------------------------------------

if ([string]::IsNullOrWhiteSpace($WwwPath)) { $WwwPath = $DefaultWwwPath }
if ([string]::IsNullOrWhiteSpace($OutputZip)) { $OutputZip = $DefaultOutputZip }

$WwwPath = (Resolve-Path $WwwPath -ErrorAction Stop).Path

Write-Host "www folder:  $WwwPath"
Write-Host "output zip:  $OutputZip"
Write-Host ""

if (-not (Test-Path $WwwPath -PathType Container)) {
    Write-Error "www folder not found: $WwwPath"
    exit 1
}

# ---- Step 1: enumerate every real file in www/ (the ground truth) ----
$sourceFiles = Get-ChildItem -Path $WwwPath -Recurse -File |
    ForEach-Object { $_.FullName.Substring($WwwPath.Length + 1).Replace('\', '/') } |
    Sort-Object

if ($sourceFiles.Count -eq 0) {
    Write-Error "www folder is empty -- refusing to build an empty bundle.zip"
    exit 1
}

Write-Host "Found $($sourceFiles.Count) files in www/."

# ---- Step 2: build the zip from the FULL folder contents (never hand-picked) ----
if (Test-Path $OutputZip) { Remove-Item $OutputZip -Force }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $WwwPath, $OutputZip,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $false  # false = do NOT include the www folder itself, only its contents
) 

Write-Host "Created $OutputZip"

# ---- Step 3: re-open the zip and verify EVERY source file is present ----
$zip = [System.IO.Compression.ZipFile]::OpenRead($OutputZip)
try {
    $zipEntries = $zip.Entries | ForEach-Object { $_.FullName.Replace('\', '/') } | Sort-Object
} finally {
    $zip.Dispose()
}

$missing = Compare-Object -ReferenceObject $sourceFiles -DifferenceObject $zipEntries -PassThru |
    Where-Object { $_ -in $sourceFiles }

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "BUNDLE INCOMPLETE -- these files exist in www/ but are missing from the zip:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Remove-Item $OutputZip -Force
    Write-Error "Deleted incomplete $OutputZip. No partial bundle was left on disk."
    exit 1
}

if ($zipEntries.Count -ne $sourceFiles.Count) {
    Write-Host ""
    Write-Host "WARNING: zip has $($zipEntries.Count) entries but www/ has $($sourceFiles.Count) files (extra entries in zip, not missing ones)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "OK -- all $($sourceFiles.Count) files from www/ are present in $OutputZip." -ForegroundColor Green
Write-Host "Zip size: $([math]::Round((Get-Item $OutputZip).Length / 1MB, 2)) MB"
Write-Host ""
Write-Host "Next: create a GitHub Release (tag vX.Y.Z, NOT marked Pre-release, marked Latest)"
Write-Host "on github.com/Apefty/LesGrandeSauces and attach this bundle.zip."
