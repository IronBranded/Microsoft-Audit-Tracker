<#
    .SYNOPSIS
    MAT_UI_Engine.ps1 - v1.2
    .DESCRIPTION
    UI engine: header rendering and main menu loop.
    Fix: [string]::IsNullOrWhiteSpace guard on all state fields before calling
    .Length or .Substring — prevents NullReferenceException in PS5.1 when state
    is momentarily null during a connection attempt or on first startup.
#>

function Show-MATHeader {
    Clear-Host

    $status = $script:MAT_Global.Status
    $sColor = switch ($status) {
        "Connected"    { "Green"  }
        "Partial"      { "Yellow" }
        "Disconnected" { "Red"    }
        default        { "Yellow" }
    }

    # Null-safe reads: [string]::IsNullOrWhiteSpace prevents .Length crash in PS5.1
    $rawTenant = if ([string]::IsNullOrWhiteSpace($script:MAT_Global.TenantName)) {
        "DISCONNECTED"
    } else { $script:MAT_Global.TenantName }

    $tenant = if ($rawTenant.Length -gt 35) { $rawTenant.Substring(0,32) + "..." } else { $rawTenant }

    $role  = if ([string]::IsNullOrWhiteSpace($script:MAT_Global.UserRole))    { "Not Authenticated" } else { $script:MAT_Global.UserRole }
    $azure = if ([string]::IsNullOrWhiteSpace($script:MAT_Global.AzureStatus)) { "Not Checked"       } else { $script:MAT_Global.AzureStatus }
    $user  = $script:MAT_Global.UserPrincipal

    $displayUser = if ([string]::IsNullOrWhiteSpace($user)) {
        "None"
    } elseif ($user.Length -gt 55) {
        $user.Substring(0,52) + "..."
    } else { $user }

    # Tenant name color: bright when connected, dimmed when not
    $tenantColor = if ($status -eq "Connected") { "White" } else { "DarkGray" }

    $time = Get-Date -Format "HH:mm:ss"
    $w    = 74

    Write-Host ("╔" + ("═" * $w) + "╗") -ForegroundColor Blue
    Write-Host "║   Microsoft Audit Tracker - Cloud Response & Auditing Utility           ║" -ForegroundColor Blue
    Write-Host ("╠" + ("═" * $w) + "╣") -ForegroundColor Blue

    Write-Host "║ " -NoNewline -ForegroundColor Blue
    Write-Host "  TENANT : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-35}" -f $tenant) -NoNewline -ForegroundColor $tenantColor
    Write-Host "  STATUS : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-12}" -f $status) -NoNewline -ForegroundColor $sColor
    Write-Host "   ║" -ForegroundColor Blue

    Write-Host "║ " -NoNewline -ForegroundColor Blue
    Write-Host "  USER   : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-60}" -f $displayUser) -NoNewline -ForegroundColor White
    Write-Host "   ║" -ForegroundColor Blue

    Write-Host "║ " -NoNewline -ForegroundColor Blue
    Write-Host "  M365   : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-35}" -f $role) -NoNewline -ForegroundColor Yellow
    Write-Host "  MODE   : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-12}" -f "DASHBOARD") -NoNewline -ForegroundColor White
    Write-Host "   ║" -ForegroundColor Blue

    Write-Host "║ " -NoNewline -ForegroundColor Blue
    Write-Host "  AZURE  : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-35}" -f $azure) -NoNewline -ForegroundColor Cyan
    Write-Host "  TIME   : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-12}" -f $time) -NoNewline -ForegroundColor Gray
    Write-Host "   ║" -ForegroundColor Blue

    Write-Host ("╚" + ("═" * $w) + "╝") -ForegroundColor Blue
}


function Show-MATMenu {
    while ($true) {
        Show-MATHeader

        Write-Host "`n    ----------- OPERATIONS -----------"
        Write-Host "    [1] Auditor Mode    (Forensic Readiness + Copilot Telemetry)" -ForegroundColor Cyan
        Write-Host "    [2] Protector Mode  (Identity Posture + Copilot Governance)" -ForegroundColor Cyan
        Write-Host "    [3] Licensor Mode   (Defensive Stack + Copilot License)" -ForegroundColor Cyan
        Write-Host "    [4] Super Auditor   (Run 1+2+3, HTML report with Copilot section)" -ForegroundColor Yellow
        Write-Host "    [5] Activator Mode  (Remediation: Enable UAL)" -ForegroundColor Red
        Write-Host "`n    ----------- SESSIONS -----------"
        Write-Host "    [C] Connect / Switch Tenant" -ForegroundColor White
        Write-Host "    [D] Diagnostic Check" -ForegroundColor White
        Write-Host "    [Q] Quit" -ForegroundColor White

        $choice = Read-Host "`nMAT: Select Option"

        switch ($choice.ToUpper()) {
            "1" { Invoke-AuditorMode }
            "2" { Invoke-ProtectorMode }
            "3" { Invoke-LicensorMode }
            "4" { Invoke-SuperAuditor }
            "5" { Invoke-ActivatorMode }
            "C" { Connect-MAT }
            "D" { Invoke-Diagnostic }
            "Q" {
                Write-Host "`n[*] Disconnecting sessions..." -ForegroundColor Yellow
                Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
                Disconnect-MgGraph -ErrorAction SilentlyContinue
                if (Get-Module -Name Az.Accounts -ErrorAction SilentlyContinue) {
                    Disconnect-AzAccount -Confirm:$false -ErrorAction SilentlyContinue
                }
                Write-Host "[+] Goodbye!" -ForegroundColor Green
                exit
            }
            default {
                Write-Host "[!] Invalid selection — choose a listed option." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    }
}
