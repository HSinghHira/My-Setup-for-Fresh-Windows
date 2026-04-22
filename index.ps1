# ============================================================
# Windows Setup Script
# ============================================================

# ========================
# Admin Check
# ========================
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ This script must be run as Administrator. Right-click and select 'Run as Administrator'." -ForegroundColor Red
    exit 1
}

# ========================
# Result Tracking
# ========================
$results = @()

# Known winget exit codes that mean "already installed / nothing to do"
$WINGET_NO_UPGRADE      = -1978335189  # No available upgrade found
$WINGET_ALREADY_PRESENT = -1978335150  # Package already installed
$WINGET_NOT_FOUND       = -1978335212  # No package found matching input criteria

function Install-WingetApp {
    param(
        [string]$Id,
        [string]$Label,
        [string]$Version = "",
        [string]$Source = "winget"
    )

    $timestamp = Get-Date -Format "HH:mm:ss"

    # Use -SimpleMatch so special characters like ++ are treated literally, not as regex
    $checkArgs = @("list", "--id", $Id, "--source", $Source, "--accept-source-agreements")
    $installed = winget @checkArgs 2>&1 | Select-String -SimpleMatch $Id
    if ($installed) {
        Write-Host "[$timestamp] ⏭  Skipping $Label (already installed)" -ForegroundColor Yellow
        $script:results += [PSCustomObject]@{ App = $Label; Status = "Skipped" }
        return
    }

    Write-Host "[$timestamp] 📦 Installing $Label..." -ForegroundColor Cyan

    $installArgs = @("install", "--exact", "--id", $Id, "--source", $Source, "--silent", "--accept-package-agreements", "--accept-source-agreements")
    if ($Version -ne "") { $installArgs += @("--version", $Version) }

    winget @installArgs
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "[$timestamp] ✅ $Label installed successfully." -ForegroundColor Green
        $script:results += [PSCustomObject]@{ App = $Label; Status = "Installed" }
    } elseif ($exitCode -eq $WINGET_NO_UPGRADE -or $exitCode -eq $WINGET_ALREADY_PRESENT) {
        # winget found it installed but with no upgrade available — not a real failure
        Write-Host "[$timestamp] ⏭  $Label is already up to date." -ForegroundColor Yellow
        $script:results += [PSCustomObject]@{ App = $Label; Status = "Skipped" }
    } elseif ($exitCode -eq $WINGET_NOT_FOUND) {
        # Package not found in the specified source — warn but don't hard-fail
        Write-Host "[$timestamp] ⚠️  $Label not found in source '$Source' — skipping." -ForegroundColor Yellow
        $script:results += [PSCustomObject]@{ App = $Label; Status = "Not Found" }
    } else {
        Write-Host "[$timestamp] ❌ $Label failed (exit code $exitCode)." -ForegroundColor Red
        $script:results += [PSCustomObject]@{ App = $Label; Status = "Failed" }
    }
}

# ========================
# Winget Self-Update
# ========================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Updating winget & sources" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
winget upgrade --id Microsoft.AppInstaller --silent --accept-package-agreements --accept-source-agreements
winget source update

# ========================
# Core Apps
# ========================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Core Apps" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Install-WingetApp -Id "7zip.7zip"                          -Label "7-Zip"
Install-WingetApp -Id "Daum.PotPlayer"                     -Label "PotPlayer"
Install-WingetApp -Id "ShareX.ShareX"                      -Label "ShareX"
Install-WingetApp -Id "Gyan.FFmpeg"                        -Label "FFmpeg"

# ========================
# System Utilities
# ========================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  System Utilities" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Install-WingetApp -Id "xanderfrangos.twinkletray"          -Label "TwinkleTray"
Install-WingetApp -Id "File-New-Project.EarTrumpet"        -Label "EarTrumpet"
Install-WingetApp -Id "CrystalRich.LockHunter"             -Label "LockHunter"
Install-WingetApp -Id "Klocman.BulkCrapUninstaller"        -Label "Bulk Crap Uninstaller"

# ========================
# Productivity
# ========================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Productivity" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Install-WingetApp -Id "PDFgear.PDFgear"                    -Label "PDFgear"
Install-WingetApp -Id "JavadMotallebi.NeatDownloadManager" -Label "Neat Download Manager"
Install-WingetApp -Id "flux.flux"                          -Label "f.lux"
Install-WingetApp -Id "riyasy.FlyPhotos"                   -Label "FlyPhotos"
Install-WingetApp -Id "UnifiedIntents.UnifiedRemote"       -Label "Unified Remote"
Install-WingetApp -Id "Ditto.Ditto"                        -Label "Ditto"

# ========================
# Dev Setup
# ========================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Dev Setup" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Install-WingetApp -Id "Git.Git"                            -Label "Git"
Install-WingetApp -Id "Oven-sh.Bun"                        -Label "Bun"
Install-WingetApp -Id "Volta.Volta"                        -Label "Volta"
Install-WingetApp -Id "Notepad++.Notepad++"                -Label "Notepad++"
Install-WingetApp -Id "Google.Antigravity"                 -Label "Google Antigravity"
Install-WingetApp -Id "Microsoft.VisualStudioCode"         -Label "VS Code"

