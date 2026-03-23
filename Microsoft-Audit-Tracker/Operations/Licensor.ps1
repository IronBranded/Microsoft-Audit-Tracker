<#
    .SYNOPSIS
    Licensor.ps1 - MAT v1.2
    .DESCRIPTION
    Defensive Stack and License Inventory reporter.
    Uses Get-MATSkuData cache; fixed Generic.List deduplication cast;
    HashSet for Defender plan lookups; over-consumed license flagged;
    RequiredSolutions names match DefenderMap values exactly.
    Copilot license analysis and usage reporting integrated.
#>

function Invoke-LicensorMode {
    param([switch]$Silent)

    if (-not $script:MAT_Global.IsConnected) {
        Write-Host "`n[!] Connection Required. Use [C] to connect first." -ForegroundColor Red
        Start-Sleep -Seconds 2; return
    }

    Write-Host "`n[*] Initiating Licensor Mode..." -ForegroundColor Cyan
    Write-Host "[*] Tenant : $($script:MAT_Global.TenantName)"    -ForegroundColor White
    Write-Host "[*] User   : $($script:MAT_Global.UserPrincipal)" -ForegroundColor White
    Write-Host ""

    $reportPath = Get-MATReportPath -TenantName $script:MAT_Global.TenantName

    Write-Host "[-] Loading License Data..." -ForegroundColor Gray
    $allSkus = Get-MATSkuData
    if (-not $allSkus) {
        Write-Host "[!] ERROR: SKU data unavailable." -ForegroundColor Red
        Write-MATLog -OperationName "LicensorMode" -Details "SKU data unavailable." -Status "ERROR"
        if (-not $Silent) { Pause }
        return
    }
    Write-Host "[✓] $($allSkus.Count) SKUs loaded from cache" -ForegroundColor Green

    $SkuMap      = if ($script:LicenseSkuMap)      { $script:LicenseSkuMap }      else { @{} }
    $DefenderMap = if ($script:LicenseDefenderMap) { $script:LicenseDefenderMap } else { @{} }

    # RequiredSolutions: exact strings matching DefenderMap resolved values.
    # Using -like "$sol*" for the placeholder check to handle Plan 1/Plan 2 variants.
    $RequiredSolutions = @(
        "Microsoft Sentinel",
        "Defender for Endpoint",
        "Defender for Endpoint Plan 2",
        "Defender for Office 365 Plan 1",
        "Defender for Office 365 Plan 2",
        "Defender for Identity",
        "Defender XDR",
        "Defender for Cloud Apps",
        "Defender for IoT"
    )

    # Pre-split DefenderMap keys into exact and wildcard sets for O(1) hot-path lookup
    $defExact = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $defWild  = [System.Collections.Generic.List[string]]::new()
    foreach ($k in $DefenderMap.Keys) {
        if ($k -like "*`**") { $defWild.Add($k) } else { [void]$defExact.Add($k) }
    }

    # ---- 1. DEFENSIVE STACK ---------------------------------------------------
    Write-Host "[-] Extracting Defender & Sentinel Status..." -ForegroundColor Gray
    $defensiveRaw = [System.Collections.Generic.List[PSObject]]::new()

    foreach ($sku in $allSkus) {
        foreach ($plan in $sku.ServicePlans) {
            $solution = $null

            if ($defExact.Contains($plan.ServicePlanName)) {
                $solution = $DefenderMap[$plan.ServicePlanName]
            } else {
                foreach ($wk in $defWild) {
                    if ($plan.ServicePlanName -match ($wk -replace '\*','.*')) {
                        $solution = $DefenderMap[$wk]; break
                    }
                }
            }

            if ($solution) {
                $defensiveRaw.Add([PSCustomObject]@{
                    Solution    = $solution
                    Status      = if ($plan.ProvisioningStatus -eq "Success") {"Active"} else {"Inactive"}
                    ServicePlan = $plan.ServicePlanName
                    TotalSeats  = $sku.PrepaidUnits.Enabled
                    Consumed    = $sku.ConsumedUnits
                    Unused      = $sku.PrepaidUnits.Enabled - $sku.ConsumedUnits
                    SourceSKU   = if ($SkuMap.ContainsKey($sku.SkuPartNumber)) { $SkuMap[$sku.SkuPartNumber] } else { $sku.SkuPartNumber }
                })
            }
        }
    }

    # Deduplicate: keep Active over Inactive per Solution.
    # Build new list explicitly to avoid fragile cast of pipeline output to Generic.List.
    $defensiveResults = [System.Collections.Generic.List[PSObject]]::new()
    $defensiveRaw |
        Sort-Object Solution, @{Expression={ if ($_.Status -eq "Active"){0} else {1} }} |
        Group-Object Solution |
        ForEach-Object { $defensiveResults.Add(($_.Group | Select-Object -First 1)) }

    # Placeholder injection — -like handles Plan 1/Plan 2 suffix variants
    foreach ($sol in $RequiredSolutions) {
        if (-not ($defensiveResults | Where-Object { $_.Solution -like "$sol*" })) {
            $defensiveResults.Add([PSCustomObject]@{
                Solution="$sol"; Status="Not Licensed"; ServicePlan="None"
                TotalSeats=0; Consumed=0; Unused=0; SourceSKU="None"
            })
        }
    }

    $defFile = Join-Path $reportPath "Defensive_Stack.csv"
    $defensiveResults | Export-Csv -Path $defFile -NoTypeInformation
    Write-Host "[✓] Defensive Stack: $($defensiveResults.Count) items" -ForegroundColor Green

    # ---- 2. LICENSE INVENTORY --------------------------------------------------
    Write-Host "[-] Generating License Inventory..." -ForegroundColor Gray
    $licInventory = [System.Collections.Generic.List[PSObject]]::new()

    foreach ($sku in $allSkus) {
        $total    = $sku.PrepaidUnits.Enabled
        $consumed = $sku.ConsumedUnits
        $unused   = $total - $consumed
        $health   = if ($consumed -gt $total)    { "Warning" }       # over-consumed
                    elseif ($total -gt $consumed) { "Optimizable" }   # unused seats
                    else                          { "Healthy" }

        $licInventory.Add([PSCustomObject]@{
            License_Name = if ($SkuMap.ContainsKey($sku.SkuPartNumber)) { $SkuMap[$sku.SkuPartNumber] } else { $sku.SkuPartNumber }
            SKU_ID       = $sku.SkuPartNumber
            Total_Seats  = $total
            Consumed     = $consumed
            Unused       = $unused
            Health       = $health
        })
    }

    # ---- 3. COPILOT LICENSE ANALYSIS ------------------------------------------
    Write-Host "[-] Analyzing Copilot License Status..." -ForegroundColor Gray

    $cpSkuIds  = @("Microsoft_365_Copilot","COPILOT_FOR_M365","M365_COPILOT","COPILOT_FOR_MICROSOFT_365")
    $cpSvcPlns = if ($script:CopilotServicePlans) { $script:CopilotServicePlans } else {
        @("Copilot_for_M365","Microsoft_365_Copilot","M365_COPILOT","COPILOT_FOR_MICROSOFT_365")
    }
    $copilotSkus = $allSkus | Where-Object { $_.SkuPartNumber -in $cpSkuIds }

    if ($copilotSkus) {
        foreach ($sku in $copilotSkus) {
            $total    = $sku.PrepaidUnits.Enabled
            $expiring = $sku.PrepaidUnits.Warning
            $consumed = $sku.ConsumedUnits
            $unused   = $total - $consumed
            $pct      = if ($total -gt 0) { [math]::Round(($consumed / $total) * 100, 1) } else { 0 }
            $health   = if ($consumed -eq 0)             { "Warning" }
                        elseif ($consumed -gt $total)    { "Warning" }
                        elseif ($unused -gt $total * 0.5) { "Optimizable" }
                        else                             { "Healthy" }

            $licInventory.Add([PSCustomObject]@{
                License_Name = if ($SkuMap.ContainsKey($sku.SkuPartNumber)) { $SkuMap[$sku.SkuPartNumber] } else { "Microsoft 365 Copilot" }
                SKU_ID       = $sku.SkuPartNumber
                Total_Seats  = $total
                Consumed     = $consumed
                Unused       = $unused
                Health       = "$health ($pct% utilized)"
            })
            if ($expiring -gt 0) {
                $licInventory.Add([PSCustomObject]@{
                    License_Name="Microsoft 365 Copilot — Expiry Warning"
                    SKU_ID=$sku.SkuPartNumber; Total_Seats=$expiring
                    Consumed=0; Unused=$expiring; Health="Warning"
                })
            }
        }
        Write-Host "[✓] Copilot license detected and analysed" -ForegroundColor Green
    } else {
        $bundled = $allSkus.ServicePlans | Where-Object {
            $_.ServicePlanName -in $cpSvcPlns -and $_.ProvisioningStatus -eq "Success"
        } | Select-Object -First 1

        if ($bundled) {
            $licInventory.Add([PSCustomObject]@{
                License_Name="Microsoft 365 Copilot (Bundled)"
                SKU_ID=$bundled.ServicePlanName; Total_Seats="N/A"
                Consumed="N/A"; Unused="N/A"; Health="Healthy"
            })
        } else {
            $licInventory.Add([PSCustomObject]@{
                License_Name="Microsoft 365 Copilot"; SKU_ID="Not Licensed"
                Total_Seats=0; Consumed=0; Unused=0; Health="Not Licensed"
            })
        }
    }

    # Copilot usage summary (requires Reports.Read.All)
    try {
        $usage = Invoke-MgGraphRequest -Method GET `
            -Uri "https://graph.microsoft.com/v1.0/reports/getMicrosoft365CopilotUsageSummary(period='D30')" `
            -ErrorAction Stop
        if ($usage) {
            $licInventory.Add([PSCustomObject]@{
                License_Name="Copilot Usage Summary (30-day)"
                SKU_ID="Graph Reports API"; Total_Seats="See M365 Admin Center"
                Consumed="Active"; Unused="N/A"; Health="Healthy"
            })
        }
    } catch {
        if ($_ -match "403|Forbidden|401|Unauthorized|InsufficientPermissions") {
            $licInventory.Add([PSCustomObject]@{
                License_Name="Copilot Usage Summary (30-day)"
                SKU_ID="Graph Reports API"; Total_Seats="N/A"
                Consumed="N/A"; Unused="N/A"
                Health="Manual Check — Reports.Read.All required"
            })
        }
        # 404 = Copilot not deployed; no row needed
    }

    $licFile = Join-Path $reportPath "Licenses_Inventory.csv"
    $licInventory | Export-Csv -Path $licFile -NoTypeInformation
    Write-Host "[✓] License Inventory: $($licInventory.Count) items" -ForegroundColor Green

    Write-MATLog -OperationName "LicensorMode" -Details "Defensive_Stack ($($defensiveResults.Count)) and Licenses_Inventory ($($licInventory.Count)) saved to $reportPath"

    Write-Host "`n[✓] Licensor Mode Complete!" -ForegroundColor Green
    Write-Host "[+] Reports: $reportPath" -ForegroundColor Cyan
    Write-Host "    - Defensive_Stack.csv    ($($defensiveResults.Count) items)" -ForegroundColor White
    Write-Host "    - Licenses_Inventory.csv ($($licInventory.Count) items)" -ForegroundColor White

    if (-not $Silent) { Pause }
}
