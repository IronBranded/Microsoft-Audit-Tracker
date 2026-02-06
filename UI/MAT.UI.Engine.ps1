<#
    .SYNOPSIS
    MAT.UI.Engine.ps1 - V1.3
    .DESCRIPTION
    Validated UI engine with gray-label status headers and robust Licensor logic.
#>

function Show-MATHeader {
    Clear-Host
    
    # 1. Setup Variables
    $status = $script:MAT_Global.Status
    $sColor = switch ($status) { "Connected" {"Green"} "Partial" {"Yellow"} default {"Red"} }
    $tenant = if ($script:MAT_Global.TenantName.Length -gt 30) { $script:MAT_Global.TenantName.Substring(0,27) + "..." } else { $script:MAT_Global.TenantName }
    $role   = $script:MAT_Global.UserRole
    $azure  = $script:MAT_Global.AzureStatus
    $time   = Get-Date -Format "HH:mm:ss"

    # 2. Header Render Configuration
    $InnerWidth = 74
    $topLine = "╔" + ("═" * $InnerWidth) + "╗"
    $midLine = "╠" + ("═" * $InnerWidth) + "╣"
    $botLine = "╚" + ("═" * $InnerWidth) + "╝"

    # 3. Render Top Logo Section
    Write-Host $topLine -ForegroundColor Blue
    $logoLines = @(
        "   ███╗  ███╗ █████╗ ████████╗    Microsoft Audit Tracker",
        "   ████╗ ████║██╔══██╗╚══██╔══╝    Cloud Response & Auditing Utility",
        "   ██╔████╔██║███████║   ██║       Version 1.0",
        "   ██║╚██╔╝██║██╔══██║   ██║       Creator: M. Decayette (IronBranded)",
        "   ██║ ╚═╝ ██║██║  ██║   ██║       ""To be prepared is half the victory"""
    )

    foreach ($line in $logoLines) {
        Write-Host "║" -NoNewline -ForegroundColor Blue
        Write-Host ($line.PadRight($InnerWidth)) -NoNewline -ForegroundColor Blue
        Write-Host "║" -ForegroundColor Blue
    }
    Write-Host $midLine -ForegroundColor Blue

    # 4. Render Status Section (Gray Labels + Chained Colors)
    # Line 1: Tenant
    Write-Host "║ " -NoNewline -ForegroundColor Blue
    Write-Host "  TENANT : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-35}" -f $tenant) -NoNewline -ForegroundColor White
    Write-Host "  STATUS : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-12}" -f $status) -NoNewline -ForegroundColor $sColor
    Write-Host "   ║" -ForegroundColor Blue

    # Line 2: M365
    Write-Host "║ " -NoNewline -ForegroundColor Blue
    Write-Host "  M365   : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-35}" -f $role) -NoNewline -ForegroundColor Yellow
    Write-Host "  MODE   : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-12}" -f "DASHBOARD") -NoNewline -ForegroundColor White
    Write-Host "   ║" -ForegroundColor Blue

    # Line 3: Azure
    Write-Host "║ " -NoNewline -ForegroundColor Blue
    Write-Host "  AZURE  : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-35}" -f $azure) -NoNewline -ForegroundColor White
    Write-Host "  TIME   : " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-12}" -f $time) -NoNewline -ForegroundColor Gray
    Write-Host "   ║" -ForegroundColor Blue

    Write-Host $botLine -ForegroundColor Blue
    Write-Host ""

    # 5. Environment Health Key
    Write-Host "    ENVIRONMENT HEALTH KEY" -ForegroundColor Gray
    Write-Host "    [ " -NoNewline; Write-Host "● Connected " -ForegroundColor Green -NoNewline; Write-Host "● Partial " -ForegroundColor Yellow -NoNewline; Write-Host "● Not connected " -ForegroundColor Red -NoNewline; Write-Host "]"
    Write-Host ""
    Write-Host "    ● : Full audit capabilities enabled." -ForegroundColor Green
    Write-Host "    ● : Missing modules / Permission limited / Re-auth required" -ForegroundColor Yellow
    Write-Host "    ● : Tenant is not connected." -ForegroundColor Red
    Write-Host "    + ----------------------------------------------------------------- +" -ForegroundColor Gray
}

