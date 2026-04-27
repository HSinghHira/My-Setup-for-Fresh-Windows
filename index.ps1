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
    [switch]$SkipEUPrivacy,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ─────────────────────────────────────────────────────────────────────────────
#  Transcript / Log File  →  saved to Desktop
# ─────────────────────────────────────────────────────────────────────────────

$startTime = Get-Date
$logRoot   = [Environment]::GetFolderPath('Desktop')
$logFile   = Join-Path $logRoot ("setup-log-" + $startTime.ToString('yyyy-MM-dd_HH-mm') + ".txt")
Start-Transcript -Path $logFile | Out-Null

# ─────────────────────────────────────────────────────────────────────────────
#  Temp-file tracker  (cleaned up at the end)
# ─────────────────────────────────────────────────────────────────────────────

$script:tempFiles = [System.Collections.Generic.List[string]]::new()

# ─────────────────────────────────────────────────────────────────────────────
#  Section 1 — Admin Check  (auto-elevates via UAC if not already admin)
# ─────────────────────────────────────────────────────────────────────────────

# FIX: Initialise $isAdmin before assignment so Set-StrictMode doesn't throw
$isAdmin = $false
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "⚠️  Not running as Administrator — requesting elevation via UAC …" -ForegroundColor Yellow
    Write-Host ""

    # Build argument string, forwarding any switches the user passed
    $psArgs = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($DryRun)           { $psArgs += ' -DryRun' }
    if ($SkipRuntimes)     { $psArgs += ' -SkipRuntimes' }
    if ($SkipCoreApps)     { $psArgs += ' -SkipCoreApps' }
    if ($SkipSystemUtils)  { $psArgs += ' -SkipSystemUtils' }
    if ($SkipProductivity) { $psArgs += ' -SkipProductivity' }
    if ($SkipDevSetup)     { $psArgs += ' -SkipDevSetup' }
    if ($SkipStoreApps)    { $psArgs += ' -SkipStoreApps' }
    if ($SkipExtensions)   { $psArgs += ' -SkipExtensions' }
    if ($SkipDebloat)      { $psArgs += ' -SkipDebloat' }
    if ($SkipEUPrivacy)    { $psArgs += ' -SkipEUPrivacy' }

    try { Stop-Transcript | Out-Null } catch {}
    Start-Process powershell.exe -ArgumentList $psArgs -Verb RunAs
    exit
}

# ─────────────────────────────────────────────────────────────────────────────
#  Section 2 — Result Tracking
# ─────────────────────────────────────────────────────────────────────────────

# FIX: Use a Generic List instead of array += to avoid O(n²) rebuilds
$script:results = [System.Collections.Generic.List[PSCustomObject]]::new()

function Add-Result {
    param([string]$App, [string]$Status)
    $script:results.Add([PSCustomObject]@{ App = $App; Status = $Status })
}

# ─────────────────────────────────────────────────────────────────────────────
#  Clear terminal then show banner
# ─────────────────────────────────────────────────────────────────────────────

Clear-Host

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         Windows 11 Setup Script — Master Edition             ║" -ForegroundColor Cyan
Write-Host "║                  by Harman Singh Hira                        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
#  Dry-Run Notice
# ─────────────────────────────────────────────────────────────────────────────

if ($DryRun) {
    Write-Host ''
    Write-Host '╔══════════════════════════════════════════════════════════════╗' -ForegroundColor Yellow
    Write-Host '║   DRY-RUN MODE — Nothing will be installed or changed        ║' -ForegroundColor Yellow
    Write-Host '║   All steps will be printed but not executed                 ║' -ForegroundColor Yellow
    Write-Host '╚══════════════════════════════════════════════════════════════╝' -ForegroundColor Yellow
    Write-Host ''
}

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
        [string]$Version = '',
        [string]$Source  = 'winget'
    )

    $ts = Get-Timestamp
    Write-Host "[$ts] 📦 $Label …" -ForegroundColor DarkCyan

    # DryRun — print intent only, do nothing
    if ($DryRun) {
        Write-Host "[$ts]    🔍 [DRY-RUN] Would install: $Label (id: $Id)" -ForegroundColor Yellow
        Add-Result -App $Label -Status 'Skipped'
        return
    }

    # Check if already installed
    $listOutput = winget list --id $Id --exact --accept-source-agreements 2>&1
    if ($LASTEXITCODE -eq 0 -and ($listOutput | Select-String -Pattern ([regex]::Escape($Id)))) {
        Write-Host "[$ts]    ⏭  Already installed — skipping." -ForegroundColor DarkGray
        Add-Result -App $Label -Status 'Skipped'
        return
    }

    $installArgs = @('install', '--id', $Id, '--exact', '--silent',
                     '--accept-package-agreements', '--accept-source-agreements',
                     '--source', $Source)
    if ($Version) { $installArgs += @('--version', $Version) }

    $attempt   = 0
    $succeeded = $false

    while ($attempt -lt 2 -and -not $succeeded) {
        $attempt++
        winget @installArgs 2>&1 | Out-Null
        $ec = $LASTEXITCODE

        switch ($ec) {
            0           { $succeeded = $true }
            -1978335189 { Write-Host "[$( Get-Timestamp )]    ⏭  No upgrade available."  -ForegroundColor DarkGray; Add-Result -App $Label -Status 'Skipped';   return }
            -1978335150 { Write-Host "[$( Get-Timestamp )]    ⏭  Already installed."     -ForegroundColor DarkGray; Add-Result -App $Label -Status 'Skipped';   return }
            -1978335212 { Write-Host "[$( Get-Timestamp )]    🔍 Not found in source."   -ForegroundColor Yellow;   Add-Result -App $Label -Status 'Not Found'; return }
            default {
                if ($attempt -lt 2) {
                    Write-Host "[$( Get-Timestamp )]    ⚠️  Attempt $attempt failed (exit $ec). Retrying in 5s …" -ForegroundColor Yellow
                    Start-Sleep -Seconds 5
                }
            }
        }
    }

    if ($succeeded) {
        Write-Host "[$( Get-Timestamp )]    ✅ Installed." -ForegroundColor Green
        Add-Result -App $Label -Status 'Installed'
    } else {
        Write-Host "[$( Get-Timestamp )]    ❌ Failed after 2 attempts." -ForegroundColor Red
        Add-Result -App $Label -Status 'Failed'
    }
}

