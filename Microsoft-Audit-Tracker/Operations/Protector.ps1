function Invoke-ProtectorMode {
    if (-not $script:MAT_Global.IsConnected) { Write-Host "[!] Connect first." -ForegroundColor Red; Start-Sleep 2; return }
    
    Write-Host "[*] Running Protector Mode..." -ForegroundColor Cyan
    $reportPath = Get-MATReportPath -TenantName $script:MAT_Global.TenantName
    $outFile = Join-Path $reportPath "Protector_Report.csv"
    
    $inventory = New-Object System.Collections.Generic.List[PSObject]
    
    # 1. Security Defaults
    Write-Host "[-] Checking Security Defaults..." -ForegroundColor Gray
    try {
        $secDefaults = Get-MgPolicyIdentitySecurityDefaultEnforcementPolicy
        $status = if ($secDefaults.IsEnabled) { "Enabled" } else { "Disabled" }
        $inventory.Add([PSCustomObject]@{ Type = "Security Policy"; Name = "Security Defaults"; State = $status })
    } catch {
         $inventory.Add([PSCustomObject]@{ Type = "Security Policy"; Name = "Security Defaults"; State = "Error/Failed" })
    }
    
    # 2. Conditional Access
    Write-Host "[-] Checking Conditional Access Policies..." -ForegroundColor Gray
    try {
        $caps = Get-MgIdentityConditionalAccessPolicy
        if ($caps) {
            foreach ($policy in $caps) {
                $inventory.Add([PSCustomObject]@{ Type = "Conditional Access"; Name = $policy.DisplayName; State = $policy.State })
            }
        } else {
             $inventory.Add([PSCustomObject]@{ Type = "Conditional Access"; Name = "None"; State = "No Policies Found" })
        }
    } catch {
        $inventory.Add([PSCustomObject]@{ Type = "Conditional Access"; Name = "Error"; State = "Failed to query" })
    }
    
    # 3. Security Service Plan Inventory (Identity & Entra Variations)
    Write-Host "[-] Inventorying Security Service Plans..." -ForegroundColor Gray
    try {
        $allSkus = Get-MgSubscribedSku -Property SkuPartNumber, ServicePlans
        
        # Mapping the variations you requested
        $planMap = @{
            "AAD_PREMIUM"             = "Entra ID P1"
            "AAD_PREMIUM_V2"          = "Entra ID P2"
            "M365_ADVANCED_AUDITING"  = "Purview Audit (Premium)"
            "THREAD_PROTECTION_ENDPOINT" = "Defender for Endpoint P2"
            "ATP_ENTERPRISE"          = "Defender for Office 365"
            "MFA_PREMIUM"             = "Defender for Cloud Apps"
        }
        
        # Flat map all active service plans across all SKUs
        $activePlans = $allSkus.ServicePlans | Where-Object { $_.ProvisioningStatus -eq "Success" } | Select-Object -ExpandProperty ServicePlanName
        
        foreach ($planID in $planMap.Keys) {
            $friendlyName = $planMap[$planID]
            $isFound = if ($activePlans -contains $planID) { "Licensed" } else { "Not Found" }
            
            $inventory.Add([PSCustomObject]@{
                Type  = "Service Plan"
                Name  = $friendlyName
                State = $isFound
            })
        }
    } catch {
        $inventory.Add([PSCustomObject]@{ Type = "Service Plan"; Name = "Inventory Error"; State = "Failed to query Graph" })
    }
    
    # Export and Wrap up
    $inventory | Export-Csv -Path $outFile -NoTypeInformation
    Write-MATLog -OperationName "ProtectorMode" -Details "Generated Protector_Report.csv (Policy & Licensing)"
    
    Write-Host "[+] Operation [2] successful. Inventory saved to $outFile" -ForegroundColor Green
    Start-Sleep -Seconds 4
}
