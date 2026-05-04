# Debloat.ps1 - Section 12 logic
# Dot-sourced into index.ps1

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Windows 11 Debloat & Configuration" -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

if ($SkipDebloat) {
    Write-Host "[$( Get-Timestamp )] - Skipping debloat (flag set)." -ForegroundColor DarkGray
} else {
    Write-Host "[$( Get-Timestamp )] # Creating system restore point ..." -ForegroundColor DarkCyan
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'Before Windows 11 Setup Script Debloat' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Host "[$( Get-Timestamp )]    OK Restore point created." -ForegroundColor Green
    } catch {
        Write-Host "[$( Get-Timestamp )]    ! Could not create restore point (non-fatal): $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # 12A - Bloat App Removal
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] # 12A - Removing bloat apps ..." -ForegroundColor Cyan
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

    # 12B - Privacy & Telemetry
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] # 12B - Privacy & Telemetry ..." -ForegroundColor Cyan
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

    # 12C - AI Features
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] # 12C - Disabling AI features ..." -ForegroundColor Cyan
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

    try {
        $svc = Get-Service -Name 'WSAIFabricSvc' -ErrorAction SilentlyContinue
        if ($svc) { Set-Service -Name 'WSAIFabricSvc' -StartupType Manual -ErrorAction SilentlyContinue }
    } catch {}

    # 12D - System Tweaks
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] # 12D - System tweaks ..." -ForegroundColor Cyan
    $ctxPath = 'HKCU:\SOFTWARE\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
    if (-not (Test-Path $ctxPath)) { $null = New-Item -Path $ctxPath -Force }
    Set-ItemProperty -Path $ctxPath -Name '(Default)' -Value '' -Type String -Force
    Set-RegistryValue -Path 'HKCU:\Control Panel\Accessibility\StickyKeys' -Name 'Flags' -Value '506' -Type String
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Name 'DODownloadMode' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'     -Name 'NoAutoRebootWithLoggedOnUsers' -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'        -Name 'DeferFeatureUpdates'            -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'        -Name 'DeferFeatureUpdatesPeriodInDays' -Value 7

    # 12E - Start Menu & Search
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] # 12E - Start Menu & Search ..." -ForegroundColor Cyan
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideRecommendedSection' -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer'               -Name 'DisableSearchBoxSuggestions' -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'           -Name 'BingSearchEnabled' -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'           -Name 'EnableDynamicContentInWSB' -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'           -Name 'CortanaConsent' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'         -Name 'DisableWebSearch' -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_AccountNotifications' -Value 0

    # 12F - Taskbar
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] # 12F - Taskbar ..." -ForegroundColor Cyan
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowTaskViewButton' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'                             -Name 'AllowWidgets' -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'            -Name 'SearchboxTaskbarMode' -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' -Name 'TaskbarEndTask' -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'LastActiveClick' -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn' -Value 0

    # 12G - File Explorer
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] # 12G - File Explorer ..." -ForegroundColor Cyan
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'LaunchTo' -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt' -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Hidden' -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowDriveLettersFirst' -Value 4
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'          -Name 'HubMode' -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' -Name 'System.IsPinnedToNameSpaceTree' -Value 0

    # 12H - OneDrive startup
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] # 12H - OneDrive startup ..." -ForegroundColor Cyan
    try {
        $runKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
        if ((Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue).OneDrive) {
            Remove-ItemProperty -Path $runKey -Name 'OneDrive' -Force -ErrorAction SilentlyContinue
        }
    } catch {}

    # 12I - Multi-tasking
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] # 12I - Multi-tasking ..." -ForegroundColor Cyan
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'SnapAssist' -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'MultiTaskingAltTabFilter' -Value 3

    # 12J - Gaming
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] # 12J - Gaming / DVR ..." -ForegroundColor Cyan
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Value 0
    Set-RegistryValue -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Value 0

    # 12K - Optional Features
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] # 12K - Optional Features ..." -ForegroundColor Cyan
    $edition = (Get-WindowsEdition -Online -ErrorAction SilentlyContinue).Edition
    if ($edition -match 'Pro|Enterprise|Education') {
        try {
            $null = Enable-WindowsOptionalFeature -Online -FeatureName 'Containers-DisposableClientVM' -All -NoRestart -ErrorAction Stop
            Add-Result -App 'Windows Sandbox' -Status 'Installed'
        } catch { Add-Result -App 'Windows Sandbox' -Status 'Failed' }
    }
    try {
        $null = Enable-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux' -All -NoRestart -ErrorAction Stop
        $null = Enable-WindowsOptionalFeature -Online -FeatureName 'VirtualMachinePlatform' -All -NoRestart -ErrorAction Stop
        Add-Result -App 'WSL2' -Status 'Installed'
    } catch { Add-Result -App 'WSL2' -Status 'Failed' }

    # 12L - Dark Mode
    Write-Host ""
    Write-Host "[$( Get-Timestamp )] # 12L - Dark Mode ..." -ForegroundColor Cyan
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme'   -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'SystemUsesLightTheme' -Value 0

    Add-Result -App 'Debloat & Configuration' -Status 'Installed'
}