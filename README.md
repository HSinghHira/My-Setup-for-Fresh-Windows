# My Setup after Fresh Windows Installation

Windows setup scripts.

## Usage

**Full setup** — installs all apps and dev tools:

```powershell
irm https://apps.hira.im/ | iex

# Dry Run Mode
& ([scriptblock]::Create((irm https://apps.hira.im/))) -DryRun

# More Flags
& ([scriptblock]::Create((irm https://apps.hira.im/))) -DryRun -SkipStoreApps -SkipDebloat
```

**Appx installer** — downloads and installs a Microsoft Store app by URL or Product ID:

```powershell
# Interactive — prompts for a Store URL or Product ID
irm https://apps.hira.im/AppInstaller | iex

# Silent install by passing a Store URL
& ([scriptblock]::Create((irm https://apps.hira.im/AppInstaller))) -StoreUrl "https://apps.microsoft.com/detail/9WZDNCRFJ3TJ"

# Install by Product ID
& ([scriptblock]::Create((irm https://apps.hira.im/AppInstaller))) -ProductId "9WZDNCRFJ3TJ"
```

## Scripts

- `index.ps1` — main setup script. Installs runtimes, core apps, system utilities, dev tools, and Store apps via winget. Prompts for upgrades at the end.
- `Get-Appx.ps1` — standalone Store app installer. Tries `store.rg-adguard.net` first, falls back to `msft-store.tplant.com.au`.

