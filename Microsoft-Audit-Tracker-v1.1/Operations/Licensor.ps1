<#
    .SYNOPSIS
    Licensor.ps1 - MAT V1.1
    .DESCRIPTION
    Comprehensive License & Defensive Stack Reporter.
    Improvement: Uses shared $script:LicenseSkuMap / $script:LicenseDefenderMap
    from Data/LicenseMap.ps1 instead of duplicating the data locally.
    Improvement: Accepts -Silent switch so SuperAuditor can call without Pause.
#>

function Invoke-LicensorMode {
    param(
        # Bug Fix #2 / Improvement: When called from SuperAuditor, skip the Pause
        # so the user isn't interrupted three times during a single super-audit run.
        [switch]$Silent
    )

    if (-not $script:MAT_Global.IsConnected) {
        Write-Host "`n[!] Connection Required." -ForegroundColor Red
        Write-Host "[!] Please use option [C] to connect to a tenant first." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }

    Write-Host "`n[*] Initiating Licensor Mode..." -ForegroundColor Cyan
    Write-Host "[*] Target Tenant: $($script:MAT_Global.TenantName)" -ForegroundColor White
    Write-Host "[*] Authenticated User: $($script:MAT_Global.UserPrincipal)" -ForegroundColor White
    Write-Host ""

    $reportPath = Get-MATReportPath -TenantName $script:MAT_Global.TenantName

    Write-Host "[-] Querying Microsoft Graph for License Data..." -ForegroundColor Gray
    try {
        $allSkus = Get-MgSubscribedSku -Property SkuPartNumber, SkuId, PrepaidUnits, ConsumedUnits, ServicePlans -ErrorAction Stop
        Write-Host "[✓] Retrieved $($allSkus.Count) SKUs from tenant" -ForegroundColor Green
    } catch {
        Write-Host "[!] ERROR: Failed to query licenses - $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[!] Ensure you have Organization.Read.All permissions" -ForegroundColor Yellow
        Write-MATLog -OperationName "LicensorMode" -Details "Query failed: $($_.Exception.Message)" -Status "ERROR"
        if (-not $Silent) { Pause }
        return
    }

    # Bug Fix #3 / Improvement: Reference the shared maps loaded by Data/LicenseMap.ps1.
    # Fall back to empty hashtables if the data module failed to load (graceful degradation).
    $SkuMap      = if ($script:LicenseSkuMap)      { $script:LicenseSkuMap }      else { @{} }
    $DefenderMap = if ($script:LicenseDefenderMap) { $script:LicenseDefenderMap } else { @{} }

    $RequiredSolutions = @(
        "Microsoft Sentinel",
        "Defender for Endpoint",
        "Defender for Office 365",
        "Defender for Identity",
        "Defender XDR",
        "Defender for Cloud Apps",
        "Defender for IoT"
    )

    # --- 1. DEFENSIVE STACK REPORT ---
    Write-Host "[-] Extracting Defender & Sentinel Status..." -ForegroundColor Gray
    $defensiveResults = New-Object System.Collections.Generic.List[PSObject]

    foreach ($sku in $allSkus) {
        foreach ($plan in $sku.ServicePlans) {
            $solution = $null

            foreach ($key in $DefenderMap.Keys) {
                if ($key -like "*`**") {
                    $pattern = $key -replace '\*', '.*'
                    if ($plan.ServicePlanName -match $pattern) {
                        $solution = $DefenderMap[$key]; break
                    }
                } else {
                    if ($plan.ServicePlanName -eq $key) {
                        $solution = $DefenderMap[$key]; break
                    }
                }
            }

            if ($solution) {
                $friendlySource = if ($SkuMap.ContainsKey($sku.SkuPartNumber)) {
                    $SkuMap[$sku.SkuPartNumber]
                } else {
                    $sku.SkuPartNumber
                }

                $defensiveResults.Add([PSCustomObject]@{
                    Solution   = $solution
                    Status     = if ($plan.ProvisioningStatus -eq "Success") { "Active" } else { "Inactive" }
                    ServicePlan = $plan.ServicePlanName
                    TotalSeats = $sku.PrepaidUnits.Enabled
                    Consumed   = $sku.ConsumedUnits
                    Unused     = $sku.PrepaidUnits.Enabled - $sku.ConsumedUnits
                    SourceSKU  = $friendlySource
                })
            }
        }
    }

    # Inject "Not Licensed" placeholders for missing critical solutions
    foreach ($sol in $RequiredSolutions) {
        if (-not ($defensiveResults | Where-Object { $_.Solution -eq $sol })) {
            $defensiveResults.Add([PSCustomObject]@{
                Solution = $sol; Status = "Not Licensed"; ServicePlan = "None"
                TotalSeats = 0; Consumed = 0; Unused = 0; SourceSKU = "None"
            })
        }
    }

    $defFile = Join-Path $reportPath "Defensive_Stack.csv"
    $defensiveResults | Export-Csv -Path $defFile -NoTypeInformation
    Write-Host "[✓] Defensive Stack report generated" -ForegroundColor Green

    # --- 2. LICENSE INVENTORY REPORT ---
    Write-Host "[-] Generating License Inventory..." -ForegroundColor Gray
    $licInventory = New-Object System.Collections.Generic.List[PSObject]

    foreach ($sku in $allSkus) {
        $friendlyName = if ($SkuMap.ContainsKey($sku.SkuPartNumber)) {
            $SkuMap[$sku.SkuPartNumber]
        } else {
            $sku.SkuPartNumber   # Show raw SKU if not in map
        }

        $licInventory.Add([PSCustomObject]@{
            License_Name = $friendlyName
            SKU_ID       = $sku.SkuPartNumber
            Total_Seats  = $sku.PrepaidUnits.Enabled
            Consumed     = $sku.ConsumedUnits
            Unused       = $sku.PrepaidUnits.Enabled - $sku.ConsumedUnits
            Health       = if ($sku.PrepaidUnits.Enabled -gt $sku.ConsumedUnits) { "Optimizable" } else { "Healthy" }
        })
    }

    $licFile = Join-Path $reportPath "Licenses_Inventory.csv"
    $licInventory | Export-Csv -Path $licFile -NoTypeInformation
    Write-Host "[✓] License inventory report generated" -ForegroundColor Green

    Write-MATLog -OperationName "LicensorMode" -Details "Generated Defensive_Stack ($($defensiveResults.Count) items) and Licenses_Inventory ($($licInventory.Count) items) in $reportPath"

    Write-Host "`n[✓] Licensor Mode Complete!" -ForegroundColor Green
    Write-Host "[+] Reports saved to: $reportPath" -ForegroundColor Cyan
    Write-Host "    - Defensive_Stack.csv    ($($defensiveResults.Count) items)" -ForegroundColor White
    Write-Host "    - Licenses_Inventory.csv ($($licInventory.Count) items)" -ForegroundColor White

    if (-not $Silent) { Pause }
}
