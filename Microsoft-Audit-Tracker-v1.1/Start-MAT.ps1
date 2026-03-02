# ================================================================================
#  Microsoft Audit Tracker (MAT) - Entry Point
#  Version: 1.1
#  Description: Cloud Response & Auditing Utility for Microsoft 365/Azure
# ================================================================================

$ErrorActionPreference = "Stop"
Clear-Host

Write-Host "════════════════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host "  Microsoft Audit Tracker (MAT) - Initializing..." -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════════════════" -ForegroundColor Blue

# Bug Fix #1: $PSScriptRoot is empty when content is pasted into a console session.
# Fall back to the invocation path so module resolution always works.
$scriptPath = if ($PSScriptRoot) {
    $PSScriptRoot
} else {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}

# ================================================================================
# HELPER: Graceful exit with session cleanup
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
# 1. MODULE LOADING - Ordered for dependency resolution
# ================================================================================
Write-Host "[*] Loading MAT modules..." -ForegroundColor Yellow

try {
    # Core modules first (State must load before anything else)
    $coreModules = @(
        "Core\MAT_State.ps1",
        "Core\MAT_Logging.ps1",
        "Core\MAT_Paths.ps1",
        "Core\MAT_Connection.ps1"
    )
    
    # Data modules
    $dataModules = @(
        "Data\LicenseMap.ps1"
    )
    
    # UI modules
    $uiModules = @(
        "UI\MAT_UI_Engine.ps1"
    )
    
    # Operations modules
    $operationModules = @(
        "Operations\Diagnostic.ps1",
        "Operations\Auditor.ps1",
        "Operations\Protector.ps1",
        "Operations\Licensor.ps1",
        "Operations\Activator.ps1",
        "Operations\SuperAuditor.ps1"
    )
    
    # Combine all modules in order
    $allModules = $coreModules + $dataModules + $uiModules + $operationModules
    
    $loadedCount  = 0
    $failedModules = @()

    foreach ($module in $allModules) {
        $modulePath = Join-Path $scriptPath $module

        if (Test-Path $modulePath) {
            try {
                # Bug Fix #2: Modules that dot-source can change $ErrorActionPreference in
                # this scope and silently affect all subsequent modules. Save and restore it
                # around each load. Note: we must NOT use & { . $path } (child scope) here —
                # that would prevent functions from being defined in the calling scope.
                $prevEAP = $ErrorActionPreference
                . $modulePath
                $ErrorActionPreference = $prevEAP
                $loadedCount++
                Write-Host "  [✓] Loaded: $module" -ForegroundColor Green
            } catch {
                $ErrorActionPreference = $prevEAP
                $failedModules += $module
                Write-Host "  [✗] Failed: $module - $_" -ForegroundColor Red
            }
        } else {
            # Bug Fix #4: Missing files must be counted as failures, not silent warnings.
            $failedModules += $module
            Write-Host "  [!] Not found: $module" -ForegroundColor Red
        }
    }

    Write-Host "`n[+] Loaded $loadedCount modules successfully" -ForegroundColor Green

    if ($failedModules.Count -gt 0) {
        Write-Host "[!] Failed to load $($failedModules.Count) module(s):" -ForegroundColor Red
        foreach ($failed in $failedModules) {
            Write-Host "    - $failed" -ForegroundColor Red
        }

        # Bug Fix #3: Any failed core module means critical functions are missing — abort now
        # rather than producing a confusing error deep inside a menu operation.
        $coreFailures = $failedModules | Where-Object { $_ -like "Core\*" }
        if ($coreFailures.Count -gt 0) {
            Write-Host "`n[!] CRITICAL: Core module(s) failed to load. MAT cannot continue." -ForegroundColor Red
            Exit-MAT -Code 1
        }
    }

} catch {
    Write-Host "`n[!] CRITICAL: Module loading error: $_" -ForegroundColor Red
    Write-Host "[!] MAT cannot continue. Please check file structure." -ForegroundColor Red
    Exit-MAT -Code 1
}

# ================================================================================
# 2. DEPENDENCY CHECK - Verify PowerShell modules are installed and importable
# ================================================================================
Write-Host "`n[*] Checking PowerShell module dependencies..." -ForegroundColor Yellow

$dependencies = @(
    @{Name="Microsoft.Graph.Authentication"; Required=$true;  Note="Core Graph connectivity"},
    @{Name="ExchangeOnlineManagement";       Required=$true;  Note="Exchange audit functions"},
    @{Name="Az.Accounts";                    Required=$false; Note="Optional: Azure RBAC detection"},
    # Bug Fix #7: Az.Monitor is needed for Entra ID diagnostic checks in Auditor mode.
    # Declared here so users are informed before they encounter a silent failure.
    @{Name="Az.Monitor";                     Required=$false; Note="Optional: Entra ID diagnostic auditing"}
)

$allPresent = $true

foreach ($dep in $dependencies) {
    $modName  = $dep.Name
    $isRequired = $dep.Required

    # Bug Fix #5: ListAvailable only checks the module exists on disk — it does NOT
    # confirm it can actually be imported (version conflicts, corrupt installs, etc.).
    # Use a real import attempt so we catch broken installations early.
    $importResult = $null
    try {
        $importResult = Import-Module $modName -PassThru -ErrorAction Stop
    } catch {
        $importResult = $null
    }

    if ($importResult) {
        $version = $importResult.Version
        Write-Host "  [✓] $modName v$version - OK" -ForegroundColor Green
    } else {
        if ($isRequired) {
            Write-Host "  [✗] $modName - MISSING or BROKEN (REQUIRED)" -ForegroundColor Red
            $allPresent = $false
        } else {
            Write-Host "  [!] $modName - Not installed ($($dep.Note))" -ForegroundColor Yellow
        }
    }
}

if (-not $allPresent) {
    Write-Host "`n[!] CRITICAL: Required modules are missing!" -ForegroundColor Red
    Write-Host "[!] Install missing modules using:" -ForegroundColor Yellow
    Write-Host "    Install-Module Microsoft.Graph.Authentication -Force" -ForegroundColor White
    Write-Host "    Install-Module ExchangeOnlineManagement -Force" -ForegroundColor White
    Write-Host "`n[!] Optional (recommended for full functionality):" -ForegroundColor Yellow
    Write-Host "    Install-Module Az.Accounts -Force" -ForegroundColor White
    Write-Host "    Install-Module Az.Monitor  -Force   # Entra ID diagnostic auditing" -ForegroundColor White
    Exit-MAT -Code 1
}

# ================================================================================
# 3. INITIALIZE GLOBAL STATE
# ================================================================================
Write-Host "`n[*] Initializing MAT global state..." -ForegroundColor Yellow

if (Get-Command Initialize-MATState -ErrorAction SilentlyContinue) {
    Initialize-MATState
    Write-Host "[✓] State initialized successfully" -ForegroundColor Green
} else {
    Write-Host "[✗] Failed to initialize state - Initialize-MATState not found" -ForegroundColor Red
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
    Write-Host "`n[!] FATAL ERROR: UI Engine (Show-MATMenu) failed to load." -ForegroundColor Red
    Write-Host "[!] Cannot start MAT. Please verify file structure." -ForegroundColor Red
    Exit-MAT -Code 1
}
