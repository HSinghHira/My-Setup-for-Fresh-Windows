# Privacy.ps1 - Section 13 logic
# Dot-sourced into index.ps1

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  EU Privacy Unlock" -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

if ($SkipEUPrivacy) {
    Write-Host "[$( Get-Timestamp )] - Skipping EU privacy unlock (flag set)." -ForegroundColor DarkGray
} else {
    # MinSudo.exe lives alongside this script in scripts/sections/
    $minSudoExe = Join-Path $PSScriptRoot "MinSudo.exe"

    if (-not (Test-Path $minSudoExe)) {
        Write-Host "[$( Get-Timestamp )] X MinSudo.exe not found at: $minSudoExe" -ForegroundColor Red
        Write-Host "[$( Get-Timestamp )]   Ensure MinSudo.exe is present in scripts\sections\ and re-run." -ForegroundColor Yellow
        Add-Result -App 'EU Privacy Unlock' -Status 'Failed'
    } elseif ($DryRun) {
        Write-Host "[$( Get-Timestamp )] ~ [DryRun] Would run EU Privacy Unlock via bundled MinSudo.exe." -ForegroundColor Yellow
        Write-Host "[$( Get-Timestamp )] ~ [DryRun] Steps: set region to Ireland (EU), delete DeviceRegion values" -ForegroundColor Yellow
        Write-Host "[$( Get-Timestamp )] ~ [DryRun]        via TrustedInstaller, restore original region." -ForegroundColor Yellow
        Write-Host "[$( Get-Timestamp )] ~ [DryRun] MinSudo path: $minSudoExe" -ForegroundColor Yellow
    } else {
        $origGeo    = (Get-WinHomeLocation).GeoId
        $scriptTemp = "$env:TEMP\delete_deviceregion_$([System.IO.Path]::GetRandomFileName().Replace('.','') ).ps1"

        # ------------------------------------------------------------------
        # Step 1 — Temporarily set region to EU (Ireland) so Windows
        #          registers the upcoming DeviceRegion change correctly
        # ------------------------------------------------------------------
        Write-Host "[$( Get-Timestamp )] [1/3] Setting region to Ireland (EU) ..." -ForegroundColor DarkCyan
        try {
            Set-WinHomeLocation -GeoId 94 -ErrorAction Stop
            Write-Host "[$( Get-Timestamp )]       OK Region set to Ireland." -ForegroundColor Green
        } catch {
            Write-Host "[$( Get-Timestamp )]       ! Could not change region: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # ------------------------------------------------------------------
        # Step 2 — Delete DeviceRegion registry values via MinSudo
        #          (runs as TrustedInstaller so it has the required access)
        # ------------------------------------------------------------------
        Write-Host "[$( Get-Timestamp )] [2/3] Deleting DeviceRegion registry values via MinSudo ..." -ForegroundColor DarkCyan

        $deleteScript = @'
$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
    "SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\DeviceRegion", $true
)
if ($key) {
    foreach ($v in $key.GetValueNames()) { try { $key.DeleteValue($v) } catch {} }
    $key.Close()
    $check = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
        "SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\DeviceRegion", $false
    )
    if ($check.GetValueNames().Count -eq 0) { exit 0 } else { exit 1 }
} else { exit 2 }
'@
        $deleteScript | Out-File -FilePath $scriptTemp -Encoding UTF8 -Force

        function Invoke-MinSudoDelete {
            param([string]$Exe, [string]$Script)
            $p = Start-Process -FilePath $Exe `
                -ArgumentList "-U:T", "-P:E", "-ShowWindowMode:Hide",
                              "powershell.exe", "-ExecutionPolicy", "Bypass",
                              "-File", "`"$Script`"" `
                -Wait -PassThru -NoNewWindow -ErrorAction Stop
            return $p.ExitCode
        }

        $deleteOk = $false
        try {
            $exitCode = Invoke-MinSudoDelete -Exe $minSudoExe -Script $scriptTemp
            switch ($exitCode) {
                0 {
                    Write-Host "[$( Get-Timestamp )]       OK DeviceRegion values deleted." -ForegroundColor Green
                    $deleteOk = $true
                }
                2 {
                    Write-Host "[$( Get-Timestamp )]       OK DeviceRegion key does not exist (already clean)." -ForegroundColor Cyan
                    $deleteOk = $true
                }
                default {
                    Write-Host "[$( Get-Timestamp )]       ! Completed with exit code $exitCode — some values may remain." -ForegroundColor Yellow
                    $deleteOk = $true  # partial; still restore region & report
                }
            }
        } catch {
            Write-Host "[$( Get-Timestamp )]       ! MinSudo execution failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "[$( Get-Timestamp )]         Retrying after 2 seconds ..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            try {
                $exitCode = Invoke-MinSudoDelete -Exe $minSudoExe -Script $scriptTemp
                if ($exitCode -in 0, 2) {
                    Write-Host "[$( Get-Timestamp )]       OK Deleted on retry (exit code: $exitCode)." -ForegroundColor Green
                    $deleteOk = $true
                } else {
                    Write-Host "[$( Get-Timestamp )]       X MinSudo retry exit code: $exitCode" -ForegroundColor Red
                }
            } catch {
                Write-Host "[$( Get-Timestamp )]       X MinSudo retry failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        # Clean up temp script
        Remove-Item -Path $scriptTemp -Force -ErrorAction SilentlyContinue

        # ------------------------------------------------------------------
        # Step 3 — Restore original region
        # ------------------------------------------------------------------
        Write-Host "[$( Get-Timestamp )] [3/3] Restoring original region (GeoID: $origGeo) ..." -ForegroundColor DarkCyan
        try {
            Set-WinHomeLocation -GeoId $origGeo -ErrorAction Stop
            Write-Host "[$( Get-Timestamp )]       OK Region restored." -ForegroundColor Green
        } catch {
            Write-Host "[$( Get-Timestamp )]       ! Could not restore region: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "[$( Get-Timestamp )]         Run manually: Set-WinHomeLocation -GeoId $origGeo" -ForegroundColor Gray
        }

        # ------------------------------------------------------------------
        # Final verification & Add-Result
        # ------------------------------------------------------------------
        $regKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\DeviceRegion"
        if (Test-Path $regKeyPath) {
            $valueCount = (
                Get-Item $regKeyPath | Get-ItemProperty |
                Select-Object -ExpandProperty PSObject |
                ForEach-Object { $_.Properties | Where-Object { $_.Name -notmatch '^PS' } }
            ).Count
            if ($valueCount -eq 0) {
                Write-Host "[$( Get-Timestamp )] OK EU Privacy Unlock complete — DeviceRegion key is empty." -ForegroundColor Green
                Add-Result -App 'EU Privacy Unlock' -Status 'Installed'
            } else {
                Write-Host "[$( Get-Timestamp )] ! EU Privacy Unlock partial — $valueCount value(s) remain in DeviceRegion." -ForegroundColor Yellow
                Add-Result -App 'EU Privacy Unlock' -Status 'Failed'
            }
        } else {
            Write-Host "[$( Get-Timestamp )] OK EU Privacy Unlock complete — DeviceRegion key removed entirely." -ForegroundColor Green
            Add-Result -App 'EU Privacy Unlock' -Status 'Installed'
        }

        # Open Privacy Settings so the user can confirm the new EU options
        Start-Process "ms-settings:privacy"
    }
}