# Install Node via Volta
$env:PATH += ";$env:LOCALAPPDATA\Volta\bin"
$timestamp = Get-Date -Format "HH:mm:ss"
if (Get-Command volta -ErrorAction SilentlyContinue) {
    Write-Host "[$timestamp] 📦 Installing Node via Volta..." -ForegroundColor Cyan
    volta install node
    Write-Host "[$timestamp] ✅ Node installed via Volta." -ForegroundColor Green
    $script:results += [PSCustomObject]@{ App = "Node.js (via Volta)"; Status = "Installed" }
} else {
    Write-Host "[$timestamp] ❌ Volta not found — skipping Node install." -ForegroundColor Red
    $script:results += [PSCustomObject]@{ App = "Node.js (via Volta)"; Status = "Failed" }
}

# ========================
# Microsoft Store Apps
# ========================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Microsoft Store Apps" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Install-WingetApp -Id "9PKTQ5699M62"                       -Label "iCloud"             -Source "msstore"
Install-WingetApp -Id "9P64KGF20H0T"                       -Label "iTunes"             -Source "msstore"
Install-WingetApp -Id "9N7JSXC1SJK6"                       -Label "Ollama"             -Source "msstore"

# ========================
# Package Upgrades (with prompt)
# ========================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Package Upgrades" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

Write-Host "Checking for available upgrades..." -ForegroundColor Cyan
winget upgrade

Write-Host ""
$upgradeChoice = Read-Host "Would you like to upgrade all packages now? (y/n)"
if ($upgradeChoice -match "^[Yy]") {
    Write-Host "Upgrading all packages..." -ForegroundColor Cyan
    winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
    Write-Host "✅ All packages upgraded." -ForegroundColor Green
} else {
    Write-Host "⏭  Skipping upgrades." -ForegroundColor Yellow
}

# ========================
# AI / Ollama Model
# ========================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Ollama — llama3.1:8b model" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

# Refresh PATH so freshly installed Ollama is visible
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH", "User")

$ollamaExe = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
$ollamaCmd = if (Get-Command ollama -ErrorAction SilentlyContinue) { "ollama" }
             elseif (Test-Path $ollamaExe) { $ollamaExe }
             else { $null }

if ($ollamaCmd) {
    # Start Ollama server in the background if not already running
    $ollamaRunning = Get-Process -Name "ollama" -ErrorAction SilentlyContinue
    if (-not $ollamaRunning) {
        Write-Host "🚀 Starting Ollama server..." -ForegroundColor Cyan
        Start-Process -FilePath $ollamaCmd -ArgumentList "serve" -WindowStyle Hidden
        Start-Sleep -Seconds 3
    }

    # Check if model is already pulled
    $pulledModels = & $ollamaCmd list 2>&1
    if ($pulledModels -match "llama3\.1:8b") {
        Write-Host "⏭  llama3.1:8b already downloaded — skipping pull." -ForegroundColor Yellow
        $script:results += [PSCustomObject]@{ App = "llama3.1:8b model"; Status = "Skipped" }
    } else {
        Write-Host "⬇  Pulling llama3.1:8b (~4.7 GB — this will take a while)..." -ForegroundColor Cyan
        & $ollamaCmd pull llama3.1:8b
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ llama3.1:8b downloaded successfully." -ForegroundColor Green
            $script:results += [PSCustomObject]@{ App = "llama3.1:8b model"; Status = "Installed" }
        } else {
            Write-Host "❌ llama3.1:8b pull failed." -ForegroundColor Red
            $script:results += [PSCustomObject]@{ App = "llama3.1:8b model"; Status = "Failed" }
        }
    }
} else {
    Write-Host "⚠️  Ollama not found. Open a new terminal after setup and run:" -ForegroundColor Yellow
    Write-Host "    ollama pull llama3.1:8b" -ForegroundColor White
    $script:results += [PSCustomObject]@{ App = "llama3.1:8b model"; Status = "Failed" }
}

# ========================
# Summary
# ========================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Setup Summary" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

$installed = $results | Where-Object { $_.Status -eq "Installed" }
$skipped   = $results | Where-Object { $_.Status -eq "Skipped" }
$notFound  = $results | Where-Object { $_.Status -eq "Not Found" }
$failed    = $results | Where-Object { $_.Status -eq "Failed" }

Write-Host "✅ Installed  ($($installed.Count)):" -ForegroundColor Green
$installed | ForEach-Object { Write-Host "   - $($_.App)" -ForegroundColor Green }

Write-Host "⏭  Skipped   ($($skipped.Count)):" -ForegroundColor Yellow
$skipped | ForEach-Object { Write-Host "   - $($_.App)" -ForegroundColor Yellow }

if ($notFound.Count -gt 0) {
    Write-Host "🔍 Not Found ($($notFound.Count)):" -ForegroundColor DarkYellow
    $notFound | ForEach-Object { Write-Host "   - $($_.App)" -ForegroundColor DarkYellow }
}

if ($failed.Count -gt 0) {
    Write-Host "❌ Failed    ($($failed.Count)):" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "   - $($_.App)" -ForegroundColor Red }
} else {
    Write-Host "❌ Failed    (0)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "✅ Setup Complete!" -ForegroundColor Green