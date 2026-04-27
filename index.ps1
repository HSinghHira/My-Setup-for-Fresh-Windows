#Requires -Version 5.1
# Windows 11 Setup Script — Master Edition
# Author: Harman Singh Hira
# https://me.hsinghhira.me

[CmdletBinding()]
param(
    [switch]$SkipRuntimes,
    [switch]$SkipCoreApps,
    [switch]$SkipSystemUtils,
    [switch]$SkipProductivity,
    [switch]$SkipDevSetup,
    [switch]$SkipStoreApps,
    [switch]$SkipExtensions,
    [switch]$SkipDebloat,
    [switch]$SkipEUPrivacy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ─────────────────────────────────────────────────────────────────────────────
#  Transcript / Log File
# ─────────────────────────────────────────────────────────────────────────────

$startTime  = Get-Date
$logRoot    = if ($PSScriptRoot) { $PSScriptRoot } else { $env:TEMP }
$logFile    = Join-Path $logRoot ("setup-log-" + $startTime.ToString('yyyy-MM-dd_HH-mm') + ".txt")
Start-Transcript -Path $logFile -Append | Out-Null

# ─────────────────────────────────────────────────────────────────────────────
#  Section 1 — Admin Check
# ─────────────────────────────────────────────────────────────────────────────

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "❌ This script must be run as Administrator." -ForegroundColor Red
    Write-Host "   Right-click PowerShell and choose 'Run as administrator'." -ForegroundColor Yellow
    Write-Host ""
    try { Stop-Transcript | Out-Null } catch {}
    exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
#  Section 2 — Result Tracking
# ─────────────────────────────────────────────────────────────────────────────

$script:results = @()

function Add-Result {
    param([string]$App, [string]$Status)
    $script:results += [PSCustomObject]@{ App = $App; Status = $Status }
}

# ─────────────────────────────────────────────────────────────────────────────
#  Banner
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         Windows 11 Setup Script — Master Edition             ║" -ForegroundColor Cyan
Write-Host "║                  by Harman Singh Hira                        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
#  Section 3 — Helper Functions
# ─────────────────────────────────────────────────────────────────────────────

function Get-Timestamp { return (Get-Date -Format 'HH:mm:ss') }

function Get-ArchTag {
    return $env:PROCESSOR_ARCHITECTURE.Replace('AMD', 'X').Replace('IA', 'X')
}

function Resolve-UniqueFilePath {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $Path }
    $item = Get-Item $Path
    $i = 1
    do {
        $newPath = Join-Path $item.DirectoryName ("$($item.BaseName)($i)$($item.Extension)")
        $i++
    } while (Test-Path $newPath)
    return $newPath
}

# ── Install-WingetApp ─────────────────────────────────────────────────────────

function Install-WingetApp {
    param(
        [string]$Id,
        [string]$Label,
        [string]$Version  = '',
        [string]$Source   = 'winget'
    )

    $ts = Get-Timestamp
    Write-Host "[$ts] 📦 $Label …" -ForegroundColor DarkCyan

    # Check if already installed
    $listOutput = winget list --id $Id --exact --accept-source-agreements 2>&1
    if ($LASTEXITCODE -eq 0 -and ($listOutput | Select-String -Pattern ([regex]::Escape($Id)))) {
        Write-Host "[$ts]    ⏭  Already installed — skipping." -ForegroundColor DarkGray
        Add-Result -App $Label -Status 'Skipped'
        return
    }

    $args = @('install', '--id', $Id, '--exact', '--silent',
              '--accept-package-agreements', '--accept-source-agreements',
              '--source', $Source)
    if ($Version) { $args += @('--version', $Version) }

    $attempt = 0
    $installed = $false

    while ($attempt -lt 2 -and -not $installed) {
        $attempt++
        winget @args 2>&1 | Out-Null
        $ec = $LASTEXITCODE

        switch ($ec) {
            0                  { $installed = $true }
            -1978335189        { Write-Host "[$( Get-Timestamp )]    ⏭  No upgrade available." -ForegroundColor DarkGray; Add-Result -App $Label -Status 'Skipped'; return }
            -1978335150        { Write-Host "[$( Get-Timestamp )]    ⏭  Already installed."    -ForegroundColor DarkGray; Add-Result -App $Label -Status 'Skipped'; return }
            -1978335212        { Write-Host "[$( Get-Timestamp )]    🔍 Not found in source."  -ForegroundColor Yellow;   Add-Result -App $Label -Status 'Not Found'; return }
            default {
                if ($attempt -lt 2) {
                    Write-Host "[$( Get-Timestamp )]    ⚠️  Attempt $attempt failed (exit $ec). Retrying in 5s …" -ForegroundColor Yellow
                    Start-Sleep -Seconds 5
                }
            }
        }
    }

    if ($installed) {
        Write-Host "[$( Get-Timestamp )]    ✅ Installed." -ForegroundColor Green
        Add-Result -App $Label -Status 'Installed'
    } else {
        Write-Host "[$( Get-Timestamp )]    ❌ Failed after 2 attempts." -ForegroundColor Red
        Add-Result -App $Label -Status 'Failed'
    }
}

