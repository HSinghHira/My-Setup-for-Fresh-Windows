#Requires -Version 5.1
# Windows 11 Setup Script - Master Edition
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

# --- Bootstrapping Logic -------------------------------------------------------

$script:isRemote = [string]::IsNullOrEmpty($PSScriptRoot)
$script:repoName = "HSinghHira/My-Setup-after-Fresh-Windows-Installation"
$script:baseUrl  = "https://raw.githubusercontent.com/$($script:repoName)/main"

# This block will be used to import files either locally or remotely
$script:Bootstrapper = {
    param([string]$RelativePath)
    if ($script:isRemote) {
        $url = "$($script:baseUrl)/$($RelativePath)".Replace('\', '/')
        Write-Host "  > Bootstrapping: $RelativePath ..." -ForegroundColor Gray
        try {
            $content = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
            . ([scriptblock]::Create($content))
        } catch {
            Write-Host "X Failed to download $RelativePath from $url" -ForegroundColor Red
            throw $_
        }
    } else {
        $path = Join-Path $PSScriptRoot $RelativePath
        if (Test-Path $path) {
            . $path
        } else {
            Write-Host "X Local file not found: $path" -ForegroundColor Red
            throw "File not found: $path"
        }
    }
}

# --- Load Libraries -----------------------------------------------------------

. $script:Bootstrapper "scripts\Helpers.ps1"
. $script:Bootstrapper "scripts\Installers.ps1"
. $script:Bootstrapper "scripts\Extensions.ps1"

# ------------------------------------------------------------------------------
#  Transcript / Log File -> saved to Desktop
# ------------------------------------------------------------------------------

$startTime = Get-Date
$logRoot   = [Environment]::GetFolderPath('Desktop')
$logFile   = Join-Path $logRoot ("setup-log-" + $startTime.ToString('yyyy-MM-dd_HH-mm') + ".txt")
Start-Transcript -Path $logFile | Out-Null

# ------------------------------------------------------------------------------
#  Initialisation
# ------------------------------------------------------------------------------

$script:tempFiles = [System.Collections.Generic.List[string]]::new()
$script:results   = [System.Collections.Generic.List[PSCustomObject]]::new()

# --- Admin Check --------------------------------------------------------------

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "X This script must be run as Administrator." -ForegroundColor Red
    Write-Host "  Right-click PowerShell and choose 'Run as administrator'." -ForegroundColor Yellow
    Write-Host ""
    try { Stop-Transcript | Out-Null } catch {}
    exit 1
}

# --- Banner -------------------------------------------------------------------

Clear-Host
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "         Windows 11 Setup Script - Master Edition             " -ForegroundColor Cyan
Write-Host "                  by Harman Singh Hira                        " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "================================================================" -ForegroundColor Yellow
    Write-Host "   DRY-RUN MODE - Nothing will be installed or changed        " -ForegroundColor Yellow
    Write-Host "   All steps will be printed but not executed                 " -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Yellow
    Write-Host ""
}

# ------------------------------------------------------------------------------
#  Section 4 - Winget Self-Update
# ------------------------------------------------------------------------------

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Updating winget ..." -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "[$( Get-Timestamp )] X winget not found. Install 'App Installer' from the MS Store." -ForegroundColor Red
    try { Stop-Transcript | Out-Null } catch {}
    exit 1
}

winget upgrade --id Microsoft.AppInstaller --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
winget source update 2>&1 | Out-Null
Write-Host "[$( Get-Timestamp )] OK winget updated." -ForegroundColor Green

# ------------------------------------------------------------------------------
#  Section 5 - Runtimes & Redistributables
# ------------------------------------------------------------------------------

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Runtimes & Redistributables" -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

if ($SkipRuntimes) {
    Write-Host "[$( Get-Timestamp )] - Skipping runtimes (flag set)." -ForegroundColor DarkGray
} else {
    Install-WingetApp -Id 'Microsoft.VCRedist.2015+.x64'      -Label 'VC++ Redistributable 2015+ (x64)'
    Install-WingetApp -Id 'Microsoft.DotNet.DesktopRuntime.5'  -Label '.NET Desktop Runtime 5'
    Install-WingetApp -Id 'Microsoft.DotNet.DesktopRuntime.6'  -Label '.NET Desktop Runtime 6'
    Install-WingetApp -Id 'Microsoft.DotNet.DesktopRuntime.8'  -Label '.NET Desktop Runtime 8'
    Install-WingetApp -Id 'Microsoft.DotNet.DesktopRuntime.10' -Label '.NET Desktop Runtime 10'
}

# ------------------------------------------------------------------------------
#  Section 6 - Core Apps
# ------------------------------------------------------------------------------

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Core Apps" -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

if ($SkipCoreApps) {
    Write-Host "[$( Get-Timestamp )] - Skipping core apps (flag set)." -ForegroundColor DarkGray
} else {
    Install-WingetApp -Id '7zip.7zip'      -Label '7-Zip'
    Install-WingetApp -Id 'Daum.PotPlayer' -Label 'PotPlayer'
    Install-WingetApp -Id 'ShareX.ShareX'  -Label 'ShareX'
    Install-WingetApp -Id 'Gyan.FFmpeg'    -Label 'FFmpeg'
}

# ------------------------------------------------------------------------------
#  Section 7 - System Utilities
# ------------------------------------------------------------------------------

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  System Utilities" -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

