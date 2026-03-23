# ================================================================================
#  Microsoft Audit Tracker (MAT) - Entry Point
#  Version: 1.2
#  Description: Cloud Response & Auditing Utility for Microsoft 365 / Azure
#
#  v1.2 changes:
#    - Copilot AI audit integrated into Auditor, Protector, and Licensor modes
#    - Graph scopes corrected (Policy.Read.All, Reports.Read.All added)
#    - Activator now accepts Compliance Administrator as well as Global Admin
#    - SKU cache added to state; Diagnostic fully rewritten
#    - HTML report: collapsible sections, row-level severity, key findings panel,
#      sticky nav, zebra striping, healthy count, dynamic Copilot colspan
#    - All module paths corrected to flat layout matching actual file structure
# ================================================================================

$ErrorActionPreference = "Stop"
Clear-Host

Write-Host "════════════════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host "  Microsoft Audit Tracker (MAT) v1.2 - Initializing..." -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════════════════" -ForegroundColor Blue

# $PSScriptRoot is empty when script content is pasted directly into a console session.
# Fall back to the invocation path so module resolution always works.
$scriptPath = if ($PSScriptRoot) {
    $PSScriptRoot
} else {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}

# ================================================================================
# HELPER: Graceful exit with full session cleanup
# ================================================================================
function Exit-MAT {
    param([int]$Code = 0)
    Write-Host "`n[*] Cleaning up sessions before exit..." -ForegroundColor Yellow
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Disconnect-MgGraph -ErrorAction SilentlyContinue
    if (Get-Module -Name Az.Accounts -ErrorAction SilentlyContinue) {
        Disconnect-AzAccount -Confirm:$false -ErrorAction SilentlyContinue
    }
    Write-Host "[+] Sessions cleared." -ForegroundColor Green
    Pause
    exit $Code
}

# ================================================================================
# 1. MODULE LOADING — flat layout, dependency order
#    Load order matters: State → Logging → Paths → Connection → LicenseMap → UI
#    → Operations.  Core modules are marked; a failure in any Core module aborts.
# ================================================================================
Write-Host "[*] Loading MAT modules..." -ForegroundColor Yellow

$coreModules = @(
    "MAT_State.ps1",
    "MAT_Logging.ps1",
    "MAT_Paths.ps1",
    "MAT_Connection.ps1"
)

$otherModules = @(
    "LicenseMap.ps1",
    "MAT_UI_Engine.ps1",
    "Diagnostic.ps1",
    "Auditor.ps1",
    "Protector.ps1",
    "Licensor.ps1",
    "Activator.ps1",
    "SuperAuditor.ps1"
)

$allModules    = $coreModules + $otherModules
$loadedCount   = 0
$failedModules = @()

foreach ($module in $allModules) {
    $modulePath = Join-Path $scriptPath $module

    if (Test-Path $modulePath) {
        try {
            # Save/restore $ErrorActionPreference so a module that sets it to SilentlyContinue
            # does not silently suppress errors in subsequent modules.
            $prevEAP = $ErrorActionPreference
            . $modulePath
            $ErrorActionPreference = $prevEAP
            $loadedCount++
            Write-Host "  [✓] $module" -ForegroundColor Green
        } catch {
            $ErrorActionPreference = $prevEAP
            $failedModules += $module
            Write-Host "  [✗] FAILED: $module — $_" -ForegroundColor Red
        }
    } else {
        $failedModules += $module
        Write-Host "  [!] NOT FOUND: $module" -ForegroundColor Red
    }
}

Write-Host "`n[+] Loaded $loadedCount / $($allModules.Count) modules" -ForegroundColor Green

if ($failedModules.Count -gt 0) {
    Write-Host "[!] Failed to load $($failedModules.Count) module(s):" -ForegroundColor Red
    $failedModules | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }

    $coreFailures = $failedModules | Where-Object { $_ -in $coreModules }
    if ($coreFailures.Count -gt 0) {
        Write-Host "`n[!] CRITICAL: Core module(s) failed — MAT cannot continue." -ForegroundColor Red
        Exit-MAT -Code 1
    }
}

# ================================================================================
# 2. DEPENDENCY CHECK — verify PS modules are installed AND importable
# ================================================================================
Write-Host "`n[*] Checking PowerShell module dependencies..." -ForegroundColor Yellow

$dependencies = @(
    @{ Name = "Microsoft.Graph.Authentication"; Required = $true;  Note = "Core Graph connectivity" }
    @{ Name = "ExchangeOnlineManagement";       Required = $true;  Note = "v3.2+ required for Copilot record type" }
    @{ Name = "Az.Accounts";                    Required = $false; Note = "Optional: Azure RBAC detection" }
    @{ Name = "Az.Monitor";                     Required = $false; Note = "Optional: Entra ID diagnostic settings (requires Monitoring Reader Azure role)" }
)

$allPresent = $true
foreach ($dep in $dependencies) {
    $result = $null
    try { $result = Import-Module $dep.Name -PassThru -ErrorAction Stop } catch {}

    if ($result) {
        Write-Host "  [✓] $($dep.Name) v$($result.Version)" -ForegroundColor Green
    } elseif ($dep.Required) {
        Write-Host "  [✗] $($dep.Name) — MISSING or BROKEN (REQUIRED)" -ForegroundColor Red
        $allPresent = $false
    } else {
        Write-Host "  [!] $($dep.Name) — not installed ($($dep.Note))" -ForegroundColor Yellow
    }
}

if (-not $allPresent) {
    Write-Host "`n[!] Required modules are missing. Install them:" -ForegroundColor Red
    Write-Host "    Install-Module Microsoft.Graph.Authentication -Force" -ForegroundColor White
    Write-Host "    Install-Module ExchangeOnlineManagement -Force" -ForegroundColor White
    Write-Host "`n    Optional (recommended):" -ForegroundColor Yellow
    Write-Host "    Install-Module Az.Accounts -Force" -ForegroundColor White
    Write-Host "    Install-Module Az.Monitor  -Force" -ForegroundColor White
    Exit-MAT -Code 1
}

# ================================================================================
# 3. INITIALIZE GLOBAL STATE
# ================================================================================
Write-Host "`n[*] Initializing MAT state..." -ForegroundColor Yellow

if (Get-Command Initialize-MATState -ErrorAction SilentlyContinue) {
    Initialize-MATState
    Write-Host "[✓] State initialized" -ForegroundColor Green
} else {
    Write-Host "[✗] Initialize-MATState not found — core module failed to load." -ForegroundColor Red
    Exit-MAT -Code 1
}

# ================================================================================
# 4. LAUNCH UI
# ================================================================================
Write-Host "`n[*] Launching MAT Dashboard..." -ForegroundColor Yellow
Start-Sleep -Seconds 1

if (Get-Command Show-MATMenu -ErrorAction SilentlyContinue) {
    Show-MATMenu
} else {
    Write-Host "`n[!] FATAL: Show-MATMenu not found — UI engine failed to load." -ForegroundColor Red
    Exit-MAT -Code 1
}
