# ================================================================================
#  Microsoft Audit Tracker (MAT) - Entry Point
#  Version: 1.0 (Enhanced)
#  Description: Cloud Response & Auditing Utility for Microsoft 365/Azure
# ================================================================================

$ErrorActionPreference = "Stop"
Clear-Host

Write-Host "════════════════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host "  Microsoft Audit Tracker (MAT) - Initializing..." -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════════════════" -ForegroundColor Blue

$scriptPath = $PSScriptRoot

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
    
    $loadedCount = 0
    $failedModules = @()
    
    foreach ($module in $allModules) {
        $modulePath = Join-Path $scriptPath $module
        
        if (Test-Path $modulePath) {
            try {
                . $modulePath
                $loadedCount++
                Write-Host "  [✓] Loaded: $module" -ForegroundColor Green
            } catch {
                $failedModules += $module
                Write-Host "  [✗] Failed: $module - $_" -ForegroundColor Red
            }
        } else {
            Write-Host "  [!] Not found: $module" -ForegroundColor Yellow
        }
    }
    
    Write-Host "`n[+] Loaded $loadedCount modules successfully" -ForegroundColor Green
    
    if ($failedModules.Count -gt 0) {
        Write-Host "[!] Failed to load $($failedModules.Count) modules" -ForegroundColor Yellow
        foreach ($failed in $failedModules) {
            Write-Host "    - $failed" -ForegroundColor Yellow
        }
    }
    
} catch {
    Write-Host "`n[!] CRITICAL: Module loading error: $_" -ForegroundColor Red
    Write-Host "[!] MAT cannot continue. Please check file structure." -ForegroundColor Red
    Pause
    Exit
}

# ================================================================================
# 2. DEPENDENCY CHECK - Verify PowerShell modules are installed
# ================================================================================
Write-Host "`n[*] Checking PowerShell module dependencies..." -ForegroundColor Yellow

$dependencies = @(
    @{Name="Microsoft.Graph.Authentication"; Required=$true},
    @{Name="ExchangeOnlineManagement"; Required=$true},
    @{Name="Az.Accounts"; Required=$false}
)

$allPresent = $true

foreach ($dep in $dependencies) {
    $modName = $dep.Name
    $isRequired = $dep.Required
    
    if (Get-Module -ListAvailable -Name $modName) {
        Write-Host "  [✓] $modName - Installed" -ForegroundColor Green
    } else {
        if ($isRequired) {
            Write-Host "  [✗] $modName - MISSING (REQUIRED)" -ForegroundColor Red
            $allPresent = $false
        } else {
            Write-Host "  [!] $modName - Not installed (Optional)" -ForegroundColor Yellow
        }
    }
}

if (-not $allPresent) {
    Write-Host "`n[!] CRITICAL: Required modules are missing!" -ForegroundColor Red
    Write-Host "[!] Install missing modules using:" -ForegroundColor Yellow
    Write-Host "    Install-Module Microsoft.Graph.Authentication -Force" -ForegroundColor White
    Write-Host "    Install-Module ExchangeOnlineManagement -Force" -ForegroundColor White
    Write-Host "`n[!] Optional (for Azure auditing):" -ForegroundColor Yellow
    Write-Host "    Install-Module Az.Accounts -Force" -ForegroundColor White
    Pause
    Exit
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
    Pause
    Exit
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
    Pause
    Exit
}