# ── Install-AppxFromStore ─────────────────────────────────────────────────────

function Install-AppxFromStore {
    param(
        [string]$ProductId,
        [string]$Label
    )

    $ts       = Get-Timestamp
    $storeUrl = "https://apps.microsoft.com/detail/$ProductId"
    Write-Host "[$ts] 📦 $Label (Store fallback) …" -ForegroundColor DarkCyan

    # Primary source — tplant REST API
    $success = $false
    try {
        $apiUrl  = "https://msft-store.tplant.com.au/api/Packages?id=$storeUrl&environment=Production&inputform=url"
        $packages = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop

        if ($packages -and @($packages).Count -gt 0) {
            $arch    = Get-ArchTag
            $package = $packages | Where-Object { $_.packagefilename -like '*x64*' } | Select-Object -First 1
            if (-not $package) { $package = $packages | Where-Object { $_.packagefilename -like "*$arch*" } | Select-Object -First 1 }
            if (-not $package) { $package = $packages | Select-Object -First 1 }

            $downloadUrl = $package.packagedownloadurl
            $fileName    = $package.packagefilename
            $outPath     = Resolve-UniqueFilePath (Join-Path $env:TEMP $fileName)

            Write-Host "[$( Get-Timestamp )]    ⬇  tplant → $fileName" -ForegroundColor DarkCyan
            Invoke-WebRequest -Uri $downloadUrl -OutFile $outPath -UseBasicParsing -ErrorAction Stop
            Add-AppxPackage -Path $outPath -ErrorAction Stop
            Remove-Item $outPath -Force -ErrorAction SilentlyContinue

            Write-Host "[$( Get-Timestamp )]    ✅ Installed." -ForegroundColor Green
            Add-Result -App $Label -Status 'Installed'
            $success = $true
        }
    } catch {
        Write-Host "[$( Get-Timestamp )]    ⚠️  tplant failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    if ($success) { return }

    # Fallback source — AdGuard HTML scrape
    try {
        Write-Host "[$( Get-Timestamp )]    🔄 Falling back to AdGuard …" -ForegroundColor Yellow
        $body     = "type=url&url=$storeUrl&ring=Retail"
        $response = Invoke-WebRequest -UseBasicParsing -Method POST `
                        -Uri 'https://store.rg-adguard.net/api/GetFiles' `
                        -Body $body -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop

        $arch      = Get-ArchTag
        $links     = $response.Links |
                     Where-Object { $_ -like '*.appx*' -or $_ -like '*.appxbundle*' -or
                                    $_ -like '*.msix*' -or $_ -like '*.msixbundle*' } |
                     Where-Object { $_ -like '*_neutral_*' -or $_ -like "*_${arch}_*" } |
                     Select-String -Pattern '(?<=a href=").+(?=" r)'

        $urls = $links | ForEach-Object { $_.Matches.Value }

        if (-not $urls -or @($urls).Count -eq 0) { throw "No packages found." }

        foreach ($url in $urls) {
            $req      = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
            $fileName = ($req.Headers['Content-Disposition'] | Select-String -Pattern '(?<=filename=).+').Matches.Value
            if (-not $fileName) { $fileName = Split-Path $url -Leaf }
            $outPath  = Resolve-UniqueFilePath (Join-Path $env:TEMP $fileName)

            Write-Host "[$( Get-Timestamp )]    ⬇  AdGuard → $fileName" -ForegroundColor DarkCyan
            [System.IO.File]::WriteAllBytes($outPath, $req.Content)
            Add-AppxPackage -Path $outPath -ErrorAction Stop
            Remove-Item $outPath -Force -ErrorAction SilentlyContinue

            Write-Host "[$( Get-Timestamp )]    ✅ Installed." -ForegroundColor Green
            Add-Result -App $Label -Status 'Installed'
            $success = $true
        }
    } catch {
        Write-Host "[$( Get-Timestamp )]    ❌ AdGuard also failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    if (-not $success) {
        Add-Result -App $Label -Status 'Failed'
    }
}

# ── Install-VSExtensions ──────────────────────────────────────────────────────

function Install-VSExtensions {
    param(
        [string[]]$EnabledExtensions,
        [string[]]$DisabledExtensions   = @(),
        [string[]]$VSCodeOnlyExtensions = @()
    )

    $ides = @(
        @{ Name = 'VS Code';     Cli = 'code';       IsAntigravity = $false },
        @{ Name = 'Antigravity'; Cli = 'antigravity'; IsAntigravity = $true  }
    )

    foreach ($ide in $ides) {
        $cli          = $ide.Cli
        $isAntigravity = $ide.IsAntigravity

        if (-not (Get-Command $cli -ErrorAction SilentlyContinue)) {
            Write-Host "[$( Get-Timestamp )]    ⚠️  $($ide.Name) CLI ('$cli') not found in PATH — skipping." -ForegroundColor Yellow
            continue
        }

        Write-Host ""
        Write-Host "[$( Get-Timestamp )] 🧩 Installing extensions into $($ide.Name) …" -ForegroundColor Cyan

        $installed = & $cli --list-extensions 2>&1

        foreach ($ext in $EnabledExtensions) {
            $ts = Get-Timestamp

            # Skip VS Code-only extensions silently in Antigravity
            if ($isAntigravity -and ($VSCodeOnlyExtensions -contains $ext)) { continue }

            if ($installed -contains $ext) {
                Write-Host "[$ts]    ⏭  $ext already installed in $($ide.Name)." -ForegroundColor DarkGray
                Add-Result -App "$($ide.Name): $ext" -Status 'Skipped'
            } else {
                & $cli --install-extension $ext --force 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[$ts]    ✅ $ext" -ForegroundColor Green
                    Add-Result -App "$($ide.Name): $ext" -Status 'Installed'
                } else {
                    Write-Host "[$ts]    ❌ $ext failed." -ForegroundColor Red
                    Add-Result -App "$($ide.Name): $ext" -Status 'Failed'
                }
            }
        }

        foreach ($ext in $DisabledExtensions) {
            & $cli --disable-extension $ext 2>&1 | Out-Null
        }
    }
}

