# Installers.ps1 - Installation engines
# Dot-sourced into index.ps1

function Install-WingetApp {
    param(
        [string]$Id,
        [string]$Label,
        [string]$Version = '',
        [string]$Source  = 'winget'
    )

    $ts = Get-Timestamp
    Write-Host "[$ts] # $Label ..." -ForegroundColor DarkCyan

    if ($DryRun) {
        Write-Host "[$ts]    ? [DRY-RUN] Would install: $Label (id: $Id)" -ForegroundColor Yellow
        Add-Result -App $Label -Status 'Skipped'
        return
    }

    $listOutput = winget list --id $Id --exact --accept-source-agreements 2>&1
    if ($LASTEXITCODE -eq 0 -and ($listOutput | Select-String -Pattern ([regex]::Escape($Id)))) {
        Write-Host "[$ts]    - Already installed - skipping." -ForegroundColor DarkGray
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
            -1978335189 { Write-Host "[$( Get-Timestamp )]    - No upgrade available."; Add-Result -App $Label -Status 'Skipped'; return }
            -1978335150 { Write-Host "[$( Get-Timestamp )]    - Already installed.";    Add-Result -App $Label -Status 'Skipped'; return }
            -1978335212 { Write-Host "[$( Get-Timestamp )]    ? Not found in source.";  Add-Result -App $Label -Status 'Not Found'; return }
            default {
                if ($attempt -lt 2) {
                    Write-Host "[$( Get-Timestamp )]    ! Attempt $attempt failed (exit $ec). Retrying in 5s ..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 5
                }
            }
        }
    }

    if ($succeeded) {
        Write-Host "[$( Get-Timestamp )]    OK Installed." -ForegroundColor Green
        Add-Result -App $Label -Status 'Installed'
    } else {
        Write-Host "[$( Get-Timestamp )]    ERROR Failed after 2 attempts." -ForegroundColor Red
        Add-Result -App $Label -Status 'Failed'
    }
}

