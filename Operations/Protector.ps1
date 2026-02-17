function Invoke-ProtectorMode {
    <#
    .SYNOPSIS
    Security Posture Audit Mode
    
    .DESCRIPTION
    Inventories identity protection controls including:
    - Security Defaults status
    - Conditional Access policies
    - Security service plan assignments
    #>
    
    if (-not $script:MAT_Global.IsConnected) { 
        Write-Host "`n[!] Connection Required." -ForegroundColor Red
        Write-Host "[!] Please use option [C] to connect to a tenant first." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return 
    }
    
    Write-Host "`n[*] Running Protector Mode..." -ForegroundColor Cyan
    Write-Host "[*] Target Tenant: $($script:MAT_Global.TenantName)" -ForegroundColor White
    Write-Host "[*] Authenticated User: $($script:MAT_Global.UserPrincipal)" -ForegroundColor White
    Write-Host ""
    
    $reportPath = Get-MATReportPath -TenantName $script:MAT_Global.TenantName
    $outFile = Join-Path $reportPath "Protector_Inventory.csv"
    
    $inventory = New-Object System.Collections.Generic.List[PSObject]

    # 1. Security Defaults
    Write-Host "[-] Checking Security Defaults..." -ForegroundColor Gray
    try {
        $secDefaults = Get-MgPolicyIdentitySecurityDefaultEnforcementPolicy -ErrorAction Stop
        $status = if ($secDefaults.IsEnabled) { "Enabled" } else { "Disabled" }
        $inventory.Add([PSCustomObject]@{ 
            Type = "Security Policy"
            Name = "Security Defaults"
            State = $status
            Description = "Baseline security protections for identity"
        })
        Write-Host "[✓] Security Defaults: $status" -ForegroundColor $(if ($status -eq "Enabled") {"Green"} else {"Yellow"})
    } catch {
        Write-Host "[!] Warning: Failed to query Security Defaults - $($_.Exception.Message)" -ForegroundColor Yellow
        $inventory.Add([PSCustomObject]@{ 
            Type = "Security Policy"
            Name = "Security Defaults"
            State = "Error/Failed"
            Description = "Query failed - check permissions"
        })
    }

    # 2. Conditional Access
    Write-Host "[-] Checking Conditional Access Policies..." -ForegroundColor Gray
    try {
        $caps = Get-MgIdentityConditionalAccessPolicy -ErrorAction Stop
        if ($caps -and $caps.Count -gt 0) {
            Write-Host "[✓] Found $($caps.Count) Conditional Access policies" -ForegroundColor Green
            foreach ($policy in $caps) {
                $inventory.Add([PSCustomObject]@{ 
                    Type = "Conditional Access"
                    Name = $policy.DisplayName
                    State = $policy.State
                    Description = "CA Policy - $($policy.State)"
                })
            }
        } else {
            Write-Host "[!] No Conditional Access policies found" -ForegroundColor Yellow
            $inventory.Add([PSCustomObject]@{ 
                Type = "Conditional Access"
                Name = "None"
                State = "No Policies Found"
                Description = "No CA policies configured"
            })
        }
    } catch {
        Write-Host "[!] Warning: Failed to query Conditional Access - $($_.Exception.Message)" -ForegroundColor Yellow
        $inventory.Add([PSCustomObject]@{ 
            Type = "Conditional Access"
            Name = "Error"
            State = "Failed to query"
            Description = "Check permissions for ConditionalAccess.Read.All"
        })
    }

    # 3. Security Service Plan Inventory
    Write-Host "[-] Inventorying Security Service Plans..." -ForegroundColor Gray
    try {
        $allSkus = Get-MgSubscribedSku -Property SkuPartNumber, ServicePlans -ErrorAction Stop
        
        # Mapping the key security service plans
        $planMap = @{
            "AAD_PREMIUM"                         = "Entra ID P1"
            "AAD_PREMIUM_P2"                      = "Entra ID P2"
            "AAD_PREMIUM_V2"                      = "Entra ID P2"
            "M365_ADVANCED_AUDITING"              = "Purview Audit (Premium)"
            "THREAT_PROTECTION"                   = "Defender for Endpoint P2"
            "THREAD_PROTECTION_ENDPOINT"          = "Defender for Endpoint P2"
            "MDE_PLAN2"                           = "Defender for Endpoint P2"
            "ATP_ENTERPRISE"                      = "Defender for Office 365 P2"
            "MFA_PREMIUM"                         = "Azure AD MFA"
            "CLOUDAPPSECURITY"                    = "Defender for Cloud Apps"
            "MICROSOFT_CLOUD_APP_SECURITY"        = "Defender for Cloud Apps"
            "AZURE_ACTIVE_DIRECTORY_PLATFORM"     = "Defender for Identity"
            "AAD_IDENTITY_PROTECTION"             = "Azure AD Identity Protection"
            "INFORMATION_PROTECTION_COMPLIANCE"   = "Information Protection & Compliance"
            "M365_LIGHTHOUSE"                     = "Microsoft 365 Lighthouse"
        }

        # Flatten all service plans across all SKUs
        $activePlans = @()
        foreach ($sku in $allSkus) {
            foreach ($plan in $sku.ServicePlans) {
                if ($plan.ProvisioningStatus -eq "Success") {
                    $activePlans += $plan.ServicePlanName
                }
            }
        }
        
        $activePlans = $activePlans | Select-Object -Unique
        
        Write-Host "[✓] Analyzing $($activePlans.Count) unique active service plans" -ForegroundColor Green
        
        # Check each security plan
        $foundCount = 0
        foreach ($planID in $planMap.Keys) {
            $friendlyName = $planMap[$planID]
            $isFound = $activePlans -contains $planID
            
            $inventory.Add([PSCustomObject]@{
                Type        = "Service Plan"
                Name        = $friendlyName
                State       = if ($isFound) { "Licensed" } else { "Not Found" }
                Description = "Security service - $planID"
            })
            
            if ($isFound) { $foundCount++ }
        }
        
        Write-Host "[✓] Found $foundCount of $($planMap.Count) key security service plans" -ForegroundColor Cyan
        
    } catch {
        Write-Host "[!] Warning: Failed to query service plans - $($_.Exception.Message)" -ForegroundColor Yellow
        $inventory.Add([PSCustomObject]@{ 
            Type = "Service Plan"
            Name = "Inventory Error"
            State = "Failed to query Graph"
            Description = "Check permissions for Organization.Read.All"
        })
    }

    # Export and Wrap up
    Write-Host "`n[-] Generating report..." -ForegroundColor Gray
    $inventory | Export-Csv -Path $outFile -NoTypeInformation
    
    Write-MATLog -OperationName "ProtectorMode" -Details "Generated Protector_Inventory.csv (Policy & Licensing)"
    
    Write-Host "`n[✓] Protector Mode Complete!" -ForegroundColor Green
    Write-Host "[+] Report saved to: $outFile" -ForegroundColor Cyan
    Write-Host "[+] Total items inventoried: $($inventory.Count)" -ForegroundColor White
    
    Pause
}