# ── Set-RegistryValue ─────────────────────────────────────────────────────────

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = 'DWORD'
    )
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        Write-Host "[$( Get-Timestamp )]    ✅ $Name = $Value  ($Path)" -ForegroundColor DarkGreen
    } catch {
        Write-Host "[$( Get-Timestamp )]    ⚠️  Could not set $Name : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ── Remove-AppxIfPresent ──────────────────────────────────────────────────────

function Remove-AppxIfPresent {
    param(
        [string]$PackageName,
        [string]$Label
    )
    $ts = Get-Timestamp
    try {
        $pkg = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
        if ($pkg) {
            $pkg | Remove-AppxPackage -ErrorAction Stop
            Write-Host "[$ts]    ✅ Removed $Label" -ForegroundColor Green
        }
        $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $PackageName }
        if ($prov) {
            $prov | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
        }
        if ($pkg -or $prov) {
            Add-Result -App $Label -Status 'Installed'   # repurposed as "Removed" for bloat
        } else {
            Write-Host "[$ts]    ⏭  $Label not found — skipping." -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "[$ts]    ❌ Failed to remove $Label : $($_.Exception.Message)" -ForegroundColor Red
        Add-Result -App $Label -Status 'Failed'
    }
}

# ─────────────────────────────────────────────────────────────────────────────
#  Section 4 — Winget Self-Update
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Updating winget …" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "[$( Get-Timestamp )] ❌ winget not found. Please install App Installer from the Microsoft Store and re-run." -ForegroundColor Red
    try { Stop-Transcript | Out-Null } catch {}
    exit 1
}

winget upgrade --id Microsoft.AppInstaller --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
winget source update 2>&1 | Out-Null
Write-Host "[$( Get-Timestamp )] ✅ winget updated." -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
#  Section 5 — Runtimes & Redistributables
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Runtimes & Redistributables" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

if ($SkipRuntimes) {
    Write-Host "[$( Get-Timestamp )] ⏭  Skipping runtimes (flag set)." -ForegroundColor DarkGray
} else {
    Install-WingetApp -Id 'Microsoft.VCRedist.2015+.x64'     -Label 'VC++ Redistributable 2015+ (x64)'
    Install-WingetApp -Id 'Microsoft.DotNet.DesktopRuntime.5' -Label '.NET Desktop Runtime 5'
    Install-WingetApp -Id 'Microsoft.DotNet.DesktopRuntime.6' -Label '.NET Desktop Runtime 6'
    Install-WingetApp -Id 'Microsoft.DotNet.DesktopRuntime.8' -Label '.NET Desktop Runtime 8'
    Install-WingetApp -Id 'Microsoft.DotNet.DesktopRuntime.10' -Label '.NET Desktop Runtime 10'
}

# ─────────────────────────────────────────────────────────────────────────────
#  Section 6 — Core Apps
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Core Apps" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

if ($SkipCoreApps) {
    Write-Host "[$( Get-Timestamp )] ⏭  Skipping core apps (flag set)." -ForegroundColor DarkGray
} else {
    Install-WingetApp -Id '7zip.7zip'           -Label '7-Zip'
    Install-WingetApp -Id 'Daum.PotPlayer'      -Label 'PotPlayer'
    Install-WingetApp -Id 'ShareX.ShareX'       -Label 'ShareX'
    Install-WingetApp -Id 'Gyan.FFmpeg'         -Label 'FFmpeg'
}

