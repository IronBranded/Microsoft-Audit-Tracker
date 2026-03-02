<#
    .SYNOPSIS
    MAT_UI_Engine.ps1 - v1.1
    .DESCRIPTION
    UI engine: header rendering and main menu loop.
    Bug Fix #1: Duplicate Invoke-LicensorMode, Invoke-SuperAuditor, and
    New-SuperAuditorHTMLReport have been removed. Those functions now live
    exclusively in their respective Operations modules (Licensor.ps1,
    SuperAuditor.ps1) which load after this file and win the name collision.
    Keeping dead copies here caused confusion and a split-brain maintenance risk.
#>
<#
    .SYNOPSIS
    MAT_UI_Engine.ps1 - Enhanced Clean Design
    .DESCRIPTION
    Professional UI engine with streamlined header and comprehensive functionality
#>

function Show-MATHeader {
    <#
    .SYNOPSIS
    Displays the MAT dashboard header with current connection information
    
    .DESCRIPTION
    Dynamically renders tenant name, connection status, user roles, and timestamp.
    All information is pulled from the global state object which is updated on each connection.
    #>
    
    Clear-Host
    
    # Data Mapping from Global State (Dynamic - Updates on each connection)
    $status = $script:MAT_Global.Status
    $sColor = switch ($status) { 
        "Connected"    { "Green" } 
        "Partial"      { "Yellow" }
        "Disconnected" { "Red" }
        default        { "Yellow" } 
    }
    
    # Truncate long Tenant names for UI alignment while preserving full data
    $rawTenant = $script:MAT_Global.TenantName
    $tenant = if ($rawTenant.Length -gt 35) { 
        $rawTenant.Substring(0,32) + "..." 
    } else { 
        $rawTenant 
    }
    
    # Get current roles and user info (dynamic per connection)
    $role   = $script:MAT_Global.UserRole
    $azure  = $script:MAT_Global.AzureStatus
    $user   = $script:MAT_Global.UserPrincipal

    # Bug Fix #8: If UserPrincipal is $null, calling .Length throws a NullReferenceException
    # and crashes the menu loop. Guard against null before accessing string members.
    $displayUser = if (-not [string]::IsNullOrWhiteSpace($user) -and $user.Length -gt 35) {
        $user.Substring(0, 32) + "..."
    } else {
        if ([string]::IsNullOrWhiteSpace($user)) { "None" } else { $user }
    }
    
    $time   = Get-Date -Format "HH:mm:ss"

    # UI Rendering
    $w = 74
    Write-Host ("╔" + ("═" * $w) + "╗") -ForegroundColor Blue
    Write-Host "║   Microsoft Audit Tracker - Cloud Response & Auditing Utility           ║" -ForegroundColor Blue
    Write-Host ("╠" + ("═" * $w) + "╣") -ForegroundColor Blue
    
    # Row 1: Tenant and Status
    Write-Host "║ " -NoNewline -ForegroundColor Blue
    Write-Host "  TENANT : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-35}" -f $tenant) -NoNewline -ForegroundColor White
    Write-Host "  STATUS : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-12}" -f $status) -NoNewline -ForegroundColor $sColor
    Write-Host "   ║" -ForegroundColor Blue

    # Row 2: User Principal
    Write-Host "║ " -NoNewline -ForegroundColor Blue
    Write-Host "  USER   : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-60}" -f $displayUser) -NoNewline -ForegroundColor White
    Write-Host "   ║" -ForegroundColor Blue

    # Row 3: M365 Role and Mode
    Write-Host "║ " -NoNewline -ForegroundColor Blue
    Write-Host "  M365   : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-35}" -f $role) -NoNewline -ForegroundColor Yellow
    Write-Host "  MODE   : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-12}" -f "DASHBOARD") -NoNewline -ForegroundColor White
    Write-Host "   ║" -ForegroundColor Blue

    # Row 4: Azure Role and Time
    Write-Host "║ " -NoNewline -ForegroundColor Blue
    Write-Host "  AZURE  : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-35}" -f $azure) -NoNewline -ForegroundColor Cyan
    Write-Host "  TIME   : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-12}" -f $time) -NoNewline -ForegroundColor Gray
    Write-Host "   ║" -ForegroundColor Blue

    Write-Host ("╚" + ("═" * $w) + "╝") -ForegroundColor Blue
}


function Show-MATMenu {
    <#
    .SYNOPSIS
    Displays the main MAT menu and handles user input
    
    .DESCRIPTION
    Main menu loop that displays options and routes to appropriate functions.
    Header is refreshed on each loop to show current connection state.
    #>
    
    while ($true) {
        # Display header with current dynamic information
        Show-MATHeader
        
        Write-Host "`n    ----------- OPERATIONS -----------"
        Write-Host "    [1] Auditor Mode    (Forensic Response Readiness Audit)" -ForegroundColor Cyan
        Write-Host "    [2] Protector Mode  (Identity & Access Posture Audit)" -ForegroundColor Cyan
        Write-Host "    [3] Licensor Mode   (Defensive Stack Inventory)" -ForegroundColor Cyan
        Write-Host "    [4] Super Auditor   (Run Operations 1-2-3)" -ForegroundColor Yellow
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
                if (Get-Module -ListAvailable -Name Az.Accounts) {
                    Disconnect-AzAccount -Confirm:$false -ErrorAction SilentlyContinue
                }
                Write-Host "[+] Goodbye!" -ForegroundColor Green
                exit 
            }
            default { 
                Write-Host "[!] Invalid Selection. Please choose a valid option." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    }
}