function Install-AppxFromStore {
    param(
        [string]$ProductId,
        [string]$Label,
        [string]$PackageNamePattern = ''
    )

    $ts       = Get-Timestamp
    $storeUrl = "https://apps.microsoft.com/detail/$ProductId"
    $pattern  = if ($PackageNamePattern) { $PackageNamePattern } else { "*$Label*" }

    $existing = try {
        Get-AppxPackage -AllUsers -ErrorAction Stop | Where-Object { $_.Name -like $pattern }
    } catch {
        Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $pattern }
    }

    if ($existing) {
        Write-Host "[$ts] - $Label already installed - skipping." -ForegroundColor DarkGray
        Add-Result -App $Label -Status 'Skipped'
        return
    }

    Write-Host "[$ts] # $Label (Store fallback) ..." -ForegroundColor DarkCyan

    if ($DryRun) {
        Write-Host "[$ts]    ? [DRY-RUN] Would install Store app: $Label (id: $ProductId)" -ForegroundColor Yellow
        Add-Result -App $Label -Status 'Skipped'
        return
    }

    $success = $false

    # Source 1: tplant
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

            Write-Host "[$( Get-Timestamp )]    Download tplant -> $fileName" -ForegroundColor DarkCyan
            Invoke-WebRequest -Uri $pkg.packagedownloadurl -OutFile $outPath -UseBasicParsing -ErrorAction Stop
            $script:tempFiles.Add($outPath)

            Add-AppxPackage -Path $outPath -ErrorAction Stop

            Write-Host "[$( Get-Timestamp )]    OK $Label installed (tplant)." -ForegroundColor Green
            Add-Result -App $Label -Status 'Installed'
            $success = $true
        }
    } catch {
        Write-Host "[$( Get-Timestamp )]    ! tplant failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Source 2: AdGuard
    if (-not $success) {
        try {
            Write-Host "[$( Get-Timestamp )]    Falling back to AdGuard ..." -ForegroundColor Yellow
            $body     = "type=url&url=$storeUrl&ring=Retail"
            $response = Invoke-WebRequest -UseBasicParsing -Method POST `
                            -Uri 'https://store.rg-adguard.net/api/GetFiles' `
                            -Body $body -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop

            $arch  = Get-ArchTag
            $links = $response.Links |
                     Where-Object { $_ -like '*.appx*' -or $_ -like '*.appxbundle*' -or
                                    $_ -like '*.msix*'  -or $_ -like '*.msixbundle*' } |
                     Where-Object { $_ -like '*_neutral_*' -or $_ -like "*_${arch}_*" }

            foreach ($link in $links) {
                try {
                    $match = [regex]::Match($link, '(?<=a href=").+(?=" r)')
                    if (-not $match.Success) { continue }
                    $url = $match.Value

                    $req      = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
                    $fileName = ""
                    if ($req.Headers['Content-Disposition']) {
                        $fnMatch = [regex]::Match($req.Headers['Content-Disposition'], '(?<=filename=).+')
                        if ($fnMatch.Success) { $fileName = $fnMatch.Value.Trim('"') }
                    }
                    if (-not $fileName) { $fileName = Split-Path $url -Leaf }

                    $outPath = Resolve-UniqueFilePath (Join-Path $env:TEMP $fileName)
                    Write-Host "[$( Get-Timestamp )]    Download AdGuard -> $fileName" -ForegroundColor DarkCyan
                    [System.IO.File]::WriteAllBytes($outPath, $req.Content)
                    $script:tempFiles.Add($outPath)

                    Add-AppxPackage -Path $outPath -ErrorAction Stop

                    Write-Host "[$( Get-Timestamp )]    OK $Label installed (AdGuard)." -ForegroundColor Green
                    Add-Result -App $Label -Status 'Installed'
                    $success = $true
                    break
                } catch {
                    Write-Host "[$( Get-Timestamp )]    ! Package failed, trying next ..." -ForegroundColor Yellow
                }
            }
        } catch {
            Write-Host "[$( Get-Timestamp )]    ERROR AdGuard also failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if (-not $success) { Add-Result -App $Label -Status 'Failed' }
}

function Invoke-IdeCli {
    param( [string]$Cli, [string[]]$Arguments )

    $cmdShimInfo = Get-Command "$Cli.cmd" -ErrorAction SilentlyContinue
    $cmdShim     = if ($cmdShimInfo) { $cmdShimInfo.Source } else { $null }
    if ($cmdShim) {
        $proc = Start-Process -FilePath 'cmd.exe' `
                    -ArgumentList (@('/c', "`"$cmdShim`"") + $Arguments) `
                    -WindowStyle Hidden -PassThru -Wait -ErrorAction Stop
        return $proc.ExitCode
    }

    $exeInfo = Get-Command $Cli -ErrorAction SilentlyContinue
    $exePath = if ($exeInfo) { $exeInfo.Source } else { $null }
    if (-not $exePath) { return 1 }

    $proc = Start-Process -FilePath $exePath `
                -ArgumentList $Arguments `
                -WindowStyle Hidden -PassThru -Wait -ErrorAction Stop
    return $proc.ExitCode
}

function Get-VsixPath {
    <#
    .SYNOPSIS
        Downloads a VSIX from the Marketplace if not already cached this session.
        Returns the local path on success, $null on failure.
        Uses $script:vsixCache (hashtable ExtId -> path) to avoid re-downloading.
    #>
    param([string]$ExtId)

    if (-not $script:vsixCache) { $script:vsixCache = @{} }

    # Return cached path if already downloaded
    if ($script:vsixCache.ContainsKey($ExtId)) {
        return $script:vsixCache[$ExtId]
    }

    try {
        $parts     = $ExtId -split '\.'
        $publisher = $parts[0]
        $extName   = $parts[1..($parts.Count - 1)] -join '.'

        # Query Marketplace API for latest version
        $apiUrl  = 'https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery'
        $body    = @{
            filters = @(@{ criteria = @(@{ filterType = 7; value = $ExtId }) })
            flags   = 914
        } | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $apiUrl -Method POST -Body $body `
            -ContentType 'application/json' `
            -Headers @{ 'Accept' = 'application/json;api-version=7.1-preview.1' } `
            -ErrorAction Stop

        $version = $response.results[0].extensions[0].versions[0].version
        if (-not $version) {
            Write-Host "[$( Get-Timestamp )]       ! Could not resolve version for $ExtId" -ForegroundColor Yellow
            return $null
        }

        $vsixUrl  = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/$publisher/vsextensions/$extName/$version/vspackage"
        $vsixPath = Resolve-UniqueFilePath (Join-Path $env:TEMP "$publisher.$extName-$version.vsix")

        Write-Host "[$( Get-Timestamp )]       Downloading $ExtId v$version ..." -ForegroundColor DarkCyan
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $vsixUrl -OutFile $vsixPath -UseBasicParsing -ErrorAction Stop

        $script:tempFiles.Add($vsixPath)
        $script:vsixCache[$ExtId] = $vsixPath
        return $vsixPath

    } catch {
        Write-Host "[$( Get-Timestamp )]       ! VSIX download failed for $ExtId`: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Install-VSExtensions {
    param(
        [string[]]$EnabledExtensions,
        [string[]]$DisabledExtensions = @()
    )

    $ides = @(
        @{ Name = 'VS Code';     Cli = 'code'        },
        @{ Name = 'Antigravity'; Cli = 'antigravity'  }
    )

    # Build unified extension list with disable flag
    $allExtensions = @()
    $EnabledExtensions  | ForEach-Object { $allExtensions += [PSCustomObject]@{ Id = $_; Disable = $false } }
    $DisabledExtensions | ForEach-Object { $allExtensions += [PSCustomObject]@{ Id = $_; Disable = $true  } }

    # Reset VSIX cache for this run
    $script:vsixCache = @{}

    # ── Phase 1: Download all VSIXs up front (once each) ──────────────────────
    if (-not $DryRun) {
        Write-Host ""
        Write-Host "[$( Get-Timestamp )] # Downloading VSIXs ..." -ForegroundColor Cyan

        foreach ($ext in $allExtensions) {
            $null = Get-VsixPath -ExtId $ext.Id
        }

        Write-Host "[$( Get-Timestamp )]    OK VSIX downloads complete ($($script:vsixCache.Count)/$($allExtensions.Count) succeeded)." -ForegroundColor Green
    }

    # ── Phase 2: Install into each IDE ────────────────────────────────────────
    foreach ($ide in $ides) {
        $cli     = $ide.Cli
        $ideName = $ide.Name

        if (-not (Get-Command $cli -ErrorAction SilentlyContinue) -and
            -not (Get-Command "$cli.cmd" -ErrorAction SilentlyContinue)) {
            Write-Host "[$( Get-Timestamp )]    ! $ideName CLI not found — skipping." -ForegroundColor Yellow
            continue
        }

        Write-Host ""
        Write-Host "[$( Get-Timestamp )] # Installing extensions into $ideName ..." -ForegroundColor Cyan

        # Build installed-extension list for this IDE
        $installedList = @()
        if (-not $DryRun) {
            $tmpOut = [System.IO.Path]::GetTempFileName()
            $script:tempFiles.Add($tmpOut)

            $cmdShimInfo = Get-Command "$cli.cmd" -ErrorAction SilentlyContinue
            $cmdShim     = if ($cmdShimInfo) { $cmdShimInfo.Source } else { $null }
            if ($cmdShim) {
                Start-Process -FilePath 'cmd.exe' `
                    -ArgumentList "/c `"$cmdShim`" --list-extensions > `"$tmpOut`" 2>&1" `
                    -WindowStyle Hidden -Wait
            } else {
                $exeInfo = Get-Command $cli -ErrorAction SilentlyContinue
                Start-Process -FilePath $exeInfo.Source `
                    -ArgumentList '--list-extensions' `
                    -RedirectStandardOutput $tmpOut -WindowStyle Hidden -Wait
            }
            Get-Content $tmpOut -ErrorAction SilentlyContinue |
                Where-Object { $_ -match '\.' } |
                ForEach-Object { $installedList += $_.Trim().ToLower() }
        }

        foreach ($ext in $allExtensions) {
            $extId = $ext.Id

            if ($DryRun) {
                Write-Host "[$( Get-Timestamp )]    ~ [DryRun] Would install $extId into $ideName" -ForegroundColor Yellow
                Add-Result -App "$ideName : $extId" -Status 'Skipped'
                continue
            }

            # Skip if already installed in this IDE
            if ($installedList -contains $extId.ToLower()) {
                Write-Host "[$( Get-Timestamp )]    - $extId already in $ideName." -ForegroundColor DarkGray
                Add-Result -App "$ideName : $extId" -Status 'Skipped'

                # Still apply disable flag even if already installed
                if ($ext.Disable) {
                    $null = Invoke-IdeCli -Cli $cli -Arguments @('--disable-extension', $extId)
                }
                continue
            }

            # Get cached VSIX path (already downloaded in Phase 1)
            $vsixPath = $script:vsixCache[$extId]

            if (-not $vsixPath -or -not (Test-Path $vsixPath)) {
                Write-Host "[$( Get-Timestamp )]    X $extId — no VSIX available, skipping $ideName." -ForegroundColor Red
                Add-Result -App "$ideName : $extId" -Status 'Failed'
                continue
            }

            # Install from VSIX
            $ec = Invoke-IdeCli -Cli $cli -Arguments @('--install-extension', $vsixPath)

            if ($ec -eq 0) {
                Write-Host "[$( Get-Timestamp )]    OK $extId -> $ideName" -ForegroundColor Green
                Add-Result -App "$ideName : $extId" -Status 'Installed'
            } else {
                Write-Host "[$( Get-Timestamp )]    ERROR $extId failed in $ideName (exit $ec)" -ForegroundColor Red
                Add-Result -App "$ideName : $extId" -Status 'Failed'
            }

            if ($ext.Disable) {
                $null = Invoke-IdeCli -Cli $cli -Arguments @('--disable-extension', $extId)
            }
        }
    }
}

function Install-ExtensionViaVsix {
    # Kept for backwards compatibility — internally delegates to Get-VsixPath
    param( [string]$Cli, [string]$ExtId, [string]$IdeName )
    $vsixPath = Get-VsixPath -ExtId $ExtId
    if (-not $vsixPath) { return 1 }
    return (Invoke-IdeCli -Cli $Cli -Arguments @('--install-extension', $vsixPath))
}

function Set-RegistryValue {
    param( [string]$Path, [string]$Name, $Value, [string]$Type = 'DWORD' )
    if ($DryRun) {
        Write-Host "[$( Get-Timestamp )]    ? [DRY-RUN] Would set registry: $Name = $Value ($Path)" -ForegroundColor Yellow
        return
    }
    try {
        if (-not (Test-Path $Path)) { $null = New-Item -Path $Path -Force }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        Write-Host "[$( Get-Timestamp )]    OK $Name = $Value" -ForegroundColor DarkGreen
    } catch {
        Write-Host "[$( Get-Timestamp )]    ! Could not set [$Name]: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Remove-AppxIfPresent {
    param( [string]$PackageName, [string]$Label )
    if ($DryRun) {
        Write-Host "[$( Get-Timestamp )]    ? [DRY-RUN] Would remove: ${Label}" -ForegroundColor Yellow
        return
    }
    try {
        $pkg  = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
        $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $PackageName }
        if ($pkg)  { $null = $pkg  | Remove-AppxPackage -ErrorAction SilentlyContinue }
        if ($prov) { $null = $prov | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue }
        if ($pkg -or $prov) {
            Write-Host "[$( Get-Timestamp )]    OK Removed $Label" -ForegroundColor Green
            Add-Result -App "Removed: $Label" -Status 'Installed'
        } else {
            Write-Host "[$( Get-Timestamp )]    - $Label not found." -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "[$( Get-Timestamp )]    ERROR Failed to remove ${Label}: $($_.Exception.Message)" -ForegroundColor Red
        Add-Result -App "Removed: $Label" -Status 'Failed'
    }
}