# ─────────────────────────────────────────────────────────────────────────────
#  Section 7 — System Utilities
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  System Utilities" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

if ($SkipSystemUtils) {
    Write-Host "[$( Get-Timestamp )] ⏭  Skipping system utilities (flag set)." -ForegroundColor DarkGray
} else {
    Install-WingetApp -Id 'xanderfrangos.twinkletray'       -Label 'TwinkleTray'
    Install-WingetApp -Id 'File-New-Project.EarTrumpet'     -Label 'EarTrumpet'
    Install-WingetApp -Id 'CrystalRich.LockHunter'          -Label 'LockHunter'
    Install-WingetApp -Id 'Klocman.BulkCrapUninstaller'     -Label 'Bulk Crap Uninstaller'
    Install-WingetApp -Id '9P7KNL5RWT25'                    -Label 'Sysinternals Suite'  -Source 'msstore'
}

# ─────────────────────────────────────────────────────────────────────────────
#  Section 8 — Productivity Apps
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Productivity Apps" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

if ($SkipProductivity) {
    Write-Host "[$( Get-Timestamp )] ⏭  Skipping productivity apps (flag set)." -ForegroundColor DarkGray
} else {
    Install-WingetApp -Id 'PDFgear.PDFgear'                 -Label 'PDFgear'
    Install-WingetApp -Id 'JavadMotallebi.NeatDownloadManager' -Label 'Neat Download Manager'
    Install-WingetApp -Id 'flux.flux'                       -Label 'f.lux'
    Install-AppxFromStore -ProductId '9NV4BS3L1H4S'          -Label 'FlyPhotos'
    Install-WingetApp -Id 'UnifiedIntents.UnifiedRemote'     -Label 'Unified Remote'
    Install-WingetApp -Id 'Ditto.Ditto'                     -Label 'Ditto'
    Install-WingetApp -Id 'Microsoft.Office'                -Label 'Microsoft 365'
}

# ─────────────────────────────────────────────────────────────────────────────
#  Section 9 — Dev Setup
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Dev Setup" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

if ($SkipDevSetup) {
    Write-Host "[$( Get-Timestamp )] ⏭  Skipping dev setup (flag set)." -ForegroundColor DarkGray
} else {
    Install-WingetApp -Id 'Git.Git'                         -Label 'Git'
    Install-WingetApp -Id 'GitHub.cli'                      -Label 'GitHub CLI'
    Install-WingetApp -Id 'Oven-sh.Bun'                     -Label 'Bun'
    Install-WingetApp -Id 'Volta.Volta'                     -Label 'Volta'
    Install-WingetApp -Id 'Notepad++.Notepad++'             -Label 'Notepad++'
    Install-WingetApp -Id 'Google.Antigravity'              -Label 'Google Antigravity'
    Install-WingetApp -Id 'Microsoft.VisualStudioCode'      -Label 'VS Code'
    Install-WingetApp -Id 'Microsoft.WindowsTerminal'       -Label 'Windows Terminal'
    Install-WingetApp -Id 'Microsoft.PowerShell'            -Label 'PowerShell 7'
    Install-WingetApp -Id 'Python.Python.3.11'              -Label 'Python 3.11'
    Install-WingetApp -Id 'JanDeDobbeleer.OhMyPosh'        -Label 'Oh My Posh'

    # Refresh PATH so Volta is available
    $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('PATH', 'User')

    # Node via Volta
    if (Get-Command volta -ErrorAction SilentlyContinue) {
        Write-Host "[$( Get-Timestamp )] 📦 Installing Node via Volta …" -ForegroundColor DarkCyan
        volta install node 2>&1 | Out-Null
        Write-Host "[$( Get-Timestamp )]    ✅ Node installed via Volta." -ForegroundColor Green
        Add-Result -App 'Node (via Volta)' -Status 'Installed'
    } else {
        Write-Host "[$( Get-Timestamp )]    ⚠️  Volta not in PATH — skipping Node install." -ForegroundColor Yellow
    }

    # Oh My Posh profile config
    $ompLine = 'oh-my-posh init pwsh | Invoke-Expression'
    if ($PROFILE -and (Test-Path $PROFILE)) {
        $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
        if (-not ($profileContent -like "*oh-my-posh*")) {
            Add-Content -Path $PROFILE -Value "`n$ompLine"
            Write-Host "[$( Get-Timestamp )]    ✅ Oh My Posh added to PowerShell profile." -ForegroundColor Green
        } else {
            Write-Host "[$( Get-Timestamp )]    ⏭  Oh My Posh already in profile." -ForegroundColor DarkGray
        }
    } else {
        New-Item -Path $PROFILE -ItemType File -Force | Out-Null
        Add-Content -Path $PROFILE -Value $ompLine
        Write-Host "[$( Get-Timestamp )]    ✅ Oh My Posh profile created." -ForegroundColor Green
    }
}