if ($SkipSystemUtils) {
    Write-Host "[$( Get-Timestamp )] - Skipping system utilities (flag set)." -ForegroundColor DarkGray
} else {
    Install-WingetApp -Id 'xanderfrangos.twinkletray'   -Label 'TwinkleTray'
    Install-WingetApp -Id 'File-New-Project.EarTrumpet' -Label 'EarTrumpet'
    Install-WingetApp -Id 'CrystalRich.LockHunter'      -Label 'LockHunter'
    Install-WingetApp -Id 'Klocman.BulkCrapUninstaller' -Label 'Bulk Crap Uninstaller'
    Install-WingetApp -Id '9P7KNL5RWT25'                -Label 'Sysinternals Suite' -Source 'msstore'
}

# ------------------------------------------------------------------------------
#  Section 8 - Productivity Apps
# ------------------------------------------------------------------------------

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Productivity Apps" -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

if ($SkipProductivity) {
    Write-Host "[$( Get-Timestamp )] - Skipping productivity apps (flag set)." -ForegroundColor DarkGray
} else {
    Install-WingetApp -Id 'PDFgear.PDFgear'                    -Label 'PDFgear'
    Install-WingetApp -Id 'JavadMotallebi.NeatDownloadManager' -Label 'Neat Download Manager'
    Install-WingetApp -Id 'flux.flux'                          -Label 'f.lux'
    Install-WingetApp -Id 'riyasy.FlyPhotos'                   -Label 'FlyPhotos'
    Install-WingetApp -Id 'UnifiedIntents.UnifiedRemote'       -Label 'Unified Remote'
    Install-WingetApp -Id 'Ditto.Ditto'                        -Label 'Ditto'
}

# ------------------------------------------------------------------------------
#  Section 9 - Dev Setup
# ------------------------------------------------------------------------------

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Dev Setup" -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

if ($SkipDevSetup) {
    Write-Host "[$( Get-Timestamp )] - Skipping dev setup (flag set)." -ForegroundColor DarkGray
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

    $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('PATH', 'User')

    if (Get-Command volta -ErrorAction SilentlyContinue) {
        Write-Host "[$( Get-Timestamp )] # Installing Node via Volta ..." -ForegroundColor DarkCyan
        volta install node 2>&1 | Out-Null
        Add-Result -App 'Node (via Volta)' -Status 'Installed'
    }
}

# ------------------------------------------------------------------------------
#  Section 10 - Microsoft Store Apps
# ------------------------------------------------------------------------------

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Microsoft Store Apps" -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

if ($SkipStoreApps) {
    Write-Host "[$( Get-Timestamp )] - Skipping Store apps (flag set)." -ForegroundColor DarkGray
} else {
    Install-WingetApp -Id '9PKTQ5699M62' -Label 'iCloud' -Source 'msstore'
    Install-WingetApp -Id '9n7jsxc1sjk6' -Label 'Blip'   -Source 'msstore'
    Install-AppxFromStore -ProductId '9p64kgf20h0t' -Label 'Edison Mail' -PackageNamePattern '*Edison*'
}

# ------------------------------------------------------------------------------
#  Section 11 - VS Code & Antigravity Extensions
# ------------------------------------------------------------------------------

$env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('PATH', 'User')

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  VS Code & Antigravity Extensions" -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

if ($SkipExtensions) {
    Write-Host "[$( Get-Timestamp )] - Skipping extensions (flag set)." -ForegroundColor DarkGray
} else {
    Install-VSExtensions `
        -EnabledExtensions    $enabledExtensions  `
        -DisabledExtensions   $disabledExtensions `
        -VSCodeOnlyExtensions $vscodeOnlyExtensions
}

# --- Sections 12 & 13 (Modular) -----------------------------------------------

. $script:Bootstrapper "scripts\sections\Debloat.ps1"
. $script:Bootstrapper "scripts\sections\Privacy.ps1"

# ------------------------------------------------------------------------------
#  Temp File Cleanup
# ------------------------------------------------------------------------------

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Cleaning up temp files ..." -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

$cleaned = 0
foreach ($file in $script:tempFiles) {
    if (Test-Path $file) {
        try { Remove-Item -Path $file -Force -ErrorAction SilentlyContinue; $cleaned++ } catch {}
    }
}
Write-Host "[$( Get-Timestamp )] OK Cleaned up $cleaned temp file(s)." -ForegroundColor Green

# ------------------------------------------------------------------------------
#  Section 14 - Summary
# ------------------------------------------------------------------------------

$elapsed = (Get-Date) - $startTime
$mins    = [int]$elapsed.TotalMinutes
$secs    = $elapsed.Seconds

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  SETUP COMPLETE - Summary" -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

$script:results | Group-Object Status | ForEach-Object {
    $color = switch ($_.Name) { 'Installed' { 'Green' } 'Skipped' { 'DarkGray' } 'Failed' { 'Red' } default { 'Yellow' } }
    Write-Host "$($_.Name) ($($_.Count)):" -ForegroundColor $color
    $_.Group | ForEach-Object { Write-Host "     $($_.App)" -ForegroundColor $color }
    Write-Host ""
}

Write-Host "(!) Total time: $mins minutes $secs seconds" -ForegroundColor Cyan
Write-Host "(!) Log saved to Desktop: $logFile" -ForegroundColor Cyan
Write-Host "(!) A restart may be required for all changes to take effect." -ForegroundColor Yellow
Write-Host ""
Write-Host "Made with <3 by Harman Singh Hira - https://me.hsinghhira.me" -ForegroundColor Gray
Write-Host ""

try { Stop-Transcript | Out-Null } catch {}
exit 0