# ── Install-AppxFromStore ─────────────────────────────────────────────────────
# Tries tplant REST API first, falls back to AdGuard HTML scrape.
# FIX: Get-AppxPackage -AllUsers throws Access Denied on some machines even when
#      elevated. Now falls back gracefully to current-user query.

function Install-AppxFromStore {
    param(
        [string]$ProductId,
        [string]$Label,
        [string]$PackageNamePattern = ''
    )

    $ts       = Get-Timestamp
    $storeUrl = "https://apps.microsoft.com/detail/$ProductId"

    # ── Already-installed check ───────────────────────────────────────────────
    $pattern = if ($PackageNamePattern) { $PackageNamePattern } else { "*$Label*" }

    # FIX: -AllUsers can throw UnauthorizedAccessException even as admin; fall back to current user
    $existing = try {
        Get-AppxPackage -AllUsers -ErrorAction Stop | Where-Object { $_.Name -like $pattern }
    } catch {
        Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $pattern }
    }

    if ($existing) {
        Write-Host "[$ts] ⏭  $Label already installed — skipping." -ForegroundColor DarkGray
        Add-Result -App $Label -Status 'Skipped'
        return
    }

    Write-Host "[$ts] 📦 $Label (Store fallback) …" -ForegroundColor DarkCyan

    # DryRun — print intent only
    if ($DryRun) {
        Write-Host "[$ts]    🔍 [DRY-RUN] Would install Store app: $Label (id: $ProductId)" -ForegroundColor Yellow
        Add-Result -App $Label -Status 'Skipped'
        return
    }

    $success = $false

    # ── Source 1: tplant REST API ─────────────────────────────────────────────
    try {
        $apiUrl  = "https://msft-store.tplant.com.au/api/Packages?id=$storeUrl&environment=Production&inputform=url"
        $pkgs    = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop

        if ($pkgs -and @($pkgs).Count -gt 0) {
            $arch = Get-ArchTag
            $pkg  = $pkgs | Where-Object { $_.packagefilename -like '*x64*' } | Select-Object -First 1
            if (-not $pkg) { $pkg = $pkgs | Where-Object { $_.packagefilename -like "*$arch*" } | Select-Object -First 1 }
            if (-not $pkg) { $pkg = $pkgs | Select-Object -First 1 }

            $fileName = $pkg.packagefilename
            $outPath  = Resolve-UniqueFilePath (Join-Path $env:TEMP $fileName)

            Write-Host "[$( Get-Timestamp )]    ⬇  tplant → $fileName" -ForegroundColor DarkCyan
            Invoke-WebRequest -Uri $pkg.packagedownloadurl -OutFile $outPath -UseBasicParsing -ErrorAction Stop
            $script:tempFiles.Add($outPath)

            Add-AppxPackage -Path $outPath -ErrorAction Stop

            Write-Host "[$( Get-Timestamp )]    ✅ $Label installed (tplant)." -ForegroundColor Green
            Add-Result -App $Label -Status 'Installed'
            $success = $true
        }
    } catch {
        Write-Host "[$( Get-Timestamp )]    ⚠️  tplant failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # ── Source 2: AdGuard HTML scrape (fallback) ──────────────────────────────
    if (-not $success) {
        try {
            Write-Host "[$( Get-Timestamp )]    🔄 Falling back to AdGuard …" -ForegroundColor Yellow
            $body     = "type=url&url=$storeUrl&ring=Retail"
            $response = Invoke-WebRequest -UseBasicParsing -Method POST `
                            -Uri 'https://store.rg-adguard.net/api/GetFiles' `
                            -Body $body -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop

            $arch  = Get-ArchTag
            $links = $response.Links |
                     Where-Object { $_ -like '*.appx*' -or $_ -like '*.appxbundle*' -or
                                    $_ -like '*.msix*'  -or $_ -like '*.msixbundle*' } |
                     Where-Object { $_ -like '*_neutral_*' -or $_ -like "*_${arch}_*" } |
                     Select-String -Pattern '(?<=a href=").+(?=" r)'

            $urls = @($links | ForEach-Object { $_.Matches.Value })
            if ($urls.Count -eq 0) { throw "No packages found." }

            foreach ($url in $urls) {
                try {
                    $req      = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
                    $fileName = ($req.Headers['Content-Disposition'] |
                                 Select-String -Pattern '(?<=filename=).+').Matches.Value
                    if (-not $fileName) { $fileName = Split-Path $url -Leaf }

                    $outPath = Resolve-UniqueFilePath (Join-Path $env:TEMP $fileName)
                    Write-Host "[$( Get-Timestamp )]    ⬇  AdGuard → $fileName" -ForegroundColor DarkCyan
                    [System.IO.File]::WriteAllBytes($outPath, $req.Content)
                    $script:tempFiles.Add($outPath)

                    Add-AppxPackage -Path $outPath -ErrorAction Stop

                    Write-Host "[$( Get-Timestamp )]    ✅ $Label installed (AdGuard)." -ForegroundColor Green
                    Add-Result -App $Label -Status 'Installed'
                    $success = $true
                    break
                } catch {
                    Write-Host "[$( Get-Timestamp )]    ⚠️  Package failed, trying next …" -ForegroundColor Yellow
                }
            }
        } catch {
            Write-Host "[$( Get-Timestamp )]    ❌ AdGuard also failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if (-not $success) {
        Add-Result -App $Label -Status 'Failed'
    }
}

# ── Invoke-IdeCli ─────────────────────────────────────────────────────────────
# FIX: The root cause of VS Code / Antigravity windows opening during extension
#      installs is that the bare 'code' / 'antigravity' command in PATH resolves
#      to the GUI .exe on some installs.  We now:
#        1. Prefer the .cmd shim  (code.cmd / antigravity.cmd) which is the
#           proper headless CLI wrapper installed by both apps.
#        2. Fall back to Start-Process with -WindowStyle Hidden + -Wait so even
#           if the .exe is invoked it never produces a visible window.
#      Returns the process exit code.

function Invoke-IdeCli {
    param(
        [string]$Cli,
        [string[]]$Arguments
    )

    # Prefer the .cmd shim — it is the true headless CLI and never opens a window
    $cmdShim = (Get-Command "$Cli.cmd" -ErrorAction SilentlyContinue)?.Source
    if ($cmdShim) {
        # Run via cmd.exe so the .cmd file executes correctly and output is suppressed
        $proc = Start-Process -FilePath 'cmd.exe' `
                    -ArgumentList (@('/c', "`"$cmdShim`"") + $Arguments) `
                    -WindowStyle Hidden -PassThru -Wait -ErrorAction Stop
        return $proc.ExitCode
    }

    # Fallback: use the bare CLI with Hidden window style
    $exePath = (Get-Command $Cli -ErrorAction SilentlyContinue)?.Source
    if (-not $exePath) { return 1 }

    $proc = Start-Process -FilePath $exePath `
                -ArgumentList $Arguments `
                -WindowStyle Hidden -PassThru -Wait -ErrorAction Stop
    return $proc.ExitCode
}

# ── Install-VSExtensions ──────────────────────────────────────────────────────

function Install-VSExtensions {
    param(
        [string[]]$EnabledExtensions,
        [string[]]$DisabledExtensions   = @(),
        [string[]]$VSCodeOnlyExtensions = @()
    )

    $ides = @(
        @{ Name = 'VS Code';     Cli = 'code';        IsAntigravity = $false },
        @{ Name = 'Antigravity'; Cli = 'antigravity';  IsAntigravity = $true  }
    )

    $allExtensions = @(
        $EnabledExtensions  | ForEach-Object { [PSCustomObject]@{ Id = $_; Disable = $false } }
        $DisabledExtensions | ForEach-Object { [PSCustomObject]@{ Id = $_; Disable = $true  } }
    )

    foreach ($ide in $ides) {
        $cli           = $ide.Cli
        $ideName       = $ide.Name
        $isAntigravity = $ide.IsAntigravity

        if (-not (Get-Command $cli -ErrorAction SilentlyContinue) -and
            -not (Get-Command "$cli.cmd" -ErrorAction SilentlyContinue)) {
            Write-Host "[$( Get-Timestamp )]    ⚠️  $ideName CLI ('$cli') not found in PATH — skipping." -ForegroundColor Yellow
            continue
        }

        Write-Host ""
        Write-Host "[$( Get-Timestamp )] 🧩 Installing extensions into $ideName …" -ForegroundColor Cyan

        # FIX: Use Invoke-IdeCli (hidden window) for --list-extensions too
        $rawList = @()
        try {
            # Capture output by redirecting to a temp file to avoid any window
            $tmpOut = [System.IO.Path]::GetTempFileName()
            $script:tempFiles.Add($tmpOut)

            $cmdShim = (Get-Command "$cli.cmd" -ErrorAction SilentlyContinue)?.Source
            if ($cmdShim) {
                $proc = Start-Process -FilePath 'cmd.exe' `
                            -ArgumentList "/c `"$cmdShim`" --list-extensions > `"$tmpOut`" 2>&1" `
                            -WindowStyle Hidden -PassThru -Wait
            } else {
                $exePath = (Get-Command $cli -ErrorAction SilentlyContinue)?.Source
                $proc = Start-Process -FilePath $exePath `
                            -ArgumentList '--list-extensions' `
                            -RedirectStandardOutput $tmpOut `
                            -WindowStyle Hidden -PassThru -Wait
            }
            $rawList = Get-Content $tmpOut -ErrorAction SilentlyContinue
        } catch {}

        $installedList = @($rawList | Where-Object { $_ -is [string] -and $_ -match '\.' } |
                           ForEach-Object { $_.Trim().ToLower() })

        foreach ($ext in $allExtensions) {
            $extId = $ext.Id
            $ts    = Get-Timestamp

            # Skip VS Code-only extensions silently in Antigravity
            if ($isAntigravity -and ($VSCodeOnlyExtensions -icontains $extId)) { continue }

            # DryRun — print intent only
            if ($DryRun) {
                Write-Host "[$ts]    🔍 [DRY-RUN] Would install ext: $extId into $ideName" -ForegroundColor Yellow
                Add-Result -App "$ideName : $extId" -Status 'Skipped'
                continue
            }

            # Already installed?
            if ($installedList -icontains $extId.ToLower()) {
                Write-Host "[$ts]    ⏭  $extId already in $ideName." -ForegroundColor DarkGray
                Add-Result -App "$ideName : $extId" -Status 'Skipped'
            } else {
                # FIX: Use Invoke-IdeCli — hidden window, no GUI popup
                # Drop --force since we already confirmed it's not installed
                $ec = Invoke-IdeCli -Cli $cli -Arguments @('--install-extension', $extId)

                # VSIX fallback for Antigravity
                if ($ec -ne 0 -and $isAntigravity) {
                    Write-Host "[$ts]    ⚠️  Marketplace install failed — trying VSIX download …" -ForegroundColor Yellow
                    $ec = Install-ExtensionViaVsix -Cli $cli -ExtId $extId -IdeName $ideName
                }

                if ($ec -eq 0) {
                    Write-Host "[$ts]    ✅ $extId → $ideName" -ForegroundColor Green
                    Add-Result -App "$ideName : $extId" -Status 'Installed'
                } else {
                    Write-Host "[$ts]    ❌ $extId failed in $ideName (exit $ec)" -ForegroundColor Red
                    Add-Result -App "$ideName : $extId" -Status 'Failed'
                    continue
                }
            }

            # Disable if flagged
            if ($ext.Disable) {
                Invoke-IdeCli -Cli $cli -Arguments @('--disable-extension', $extId) | Out-Null
                Write-Host "[$ts]    🔕 $extId disabled in $ideName" -ForegroundColor DarkGray
            }
        }
    }
}

# ── Install-ExtensionViaVsix ──────────────────────────────────────────────────
# Downloads the latest .vsix from the VS Marketplace and installs it directly.
# Returns 0 on success, 1 on failure.

function Install-ExtensionViaVsix {
    param(
        [string]$Cli,
        [string]$ExtId,
        [string]$IdeName
    )

    try {
        $parts     = $ExtId -split '\.'
        $publisher = $parts[0]
        $extName   = $parts[1..($parts.Count - 1)] -join '.'

        $apiUrl  = 'https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery'
        $body    = @{
            filters = @(@{
                criteria = @(@{ filterType = 7; value = $ExtId })
            })
            flags = 914
        } | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $apiUrl -Method POST -Body $body `
                        -ContentType 'application/json' `
                        -Headers @{ 'Accept' = 'application/json;api-version=7.1-preview.1' } `
                        -ErrorAction Stop

        $version = $response.results[0].extensions[0].versions[0].version
        if (-not $version) { throw "Could not resolve version for $ExtId" }

        $vsixUrl  = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/$publisher/vsextensions/$extName/$version/vspackage"
        $vsixPath = Join-Path $env:TEMP "$publisher.$extName-$version.vsix"
        $vsixPath = Resolve-UniqueFilePath $vsixPath

        Write-Host "[$( Get-Timestamp )]       Downloading $ExtId v$version …" -ForegroundColor DarkCyan
        Invoke-WebRequest -Uri $vsixUrl -OutFile $vsixPath -UseBasicParsing -ErrorAction Stop
        $script:tempFiles.Add($vsixPath)

        # FIX: Use Invoke-IdeCli — no window
        return (Invoke-IdeCli -Cli $Cli -Arguments @('--install-extension', $vsixPath))

    } catch {
        Write-Host "[$( Get-Timestamp )]       VSIX fallback failed: $($_.Exception.Message)" -ForegroundColor Red
        return 1
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
    if ($DryRun) {
        Write-Host "[$( Get-Timestamp )]    🔍 [DRY-RUN] Would set registry: $Name = $Value  ($Path)" -ForegroundColor Yellow
        return
    }

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        Write-Host "[$( Get-Timestamp )]    ✅ $Name = $Value" -ForegroundColor DarkGreen
    } catch {
        Write-Host "[$( Get-Timestamp )]    ⚠️  Could not set [$Name]: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ── Remove-AppxIfPresent ──────────────────────────────────────────────────────

function Remove-AppxIfPresent {
    param(
        [string]$PackageName,
        [string]$Label
    )
    $ts = Get-Timestamp

    if ($DryRun) {
        Write-Host "[$ts]    🔍 [DRY-RUN] Would remove: ${Label}" -ForegroundColor Yellow
        return
    }

    try {
        $pkg  = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
        $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like $PackageName }

        if ($pkg)  { $pkg  | Remove-AppxPackage -ErrorAction SilentlyContinue }
        if ($prov) { $prov | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null }

        if ($pkg -or $prov) {
            Write-Host "[$ts]    ✅ Removed $Label" -ForegroundColor Green
            Add-Result -App "Removed: $Label" -Status 'Installed'
        } else {
            Write-Host "[$ts]    ⏭  $Label not found — skipping." -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "[$ts]    ❌ Failed to remove ${Label}: $($_.Exception.Message)" -ForegroundColor Red
        Add-Result -App "Removed: $Label" -Status 'Failed'
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
    Write-Host "[$( Get-Timestamp )] ❌ winget not found. Install 'App Installer' from the Microsoft Store and re-run." -ForegroundColor Red
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
    Install-WingetApp -Id 'Microsoft.VCRedist.2015+.x64'      -Label 'VC++ Redistributable 2015+ (x64)'
    Install-WingetApp -Id 'Microsoft.DotNet.DesktopRuntime.5'  -Label '.NET Desktop Runtime 5'
    Install-WingetApp -Id 'Microsoft.DotNet.DesktopRuntime.6'  -Label '.NET Desktop Runtime 6'
    Install-WingetApp -Id 'Microsoft.DotNet.DesktopRuntime.8'  -Label '.NET Desktop Runtime 8'
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
    Install-WingetApp -Id '7zip.7zip'      -Label '7-Zip'
    Install-WingetApp -Id 'Daum.PotPlayer' -Label 'PotPlayer'
    Install-WingetApp -Id 'ShareX.ShareX'  -Label 'ShareX'
    Install-WingetApp -Id 'Gyan.FFmpeg'    -Label 'FFmpeg'
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
    Install-WingetApp -Id 'xanderfrangos.twinkletray'   -Label 'TwinkleTray'
    Install-WingetApp -Id 'File-New-Project.EarTrumpet' -Label 'EarTrumpet'
    Install-WingetApp -Id 'CrystalRich.LockHunter'      -Label 'LockHunter'
    Install-WingetApp -Id 'Klocman.BulkCrapUninstaller' -Label 'Bulk Crap Uninstaller'
    Install-WingetApp -Id '9P7KNL5RWT25'                -Label 'Sysinternals Suite' -Source 'msstore'
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
    Install-WingetApp -Id 'PDFgear.PDFgear'                    -Label 'PDFgear'
    Install-WingetApp -Id 'JavadMotallebi.NeatDownloadManager' -Label 'Neat Download Manager'
    Install-WingetApp -Id 'flux.flux'                          -Label 'f.lux'
    Install-WingetApp -Id 'riyasy.FlyPhotos'                   -Label 'FlyPhotos'
    Install-WingetApp -Id 'UnifiedIntents.UnifiedRemote'       -Label 'Unified Remote'
    Install-WingetApp -Id 'Ditto.Ditto'                        -Label 'Ditto'
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
    Install-WingetApp -Id 'Git.Git'                    -Label 'Git'
    Install-WingetApp -Id 'GitHub.cli'                 -Label 'GitHub CLI'
    Install-WingetApp -Id 'Oven-sh.Bun'                -Label 'Bun'
    Install-WingetApp -Id 'Volta.Volta'                -Label 'Volta'
    Install-WingetApp -Id 'Notepad++.Notepad++'        -Label 'Notepad++'
    Install-WingetApp -Id 'Google.Antigravity'         -Label 'Google Antigravity'
    Install-WingetApp -Id 'Microsoft.VisualStudioCode' -Label 'VS Code'
    Install-WingetApp -Id 'Microsoft.WindowsTerminal'  -Label 'Windows Terminal'
    Install-WingetApp -Id 'Microsoft.PowerShell'       -Label 'PowerShell 7'
    Install-WingetApp -Id 'Python.Python.3.11'         -Label 'Python 3.11'

    # Refresh PATH so Volta is immediately available
    $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('PATH', 'User')

    # ── Node via Volta ────────────────────────────────────────────────────────
    if (Get-Command volta -ErrorAction SilentlyContinue) {
        Write-Host "[$( Get-Timestamp )] 📦 Installing Node via Volta …" -ForegroundColor DarkCyan
        volta install node 2>&1 | Out-Null
        Write-Host "[$( Get-Timestamp )]    ✅ Node installed via Volta." -ForegroundColor Green
        Add-Result -App 'Node (via Volta)' -Status 'Installed'
    } else {
        Write-Host "[$( Get-Timestamp )]    ⚠️  Volta not in PATH — skipping Node install." -ForegroundColor Yellow
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
    Install-WingetApp -Id '9PKTQ5699M62' -Label 'iCloud' -Source 'msstore'
    Install-WingetApp -Id '9n7jsxc1sjk6' -Label 'Blip'   -Source 'msstore'

    # Edison Mail — unlisted on Store, use dual-source AppX fallback
    Install-AppxFromStore -ProductId '9p64kgf20h0t' -Label 'Edison Mail' -PackageNamePattern '*Edison*'
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

    # ── Extensions installed and left ENABLED ─────────────────────────────────
    $enabledExtensions = @(
        'xyz.local-history',                       # Local file history
        'mrmlnc.vscode-csscomb',                   # CSS property sorter
        'PKief.material-icon-theme',               # Material file icons
        'maciejdems.add-to-gitignore',             # Add to .gitignore from explorer
        'astro-build.astro-vscode',                # Astro framework support
        'formulahendry.auto-close-tag',            # Auto close HTML/XML tags
        'steoates.autoimport',                     # Auto import suggestions
        'NuclleaR.vscode-extension-auto-import',  # Auto import for JS/TS
        'formulahendry.auto-rename-tag',           # Auto rename paired tags
        'oleksandr.beatify-ejs',                   # EJS beautifier
        'michelemelluso.code-beautifier',          # Code beautifier
        'aaron-bond.better-comments',             # Colour-coded comment annotations
        'anseki.vscode-color',                     # Inline colour picker
        'BrainstormDevelopment.copy-project-tree',# Copy folder tree to clipboard
        'pranaygp.vscode-css-peek',               # Peek CSS from HTML
        'easy-snippet-maker.custom-snippet-maker',# Create custom snippets
        'usernamehw.errorlens',                   # Inline error display
        'rslfrkndmrky.rsl-vsc-focused-folder',    # Focus single folder in explorer
        'vincaslt.highlight-matching-tag',        # Highlight matching HTML tags
        'hwencc.html-tag-wrapper',                # Wrap selection in HTML tag
        'bradgashler.htmltagwrap',                # Wrap selection in HTML tag (alt)
        'kisstkondoros.vscode-gutter-preview',    # Image preview in gutter
        'DutchIgor.json-viewer',                  # JSON tree viewer
        'ms-vscode.live-server',                  # Microsoft Live Preview
        'ritwickdey.LiveServer',                  # Ritwick's Live Server
        'zaaack.markdown-editor',                 # WYSIWYG markdown editor
        'unifiedjs.vscode-mdx',                   # MDX language support
        'josee9988.minifyall',                    # Minify JS/CSS/HTML
        'mrkou47.npmignore',                      # .npmignore support
        'ionutvmi.path-autocomplete',             # Path autocomplete
        'christian-kohler.path-intellisense',     # Path intellisense
        'johnpapa.vscode-peacock',                # Colour-code workspace windows
        'esbenp.prettier-vscode',                 # Prettier formatter
        'sototecnologia.remove-comments-frontend',# Remove frontend comments
        'misbahansori.svg-fold',                  # Fold SVG elements
        'vdanchenkov.tailwind-class-sorter',      # Sort Tailwind classes
        'sidharthachatterjee.vscode-tailwindcss', # Tailwind CSS (alt)
        'bradlc.vscode-tailwindcss',              # Official Tailwind IntelliSense
        'esdete.tailwind-rainbow',                # Colour Tailwind classes
        'bourhaouta.tailwindshades',              # Generate Tailwind shades
        'dejmedus.tailwind-sorter',               # Sort Tailwind classes (alt)
        'meganrogge.template-string-converter',   # Convert to template literals
        'shardulm94.trailing-spaces',             # Highlight trailing spaces
        'Phu1237.vs-browser',                     # In-editor browser
        'westenets.vscode-backup',                # Settings & extension backup
        'MarkosTh09.color-picker',                # Colour picker widget
        'redhat.vscode-yaml',                     # YAML language support
        'streetsidesoftware.code-spell-checker'   # Spell checker
    )

    # ── Extensions installed but started DISABLED ─────────────────────────────
    $disabledExtensions = @(
        'tamasfe.even-better-toml',   # TOML language support
        'DavidKol.fastcompare',       # Fast file comparison
        'Nobuwu.mc-color',            # Minecraft colour codes
        'Misodee.vscode-nbt',         # Minecraft NBT file support
        'WebCrafter.auto-type-code',  # Auto type code snippets
        'adpyke.codesnap',            # Code screenshot tool
        'WebNative.webnative'         # WebNative framework support
    )

    # ── Extensions that only exist in the VS Code Marketplace ────────────────
    # These are silently skipped in Antigravity (no VSIX fallback attempted)
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

    Install-VSExtensions `
        -EnabledExtensions    $enabledExtensions  `
        -DisabledExtensions   $disabledExtensions `
        -VSCodeOnlyExtensions $vscodeOnlyExtensions
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
    # Note: Checkpoint-Computer may fail on Windows 11 Home if System Restore is
    # disabled by default — this is a known Windows limitation and is non-fatal.
    Write-Host "[$( Get-Timestamp )] 🛡  Creating system restore point …" -ForegroundColor DarkCyan
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'Before Windows 11 Setup Script Debloat' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Host "[$( Get-Timestamp )]    ✅ Restore point created." -ForegroundColor Green
    } catch {
        Write-Host "[$( Get-Timestamp )]    ⚠️  Could not create restore point (non-fatal): $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # ── 12A — Bloat App Removal ───────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 🗑  12A — Removing bloat apps …" -ForegroundColor Cyan

    Remove-AppxIfPresent -PackageName 'Microsoft.BingNews'                     -Label 'MSN News'
    Remove-AppxIfPresent -PackageName 'Microsoft.BingWeather'                  -Label 'MSN Weather'
    Remove-AppxIfPresent -PackageName 'Microsoft.GamingApp'                    -Label 'Xbox Gaming App'
    Remove-AppxIfPresent -PackageName 'Microsoft.XboxGameOverlay'              -Label 'Xbox Game Overlay'
    Remove-AppxIfPresent -PackageName 'Microsoft.XboxGamingOverlay'            -Label 'Xbox Gaming Overlay'
    Remove-AppxIfPresent -PackageName 'Microsoft.XboxIdentityProvider'         -Label 'Xbox Identity Provider'
    Remove-AppxIfPresent -PackageName 'Microsoft.XboxSpeechToTextOverlay'      -Label 'Xbox Speech Overlay'
    Remove-AppxIfPresent -PackageName 'Microsoft.Xbox.TCUI'                    -Label 'Xbox TCUI'
    Remove-AppxIfPresent -PackageName 'Microsoft.ZuneMusic'                    -Label 'Groove Music'
    Remove-AppxIfPresent -PackageName 'Microsoft.ZuneVideo'                    -Label 'Movies & TV'
    Remove-AppxIfPresent -PackageName 'Microsoft.People'                       -Label 'People'
    Remove-AppxIfPresent -PackageName 'Microsoft.WindowsMaps'                  -Label 'Maps'
    Remove-AppxIfPresent -PackageName 'Microsoft.WindowsFeedbackHub'           -Label 'Feedback Hub'
    Remove-AppxIfPresent -PackageName 'Microsoft.GetHelp'                      -Label 'Get Help'
    Remove-AppxIfPresent -PackageName 'Microsoft.Getstarted'                   -Label 'Get Started / Tips'
    Remove-AppxIfPresent -PackageName 'Microsoft.549981C3F5F10'                -Label 'Cortana'
    Remove-AppxIfPresent -PackageName 'MicrosoftTeams'                         -Label 'Microsoft Teams (personal)'
    Remove-AppxIfPresent -PackageName 'Microsoft.MicrosoftSolitaireCollection' -Label 'Solitaire Collection'
    Remove-AppxIfPresent -PackageName 'Microsoft.PowerAutomateDesktop'         -Label 'Power Automate'
    Remove-AppxIfPresent -PackageName 'Microsoft.Todos'                        -Label 'Microsoft To Do'
    Remove-AppxIfPresent -PackageName 'MicrosoftCorporationII.QuickAssist'     -Label 'Quick Assist'
    Remove-AppxIfPresent -PackageName 'Clipchamp.Clipchamp'                    -Label 'Clipchamp'
    Remove-AppxIfPresent -PackageName 'Microsoft.MixedReality.Portal'          -Label 'Mixed Reality Portal'
    Remove-AppxIfPresent -PackageName 'Microsoft.SkypeApp'                     -Label 'Skype'
    Remove-AppxIfPresent -PackageName 'Microsoft.WindowsSoundRecorder'         -Label 'Sound Recorder'

    # ── 12B — Privacy & Telemetry ─────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 🔒 12B — Privacy & Telemetry …" -ForegroundColor Cyan

    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'              -Name 'AllowTelemetry'                          -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' -Name 'AllowTelemetry'                        -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'              -Name 'DoNotShowFeedbackNotifications'           -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'                      -Name 'EnableActivityFeed'                       -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'                      -Name 'PublishUserActivities'                    -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'                      -Name 'UploadUserActivities'                     -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'     -Name 'Start_TrackProgs'                         -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'       -Name 'Enabled'                                  -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'             -Name 'DisabledByGroupPolicy'                    -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338388Enabled'         -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338389Enabled'         -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-353694Enabled'         -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-353696Enabled'         -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338387Enabled'         -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SoftLandingEnabled'                      -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SystemPaneSuggestionsEnabled'            -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SilentInstalledAppsEnabled'              -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'OemPreInstalledAppsEnabled'              -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'                -Name 'ConfigureWindowsSpotlight'                -Value 2
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'                -Name 'DisableWindowsSpotlightFeatures'          -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'          -Name 'DisableLocation'                          -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'                  -Name 'LetAppsAccessLocation'                    -Value 2
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice'                        -Name 'AllowFindMyDevice'                        -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'                                -Name 'HideFirstRunExperience'                   -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'                                -Name 'SpotlightExperiencesAndRecommendationsEnabled' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'                                -Name 'NewTabPageContentEnabled'                 -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DynamicContent\Settings' -Name 'IsDynamicSettingsEnabled'               -Value 0

    # ── 12C — AI Features ─────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 🤖 12C — Disabling AI features …" -ForegroundColor Cyan

    Remove-AppxIfPresent -PackageName 'Microsoft.Windows.Copilot' -Label 'Microsoft Copilot'
    Remove-AppxIfPresent -PackageName 'Microsoft.Copilot'         -Label 'Microsoft Copilot (Store)'

    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowCopilotButton' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'      -Name 'AllowRecallEnablement'  -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'      -Name 'DisableAIDataAnalysis'  -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'      -Name 'EnableClickToDo'        -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'                   -Name 'HubsSidebarEnabled'     -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'                   -Name 'CopilotCDPPageContext'  -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Paint'                  -Name 'DisableCocreator'       -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Notepad'                -Name 'DisableAIAssistant'     -Value 1

    # Prevent AI service auto-start
    try {
        $svc = Get-Service -Name 'WSAIFabricSvc' -ErrorAction SilentlyContinue
        if ($svc) {
            Set-Service -Name 'WSAIFabricSvc' -StartupType Manual -ErrorAction SilentlyContinue
            Write-Host "[$( Get-Timestamp )]    ✅ WSAIFabricSvc set to Manual." -ForegroundColor DarkGreen
        }
    } catch {}

    # ── 12D — System Tweaks ───────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] ⚙️  12D — System tweaks …" -ForegroundColor Cyan

    # Classic Windows 10 context menu
    $ctxPath = 'HKCU:\SOFTWARE\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
    if (-not (Test-Path $ctxPath)) { New-Item -Path $ctxPath -Force | Out-Null }
    Set-ItemProperty -Path $ctxPath -Name '(Default)' -Value '' -Type String -Force
    Write-Host "[$( Get-Timestamp )]    ✅ Classic context menu enabled." -ForegroundColor DarkGreen

    # StickyKeys — correct key name is 'Flags', value '506' as String
    Set-RegistryValue -Path 'HKCU:\Control Panel\Accessibility\StickyKeys' -Name 'Flags' -Value '506' -Type String

    # Delivery Optimization & Update tweaks
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Name 'DODownloadMode'                 -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'     -Name 'NoAutoRebootWithLoggedOnUsers'  -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'        -Name 'DeferFeatureUpdates'            -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'        -Name 'DeferFeatureUpdatesPeriodInDays' -Value 7

    # ── 12E — Start Menu & Search ─────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 🔍 12E — Start Menu & Search …" -ForegroundColor Cyan

    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideRecommendedSection'       -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer'               -Name 'DisableSearchBoxSuggestions'   -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'           -Name 'BingSearchEnabled'             -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'           -Name 'EnableDynamicContentInWSB'     -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'           -Name 'CortanaConsent'                -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'         -Name 'DisableWebSearch'              -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'         -Name 'ConnectedSearchUseWeb'         -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'         -Name 'AllowCortana'                  -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_AccountNotifications'   -Value 0

    # ── 12F — Taskbar ─────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 📌 12F — Taskbar …" -ForegroundColor Cyan

    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowTaskViewButton'   -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'                             -Name 'AllowWidgets'         -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'            -Name 'SearchboxTaskbarMode' -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' -Name 'TaskbarEndTask' -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'LastActiveClick'     -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn'           -Value 0

    # ── 12G — File Explorer ───────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 📁 12G — File Explorer …" -ForegroundColor Cyan

    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'LaunchTo'              -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt'           -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Hidden'                -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowDriveLettersFirst'  -Value 4
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'          -Name 'HubMode'               -Value 1

    # Hide Gallery from nav pane
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}' -Name 'System.IsPinnedToNameSpaceTree' -Value 0

    # Hide OneDrive from nav pane
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}'              -Name 'System.IsPinnedToNameSpaceTree' -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Classes\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' -Name 'System.IsPinnedToNameSpaceTree' -Value 0

    # ── 12H — OneDrive startup ────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] ☁️  12H — OneDrive startup …" -ForegroundColor Cyan

    try {
        $runKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
        if ((Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue).OneDrive) {
            Remove-ItemProperty -Path $runKey -Name 'OneDrive' -Force -ErrorAction SilentlyContinue
            Write-Host "[$( Get-Timestamp )]    ✅ OneDrive startup entry removed." -ForegroundColor DarkGreen
        } else {
            Write-Host "[$( Get-Timestamp )]    ⏭  OneDrive startup entry not present." -ForegroundColor DarkGray
        }
    } catch {}

    # ── 12I — Multi-tasking ───────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 🪟 12I — Multi-tasking …" -ForegroundColor Cyan

    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'SnapAssist'               -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'MultiTaskingAltTabFilter'  -Value 3

    # ── 12J — Gaming ─────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 🎮 12J — Gaming / DVR …" -ForegroundColor Cyan

    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Value 0
    Set-RegistryValue -Path 'HKCU:\System\GameConfigStore'                             -Name 'GameDVR_Enabled'   -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'        -Name 'AllowGameDVR'     -Value 0

    # ── 12K — Optional Windows Features ──────────────────────────────────────
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] 🧩 12K — Optional Features …" -ForegroundColor Cyan

    # Windows Sandbox (Pro/Enterprise only)
    $edition = (Get-WindowsEdition -Online -ErrorAction SilentlyContinue).Edition
    if ($edition -match 'Pro|Enterprise|Education') {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName 'Containers-DisposableClientVM' -All -NoRestart -ErrorAction Stop | Out-Null
            Write-Host "[$( Get-Timestamp )]    ✅ Windows Sandbox enabled." -ForegroundColor DarkGreen
            Add-Result -App 'Windows Sandbox' -Status 'Installed'
        } catch {
            Write-Host "[$( Get-Timestamp )]    ⚠️  Windows Sandbox: $($_.Exception.Message)" -ForegroundColor Yellow
            Add-Result -App 'Windows Sandbox' -Status 'Failed'
        }
    } else {
        Write-Host "[$( Get-Timestamp )]    ⏭  Windows Sandbox requires Pro+ (detected: $edition) — skipping." -ForegroundColor DarkGray
        Add-Result -App 'Windows Sandbox' -Status 'Skipped'
    }

    # WSL2 requires BOTH features — WSL + VirtualMachinePlatform
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux' -All -NoRestart -ErrorAction Stop | Out-Null
        Enable-WindowsOptionalFeature -Online -FeatureName 'VirtualMachinePlatform'            -All -NoRestart -ErrorAction Stop | Out-Null
        Write-Host "[$( Get-Timestamp )]    ✅ WSL2 features enabled. Run 'wsl --install' after restart to install a distro." -ForegroundColor DarkGreen
        Add-Result -App 'WSL2' -Status 'Installed'
    } catch {
        Write-Host "[$( Get-Timestamp )]    ⚠️  WSL2: $($_.Exception.Message)" -ForegroundColor Yellow
        Add-Result -App 'WSL2' -Status 'Failed'
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
                Write-Host "[$( Get-Timestamp )]    ✅ DeviceRegion values cleared ($($valueNames.Count) removed)." -ForegroundColor Green
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
#  Temp File Cleanup
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Cleaning up temp files …" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

$cleaned = 0
foreach ($file in $script:tempFiles) {
    if (Test-Path $file) {
        try {
            Remove-Item -Path $file -Force -ErrorAction Stop
            $cleaned++
        } catch {
            Write-Host "[$( Get-Timestamp )]    ⚠️  Could not delete: $file" -ForegroundColor Yellow
        }
    }
}
Write-Host "[$( Get-Timestamp )] ✅ Cleaned up $cleaned temp file(s)." -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
#  Section 14 — Summary
# ─────────────────────────────────────────────────────────────────────────────

$elapsed = (Get-Date) - $startTime
$mins    = [int]$elapsed.TotalMinutes
$secs    = $elapsed.Seconds

$installedItems = @($script:results | Where-Object { $_.Status -eq 'Installed' })
$skippedItems   = @($script:results | Where-Object { $_.Status -eq 'Skipped'   })
$notFoundItems  = @($script:results | Where-Object { $_.Status -eq 'Not Found' })
$failedItems    = @($script:results | Where-Object { $_.Status -eq 'Failed'    })

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  SETUP COMPLETE — Summary" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

Write-Host "✅ Installed ($($installedItems.Count)):" -ForegroundColor Green
$installedItems | ForEach-Object { Write-Host "     $($_.App)" -ForegroundColor DarkGreen }

Write-Host ""
Write-Host "⏭  Skipped ($($skippedItems.Count)):" -ForegroundColor DarkGray
$skippedItems | ForEach-Object { Write-Host "     $($_.App)" -ForegroundColor DarkGray }

if ($notFoundItems.Count -gt 0) {
    Write-Host ""
    Write-Host "🔍 Not Found ($($notFoundItems.Count)):" -ForegroundColor Yellow
    $notFoundItems | ForEach-Object { Write-Host "     $($_.App)" -ForegroundColor Yellow }
}

if ($failedItems.Count -gt 0) {
    Write-Host ""
    Write-Host "❌ Failed ($($failedItems.Count)):" -ForegroundColor Red
    $failedItems | ForEach-Object { Write-Host "     $($_.App)" -ForegroundColor Red }
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