# ─────────────────────────────────────────────────────────────────────────────
#  Section 10 — Microsoft Store Apps
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Microsoft Store Apps" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

if ($SkipStoreApps) {
    Write-Host "[$( Get-Timestamp )] ⏭  Skipping Store apps (flag set)." -ForegroundColor DarkGray
} else {
    Install-WingetApp -Id '9PKTQ5699M62'   -Label 'iCloud'  -Source 'msstore'
    Install-WingetApp -Id '9n7jsxc1sjk6'   -Label 'Blip'    -Source 'msstore'

    # Edison Mail — unlisted, use dual-source fallback
    Install-AppxFromStore -ProductId '9p64kgf20h0t' -Label 'Edison Mail'
}

# ─────────────────────────────────────────────────────────────────────────────
#  Section 11 — VS Code & Antigravity Extensions
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  VS Code & Antigravity Extensions" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

# Refresh PATH so freshly installed IDEs are visible
$env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('PATH', 'User')

if ($SkipExtensions) {
    Write-Host "[$( Get-Timestamp )] ⏭  Skipping extensions (flag set)." -ForegroundColor DarkGray
} else {
    $enabledExtensions = @(
        'xyz.local-history',
        'mrmlnc.vscode-csscomb',
        'PKief.material-icon-theme',
        'maciejdems.add-to-gitignore',
        'astro-build.astro-vscode',
        'formulahendry.auto-close-tag',
        'steoates.autoimport',
        'NuclleaR.vscode-extension-auto-import',
        'formulahendry.auto-rename-tag',
        'oleksandr.beatify-ejs',
        'michelemelluso.code-beautifier',
        'aaron-bond.better-comments',
        'anseki.vscode-color',
        'BrainstormDevelopment.copy-project-tree',
        'pranaygp.vscode-css-peek',
        'easy-snippet-maker.custom-snippet-maker',
        'usernamehw.errorlens',
        'rslfrkndmrky.rsl-vsc-focused-folder',
        'vincaslt.highlight-matching-tag',
        'hwencc.html-tag-wrapper',
        'bradgashler.htmltagwrap',
        'kisstkondoros.vscode-gutter-preview',
        'DutchIgor.json-viewer',
        'ms-vscode.live-server',
        'ritwickdey.LiveServer',
        'zaaack.markdown-editor',
        'unifiedjs.vscode-mdx',
        'josee9988.minifyall',
        'mrkou47.npmignore',
        'ionutvmi.path-autocomplete',
        'christian-kohler.path-intellisense',
        'johnpapa.vscode-peacock',
        'esbenp.prettier-vscode',
        'sototecnologia.remove-comments-frontend',
        'misbahansori.svg-fold',
        'vdanchenkov.tailwind-class-sorter',
        'sidharthachatterjee.vscode-tailwindcss',
        'bradlc.vscode-tailwindcss',
        'esdete.tailwind-rainbow',
        'bourhaouta.tailwindshades',
        'dejmedus.tailwind-sorter',
        'meganrogge.template-string-converter',
        'shardulm94.trailing-spaces',
        'Phu1237.vs-browser',
        'westenets.vscode-backup',
        'MarkosTh09.color-picker',
        'redhat.vscode-yaml',
        'streetsidesoftware.code-spell-checker'
    )

    $disabledExtensions = @(
        'tamasfe.even-better-toml',
        'DavidKol.fastcompare',
        'Nobuwu.mc-color',
        'Misodee.vscode-nbt',
        'WebCrafter.auto-type-code',
        'adpyke.codesnap',
        'WebNative.webnative'
    )

    # Extensions that only exist in the VS Code marketplace — silently skipped in Antigravity
    $vscodeOnlyExtensions = @(
        'mrmlnc.vscode-csscomb',
        'maciejdems.add-to-gitignore',
        'NuclleaR.vscode-extension-auto-import',
        'oleksandr.beatify-ejs',
        'michelemelluso.code-beautifier',
        'BrainstormDevelopment.copy-project-tree',
        'easy-snippet-maker.custom-snippet-maker',
        'rslfrkndmrky.rsl-vsc-focused-folder',
        'hwencc.html-tag-wrapper',
        'DutchIgor.json-viewer',
        'mrkou47.npmignore',
        'sototecnologia.remove-comments-frontend',
        'misbahansori.svg-fold',
        'vdanchenkov.tailwind-class-sorter',
        'sidharthachatterjee.vscode-tailwindcss',
        'bourhaouta.tailwindshades',
        'westenets.vscode-backup',
        'MarkosTh09.color-picker'
    )

    Install-VSExtensions -EnabledExtensions $enabledExtensions -DisabledExtensions $disabledExtensions -VSCodeOnlyExtensions $vscodeOnlyExtensions
}