function Invoke-LicensorMode {
    if (-not $script:MAT_Global.IsConnected) { 
        Write-Host "[!] Connection Required. Please use [C] to connect first." -ForegroundColor Red
        Start-Sleep -Seconds 2
        return 
    }

    Write-Host "[*] Initiating Licensor Mode..." -ForegroundColor Cyan
    $reportPath = Get-MATReportPath -TenantName $script:MAT_Global.TenantName
    
    Write-Host "[-] Querying Microsoft Graph for License Data..." -ForegroundColor Gray
    $allSkus = Get-MgSubscribedSku -Property SkuPartNumber, PrepaidUnits, ConsumedUnits, ServicePlans

    # Use the Global Maps defined in LicenseMap.ps1
    # Assuming $SkuMap and $DefenderMap are available globally
    
    $defensiveStack = New-Object System.Collections.Generic.List[PSObject]
    $RequiredSolutions = @("Microsoft Sentinel", "Defender for Endpoint", "Defender for Office 365", "Defender for Identity", "Defender XDR", "Defender for Cloud Apps", "Defender for IoT")

    foreach ($sku in $allSkus) {
        foreach ($plan in $sku.ServicePlans) {
            $solution = $null
            foreach ($key in $DefenderMap.Keys) {
                if ($plan.ServicePlanName -like $key) { $solution = $DefenderMap[$key]; break }
            }

            if ($solution) {
                $friendlySource = if ($SkuMap.ContainsKey($sku.SkuPartNumber)) { $SkuMap[$sku.SkuPartNumber] } else { $sku.SkuPartNumber }
                $defensiveStack.Add([PSCustomObject]@{
                    Solution    = $solution
                    Status      = if ($plan.ProvisioningStatus -eq "Success") { "Active" } else { "Inactive" }
                    ServicePlan = $plan.ServicePlanName
                    TotalSeats  = $sku.PrepaidUnits.Enabled
                    Consumed    = $sku.ConsumedUnits
                    Unused      = $sku.PrepaidUnits.Enabled - $sku.ConsumedUnits
                    SourceSKU   = $friendlySource
                })
            }
        }
    }

    foreach ($sol in $RequiredSolutions) {
        if (-not ($defensiveStack | Where-Object { $_.Solution -eq $sol })) {
            $defensiveStack.Add([PSCustomObject]@{
                Solution = $sol; Status = "Not Licensed"; ServicePlan = "None"; TotalSeats = 0; Consumed = 0; Unused = 0; SourceSKU = "None"
            })
        }
    }

    $defFile = Join-Path $reportPath "Defensive_Stack.csv"
    $defensiveStack | Export-Csv -Path $defFile -NoTypeInformation

    Write-Host "[-] Generating Inventory for Core Suites..." -ForegroundColor Gray
    $licInventory = foreach ($sku in $allSkus) {
        if ($SkuMap.ContainsKey($sku.SkuPartNumber)) {
            [PSCustomObject]@{
                License_Name = $SkuMap[$sku.SkuPartNumber]
                Total_Seats  = $sku.PrepaidUnits.Enabled
                Consumed     = $sku.ConsumedUnits
                Unused       = $sku.PrepaidUnits.Enabled - $sku.ConsumedUnits
                Health       = if ($sku.PrepaidUnits.Enabled -gt $sku.ConsumedUnits) { "Optimizable" } else { "Healthy" }
            }
        }
    }
    
    $licFile = Join-Path $reportPath "Licenses_Inventory.csv"
    $licInventory | Export-Csv -Path $licFile -NoTypeInformation

    Write-MATLog -OperationName "LicensorMode" -Details "Generated Reports in $reportPath"
    Write-Host "[+] SUCCESS: Data exported to $reportPath" -ForegroundColor Green
    Start-Sleep -Seconds 3
}

function Show-MATMenu {
    while ($true) {
        Show-MATHeader
    Write-Host "    ----------- BASIC OPERATIONS -----------" -ForegroundColor White
    Write-Host "    [1] Auditor Mode    Logging Health: Verifies if systems are recording." -ForegroundColor Cyan
    Write-Host "    [2] Protector Mode  Posture Audit: (ServicePlans + CA + Sec Defaults)" -ForegroundColor Cyan
    Write-Host "    [3] Licensor Mode   SKU Inventory: Translates IDs to product names." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    ----------- ADVANCED OPERATIONS -----------" -ForegroundColor White
    Write-Host "    [4] Super Auditor   Full Spectrum: Automated capture of all modules." -ForegroundColor Yellow
    Write-Host "    [5] Activator Mode  Remediation: Force-Enable Unified Audit Logging." -ForegroundColor Red
    Write-Host ""
        Write-Host "    ----------- SESSION OPERATIONS -----------" -ForegroundColor White
        Write-Host "    [C] Connect to tenant" -ForegroundColor White
        Write-Host "    [D] Diagnostic" -ForegroundColor White
        Write-Host "    [Q] Quit" -ForegroundColor White
        
        $selection = Read-Host "`nMAT: Select Option"
        switch ($selection) {
            "1" { Invoke-AuditorMode }
            "2" { Invoke-ProtectorMode }
            "3" { Invoke-LicensorMode }
            "4" { Invoke-SuperAuditor }
            "5" { Invoke-ActivatorMode }
            "C" { Connect-MAT }
            "D" { Invoke-Diagnostic }
            "Q" { exit }
            default { Write-Host "[!] Invalid Selection" -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}