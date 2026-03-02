function Invoke-Diagnostic {
    Clear-Host
    Write-Host "--- MAT DIAGNOSTICS ---" -ForegroundColor Cyan
    
    # Check 1: Internet
    Write-Host "Checking Connectivity..." -NoNewline
    try {
        $ping = Invoke-WebRequest -Uri "https://graph.microsoft.com" -UseBasicParsing -TimeoutSec 5
        if ($ping.StatusCode -eq 200) { Write-Host " [OK]" -ForegroundColor Green } else { Write-Host " [WARN]" -ForegroundColor Yellow }
    } catch {
        Write-Host " [FAIL]" -ForegroundColor Red
    }

    # Check 2: Modules
    Write-Host "Checking Modules:"
    $mods = @("Microsoft.Graph.Authentication", "ExchangeOnlineManagement", "Az.Accounts")
    foreach ($m in $mods) {
        if (Get-Module -ListAvailable -Name $m) {
            Write-Host "  - $m : Installed" -ForegroundColor Green
        } else {
            Write-Host "  - $m : MISSING" -ForegroundColor Red
        }
    }

    # Check 3: Session
    Write-Host "Session Status: $($script:MAT_Global.Status)"
    Write-Host "User: $($script:MAT_Global.UserPrincipal)"
    
    Pause
}