# ─────────────────────────────────────────────────────────────────────────────
#  Section 12 — Windows 11 Debloat & Configuration
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Windows 11 Debloat & Configuration" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

if ($SkipDebloat) {
    Write-Host "[$( Get-Timestamp )] ⏭  Skipping debloat (flag set)." -ForegroundColor DarkGray
} else {
    # Create restore point before debloat
    Write-Host "[$( Get-Timestamp )] 🛡  Creating system restore point …" -ForegroundColor DarkCyan
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'Before Windows 11 Setup Script Debloat' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Host "[$( Get-Timestamp )]    ✅ Restore point created." -ForegroundColor Green
    } catch {
        Write-Host "[$( Get-Timestamp )]    ⚠️  Could not create restore point: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # ── 12A — Bloat App Removal ───────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 🗑  12A — Removing bloat apps …" -ForegroundColor Cyan

    Remove-AppxIfPresent -PackageName 'Microsoft.BingNews'                 -Label 'MSN News'
    Remove-AppxIfPresent -PackageName 'Microsoft.GamingApp'                -Label 'Xbox Gaming App'
    Remove-AppxIfPresent -PackageName 'Microsoft.XboxGameOverlay'          -Label 'Xbox Game Overlay'
    Remove-AppxIfPresent -PackageName 'Microsoft.XboxGamingOverlay'        -Label 'Xbox Gaming Overlay'
    Remove-AppxIfPresent -PackageName 'Microsoft.XboxIdentityProvider'     -Label 'Xbox Identity Provider'
    Remove-AppxIfPresent -PackageName 'Microsoft.XboxSpeechToTextOverlay'  -Label 'Xbox Speech Overlay'
    Remove-AppxIfPresent -PackageName 'Microsoft.Xbox.TCUI'                -Label 'Xbox TCUI'
    Remove-AppxIfPresent -PackageName 'Microsoft.ZuneMusic'                -Label 'Groove Music'
    Remove-AppxIfPresent -PackageName 'Microsoft.ZuneVideo'                -Label 'Movies & TV'
    Remove-AppxIfPresent -PackageName 'Microsoft.People'                   -Label 'People'
    Remove-AppxIfPresent -PackageName 'Microsoft.WindowsMaps'              -Label 'Maps'
    Remove-AppxIfPresent -PackageName 'Microsoft.WindowsFeedbackHub'       -Label 'Feedback Hub'
    Remove-AppxIfPresent -PackageName 'Microsoft.GetHelp'                  -Label 'Get Help'
    Remove-AppxIfPresent -PackageName 'Microsoft.Getstarted'               -Label 'Get Started / Tips'
    Remove-AppxIfPresent -PackageName 'Microsoft.549981C3F5F10'            -Label 'Cortana'
    Remove-AppxIfPresent -PackageName 'MicrosoftTeams'                     -Label 'Microsoft Teams (personal)'
    Remove-AppxIfPresent -PackageName 'Microsoft.MicrosoftSolitaireCollection' -Label 'Solitaire Collection'
    Remove-AppxIfPresent -PackageName 'Microsoft.PowerAutomateDesktop'     -Label 'Power Automate'
    Remove-AppxIfPresent -PackageName 'Microsoft.Todos'                    -Label 'Microsoft To Do'
    Remove-AppxIfPresent -PackageName 'MicrosoftCorporationII.QuickAssist' -Label 'Quick Assist'
    Remove-AppxIfPresent -PackageName 'Microsoft.BingWeather'              -Label 'MSN Weather'

    # ── 12B — Privacy & Telemetry ─────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 🔒 12B — Privacy & Telemetry …" -ForegroundColor Cyan

    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry'          -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'         -Name 'EnableActivityFeed'       -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'         -Name 'PublishUserActivities'    -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_TrackProgs' -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'   -Name 'Enabled'          -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338389Enabled' -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-353694Enabled' -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-353696Enabled' -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338387Enabled' -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'ConfigureWindowsSpotlight'       -Value 2
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'           -Name 'DisableLocation'                -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice'                         -Name 'AllowFindMyDevice'              -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\BingAdsSuppression'     -Name 'BlockBingAds'                   -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DynamicContent\Settings' -Name 'IsDynamicSettingsEnabled'      -Value 0

    # ── 12C — AI Features ─────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 🤖 12C — Disabling AI features …" -ForegroundColor Cyan

    Remove-AppxIfPresent -PackageName 'Microsoft.Windows.Copilot' -Label 'Microsoft Copilot'
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot'  -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'      -Name 'AllowRecallEnablement'  -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'      -Name 'EnableClickToDo'        -Value 0

    # Prevent AI service auto-start
    try {
        $svc = Get-Service -Name 'WSAIFabricSvc' -ErrorAction SilentlyContinue
        if ($svc) {
            Set-Service -Name 'WSAIFabricSvc' -StartupType Manual -ErrorAction SilentlyContinue
            Write-Host "[$( Get-Timestamp )]    ✅ WSAIFabricSvc set to Manual." -ForegroundColor DarkGreen
        }
    } catch {}

    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'          -Name 'HubsSidebarEnabled'              -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'          -Name 'CopilotCDPPageContext'            -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Paint'         -Name 'DisableCocreator'                 -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Notepad'       -Name 'DisableAIAssistant'               -Value 1

    # ── 12D — System Tweaks ───────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] ⚙️  12D — System tweaks …" -ForegroundColor Cyan

    # Classic context menu
    $ctxPath = 'HKCU:\SOFTWARE\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
    if (-not (Test-Path $ctxPath)) { New-Item -Path $ctxPath -Force | Out-Null }
    Set-ItemProperty -Path $ctxPath -Name '(Default)' -Value '' -Type String -Force

    Set-RegistryValue -Path 'HKCU:\Control Panel\Accessibility\StickyKeys' -Name 'WinEnable' -Value 0 -Type String
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Name 'DODownloadMode' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'     -Name 'NoAutoRebootWithLoggedOnUsers' -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'        -Name 'DeferFeatureUpdatesPeriodInDays' -Value 7

    # ── 12E — Start Menu & Search ─────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 🔍 12E — Start Menu & Search …" -ForegroundColor Cyan

    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideRecommendedSection' -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Name 'BingSearchEnabled'            -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Name 'EnableDynamicContentInWSB'    -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana'               -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_AccountNotifications' -Value 0

    # ── 12F — Taskbar ─────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 📌 12F — Taskbar …" -ForegroundColor Cyan

    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowTaskViewButton'    -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'                             -Name 'AllowWidgets'          -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'            -Name 'SearchboxTaskbarMode'  -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarEndTask'        -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'LastActiveClick'       -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn'             -Value 0

    # ── 12G — File Explorer ───────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 📁 12G — File Explorer …" -ForegroundColor Cyan

    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'LaunchTo'         -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt'     -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Hidden'          -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HubMode'  -Name 'HubMode'         -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowDriveLettersFirst' -Value 4

    # Hide Gallery from nav pane
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}' -Name 'System.IsPinnedToNameSpaceTree' -Value 0

    # Hide OneDrive from nav pane
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' -Name 'System.IsPinnedToNameSpaceTree' -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Classes\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' -Name 'System.IsPinnedToNameSpaceTree' -Value 0

    # ── 12H — OneDrive ────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] ☁️  12H — OneDrive startup …" -ForegroundColor Cyan

    try {
        $runKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
        if ((Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue).OneDrive) {
            Remove-ItemProperty -Path $runKey -Name 'OneDrive' -Force -ErrorAction SilentlyContinue
            Write-Host "[$( Get-Timestamp )]    ✅ OneDrive startup entry removed." -ForegroundColor DarkGreen
        }
    } catch {}

    # ── 12I — Multi-tasking ───────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 🪟 12I — Multi-tasking …" -ForegroundColor Cyan

    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'SnapAssist'              -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'MultiTaskingAltTabFilter' -Value 3

    # ── 12J — Gaming ─────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 🎮 12J — Gaming / DVR …" -ForegroundColor Cyan

    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Value 0
    Set-RegistryValue -Path 'HKCU:\System\GameConfigStore'                             -Name 'GameDVR_Enabled'  -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'        -Name 'AllowGameDVR'    -Value 0

    # ── 12K — Optional Windows Features ──────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 🧩 12K — Optional Features …" -ForegroundColor Cyan

    # Windows Sandbox (Pro+ only)
    $edition = (Get-WindowsEdition -Online -ErrorAction SilentlyContinue).Edition
    if ($edition -match 'Pro|Enterprise|Education') {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName 'Containers-DisposableClientVM' -All -NoRestart -ErrorAction Stop | Out-Null
            Write-Host "[$( Get-Timestamp )]    ✅ Windows Sandbox enabled." -ForegroundColor DarkGreen
        } catch {
            Write-Host "[$( Get-Timestamp )]    ⚠️  Windows Sandbox: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[$( Get-Timestamp )]    ⏭  Windows Sandbox requires Pro+ — skipping." -ForegroundColor DarkGray
    }

    # WSL
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux' -All -NoRestart -ErrorAction Stop | Out-Null
        Write-Host "[$( Get-Timestamp )]    ✅ WSL feature enabled." -ForegroundColor DarkGreen
    } catch {
        Write-Host "[$( Get-Timestamp )]    ⚠️  WSL: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # ── 12L — Dark Mode ───────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 🌙 12L — Dark Mode …" -ForegroundColor Cyan

    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme'   -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'SystemUsesLightTheme' -Value 0
}

# ─────────────────────────────────────────────────────────────────────────────
#  Section 13 — EU Privacy Unlock
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  EU Privacy Unlock" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

if ($SkipEUPrivacy) {
    Write-Host "[$( Get-Timestamp )] ⏭  Skipping EU privacy unlock (flag set)." -ForegroundColor DarkGray
} else {
    $origGeo = (Get-WinHomeLocation).GeoId
    $ts      = Get-Timestamp

    Write-Host "[$ts] 🔒 Temporarily switching region to Ireland (EU) …" -ForegroundColor DarkCyan
    try {
        Set-WinHomeLocation -GeoId 94 -ErrorAction Stop
        Write-Host "[$( Get-Timestamp )]    ✅ Region set to Ireland." -ForegroundColor DarkGreen
    } catch {
        Write-Host "[$( Get-Timestamp )]    ⚠️  Could not change region: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Write-Host "[$( Get-Timestamp )]    Deleting DeviceRegion registry values …" -ForegroundColor DarkCyan
    try {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
            'SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\DeviceRegion', $true
        )

        if ($key) {
            $valueNames = $key.GetValueNames()
            foreach ($val in $valueNames) {
                try { $key.DeleteValue($val) } catch {}
            }
            $remaining = $key.GetValueNames().Count
            $key.Close()

            if ($remaining -eq 0) {
                Write-Host "[$( Get-Timestamp )]    ✅ DeviceRegion values cleared." -ForegroundColor Green
                Add-Result -App 'EU Privacy Unlock' -Status 'Installed'
            } else {
                Write-Host "[$( Get-Timestamp )]    ⚠️  $remaining value(s) could not be deleted." -ForegroundColor Yellow
                Add-Result -App 'EU Privacy Unlock' -Status 'Failed'
            }
        } else {
            Write-Host "[$( Get-Timestamp )]    ℹ  DeviceRegion key not found — already clear." -ForegroundColor Cyan
            Add-Result -App 'EU Privacy Unlock' -Status 'Skipped'
        }
    } catch {
        Write-Host "[$( Get-Timestamp )]    ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        Add-Result -App 'EU Privacy Unlock' -Status 'Failed'
    }

    Write-Host "[$( Get-Timestamp )]    Restoring original region (GeoID: $origGeo) …" -ForegroundColor DarkCyan
    try {
        Set-WinHomeLocation -GeoId $origGeo -ErrorAction Stop
        Write-Host "[$( Get-Timestamp )]    ✅ Region restored." -ForegroundColor DarkGreen
    } catch {
        Write-Host "[$( Get-Timestamp )]    ⚠️  Could not restore region. Run manually: Set-WinHomeLocation -GeoId $origGeo" -ForegroundColor Yellow
    }
}

# ─────────────────────────────────────────────────────────────────────────────
#  Section 14 — Summary
# ─────────────────────────────────────────────────────────────────────────────

$elapsed  = (Get-Date) - $startTime
$mins     = [int]$elapsed.TotalMinutes
$secs     = $elapsed.Seconds

$installed  = $script:results | Where-Object { $_.Status -eq 'Installed' }
$skipped    = $script:results | Where-Object { $_.Status -eq 'Skipped'   }
$notFound   = $script:results | Where-Object { $_.Status -eq 'Not Found' }
$failed     = $script:results | Where-Object { $_.Status -eq 'Failed'    }

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  SETUP COMPLETE — Summary" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

Write-Host "✅ Installed ($($installed.Count)):" -ForegroundColor Green
$installed | ForEach-Object { Write-Host "     $($_.App)" -ForegroundColor DarkGreen }

Write-Host ""
Write-Host "⏭  Skipped ($($skipped.Count)):" -ForegroundColor DarkGray
$skipped | ForEach-Object { Write-Host "     $($_.App)" -ForegroundColor DarkGray }

if ($notFound.Count -gt 0) {
    Write-Host ""
    Write-Host "🔍 Not Found ($($notFound.Count)):" -ForegroundColor Yellow
    $notFound | ForEach-Object { Write-Host "     $($_.App)" -ForegroundColor Yellow }
}

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "❌ Failed ($($failed.Count)):" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "     $($_.App)" -ForegroundColor Red }
}

Write-Host ""
Write-Host "⏱  Total time: $mins minutes $secs seconds" -ForegroundColor Cyan
Write-Host "📄 Log saved to: $logFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  A restart may be required for all changes to take effect." -ForegroundColor Yellow
Write-Host ""
Write-Host "Made with ❤️ by Harman Singh Hira — https://me.hsinghhira.me" -ForegroundColor Gray
Write-Host ""

try { Stop-Transcript | Out-Null } catch {}
exit 0
# SIG # End of script — any content below this line is ignored