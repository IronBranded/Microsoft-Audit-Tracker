<#
    .SYNOPSIS
    Licensor.ps1 - MAT V1.0
    .DESCRIPTION
    Comprehensive License & Defensive Stack Reporter.
    Supports Enterprise, Government (GCC/DoD), and Education SKUs.
#>

function Invoke-LicensorMode {
    if (-not $script:MAT_Global.IsConnected) { 
        Write-Host "[!] Connection Required. Please use [C] to connect first." -ForegroundColor Red
        Start-Sleep -Seconds 2
        return 
    }

    Write-Host "[*] Initiating Licensor Mode..." -ForegroundColor Cyan
    $reportPath = Get-MATReportPath -TenantName $script:MAT_Global.TenantName
    
    Write-Host "[-] Querying Microsoft Graph for License Data..." -ForegroundColor Gray
    $allSkus = Get-MgSubscribedSku -Property SkuPartNumber, SkuId, PrepaidUnits, ConsumedUnits, ServicePlans

    # =====================================================================
    # EXPANDED SKU MAP (Your Full Reference List)
    # =====================================================================
    $SkuMap = @{
        # Office 365 Enterprise
        "STANDARDPACK"                    = "Office 365 E1"
        "ENTERPRISEPACK"                  = "Office 365 E3"
        "ENTERPRISEPREMIUM"               = "Office 365 E5"
        "ENTERPRISEWITHSCAL"              = "Office 365 E4 (Legacy)"
        "MIDSIZEPACK"                     = "Office 365 Midsize Business (Legacy)"
        # Microsoft 365 Enterprise
        "SPE_E3"                          = "Microsoft 365 E3"
        "SPE_E5"                          = "Microsoft 365 E5 (Full)"
        "SPE_F1"                          = "Microsoft 365 F1 (Legacy)"
        "M365_E3"                         = "Microsoft 365 E3"
        "M365_E5"                         = "Microsoft 365 E5"
        "M365_E5_SECURITY"                = "Microsoft 365 E5 Security"
        "M365_E5_COMPLIANCE"              = "Microsoft 365 E5 Compliance"
        "IDENTITY_THREAT_PROTECTION"      = "Microsoft 365 E5 Security (Legacy)"
        "THREAT_INTELLIGENCE"             = "Microsoft 365 E5 Security Add-on"
        # Microsoft 365 Business
        "M365_BUSINESS_BASIC"             = "Microsoft 365 Business Basic"
        "M365_BUSINESS_STANDARD"          = "Microsoft 365 Business Standard"
        "M365_BUSINESS_PREMIUM"           = "Microsoft 365 Business Premium"
        "O365_BUSINESS"                   = "Office 365 Business"
        "O365_BUSINESS_ESSENTIALS"        = "Office 365 Business Essentials"
        "O365_BUSINESS_PREMIUM"           = "Office 365 Business Premium"
        # Frontline
        "M365_F1"                         = "Microsoft 365 F1"
        "M365_F3"                         = "Microsoft 365 F3"
        "M365_F5_SECURITY"                = "Microsoft 365 F5 Security"
        "M365_F5_COMPLIANCE"              = "Microsoft 365 F5 Compliance"
        "M365_F5_SECCOMP"                 = "Microsoft 365 F5 Security + Compliance"
        # Education
        "M365_A1"                         = "Microsoft 365 A1 (Legacy)"
        "A1_FOR_DEVICES"                  = "Microsoft 365 A1 for Devices"
        "M365_A3"                         = "Microsoft 365 A3"
        "M365_A5"                         = "Microsoft 365 A5 (Full)"
        "M365_A5_SECURITY"                = "Microsoft 365 A5 Security"
        "M365_A5_COMPLIANCE"              = "Microsoft 365 A5 Compliance"
        "STANDARDWOFFPACK_IW_STUDENT"     = "Office 365 A1 Student"
        "STANDARDWOFFPACK_IW_FACULTY"     = "Office 365 A1 Faculty"
        # Defender / Security Add-ons
        "ATP_ENTERPRISE"                  = "Defender for Office 365 Plan 2"
        "ATP_ENTERPRISE_FACULTY"          = "Defender for Office 365 Plan 2 (Faculty)"
        "ATP_ENTERPRISE_STUDENT"          = "Defender for Office 365 Plan 2 (Student)"
        "AAD_PREMIUM"                     = "Azure AD Premium P1"
        "AAD_PREMIUM_P2"                  = "Azure AD Premium P2"
        "EMS"                             = "Enterprise Mobility + Security E3"
        "EMSPREMIUM"                      = "Enterprise Mobility + Security E5"
        # Government SKUs
        "ENTERPRISEPACK_GOV"              = "Office 365 E3 (GCC)"
        "ENTERPRISEPREMIUM_GOV"           = "Office 365 E5 (GCC)"
        "SPE_E3_GOV"                      = "Microsoft 365 E3 (GCC)"
        "SPE_E5_GOV"                      = "Microsoft 365 E5 (GCC)"
        "ENTERPRISEPACK_GOV_HI"           = "Office 365 E3 (GCC High)"
        "ENTERPRISEPREMIUM_GOV_HI"        = "Office 365 E5 (GCC High)"
        "DOD_ENTERPRISEPACK"              = "Office 365 E3 (DoD)"
        "DOD_ENTERPRISEPREMIUM"           = "Office 365 E5 (DoD)"
        # Misc
        "FLOW_FREE"                       = "Power Automate Free"
        "POWER_BI_STANDARD"               = "Power BI Pro"
        "POWER_BI_PREMIUM"                = "Power BI Premium"
        "PROJECTPROFESSIONAL"             = "Project Plan 3"
        "PROJECTPREMIUM"                  = "Project Plan 5"
        "VISIOCLIENT"                     = "Visio Plan 2"
    }

    # =====================================================================
    # EXPANDED DEFENDER / SENTINEL SERVICE PLAN MAP
    # =====================================================================
    $DefenderMap = @{
        # Sentinel
        "*SENTINEL*"                      = "Microsoft Sentinel"
        "MICROSOFT_SENTINEL"              = "Microsoft Sentinel"
        "AZURE_SENTINEL"                  = "Microsoft Sentinel"
        # Endpoint
        "THREAT_PROTECTION"               = "Defender for Endpoint"
        "WINDOWS_DEFENDER_ADVANCED_THREAT_PROTECTION" = "Defender for Endpoint"
        "MDATP"                           = "Defender for Endpoint"
        "MDE_PLAN2"                       = "Defender for Endpoint Plan 2"
        "MDE_PLAN1"                       = "Defender for Endpoint Plan 1"
        # Office 365
        "ATP_ENTERPRISE"                  = "Defender for Office 365 Plan 2"
        "ATP_ENTERPRISE_FACULTY"          = "Defender for Office 365 Plan 2"
        "ATP_ENTERPRISE_STUDENT"          = "Defender for Office 365 Plan 2"
        "EXCHANGE_ADVANCED_THREAT_PROTECTION" = "Defender for Office 365 Plan 1"
        "ATP_STANDARD"                    = "Defender for Office 365 Plan 1"
        # Identity
        "AZURE_ACTIVE_DIRECTORY_PLATFORM"  = "Defender for Identity"
        "AAD_IDENTITY_PROTECTION"          = "Defender for Identity"
        "M365_DEFENDER_IDENTITY"           = "Defender for Identity"
        # Cloud Apps
        "CLOUDAPPSECURITY"                = "Defender for Cloud Apps"
        "MICROSOFT_CLOUD_APP_SECURITY"    = "Defender for Cloud Apps"
        "MCAS"                            = "Defender for Cloud Apps"
        # XDR / IoT
        "MTP"                             = "Defender XDR"
        "MICROSOFT_THREAT_PROTECTION"     = "Defender XDR"
        "M365_DEFENDER"                   = "Defender XDR"
        "*IOT*"                           = "Defender for IoT"
        "IOT_SECURITY"                    = "Defender for IoT"
    }

    $RequiredSolutions = @("Microsoft Sentinel", "Defender for Endpoint", "Defender for Office 365", "Defender for Identity", "Defender XDR", "Defender for Cloud Apps", "Defender for IoT")

    # --- 1. DEFENSIVE STACK REPORT ---
    Write-Host "[-] Extracting Defender & Sentinel Status..." -ForegroundColor Gray
    $defensiveResults = New-Object System.Collections.Generic.List[PSObject]

    foreach ($sku in $allSkus) {
        foreach ($plan in $sku.ServicePlans) {
            $solution = $null
            foreach ($key in $DefenderMap.Keys) {
                if ($plan.ServicePlanName -like $key) { $solution = $DefenderMap[$key]; break }
            }

            if ($solution) {
                $friendlySource = if ($SkuMap.ContainsKey($sku.SkuPartNumber)) { $SkuMap[$sku.SkuPartNumber] } else { $sku.SkuPartNumber }
                $defensiveResults.Add([PSCustomObject]@{
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

    # Inject "Not Licensed" for missing items
    foreach ($sol in $RequiredSolutions) {
        if (-not ($defensiveResults | Where-Object { $_.Solution -eq $sol })) {
            $defensiveResults.Add([PSCustomObject]@{
                Solution = $sol; Status = "Not Licensed"; ServicePlan = "None"; TotalSeats = 0; Consumed = 0; Unused = 0; SourceSKU = "None"
            })
        }
    }
    $defFile = Join-Path $reportPath "Defensive_Stack.csv"
    $defensiveResults | Export-Csv -Path $defFile -NoTypeInformation

    # --- 2. LICENSE INVENTORY REPORT ---
    Write-Host "[-] Generating Inventory for Core Suites..." -ForegroundColor Gray
    $licInventory = New-Object System.Collections.Generic.List[PSObject]

    foreach ($sku in $allSkus) {
        if ($SkuMap.ContainsKey($sku.SkuPartNumber)) {
            $licInventory.Add([PSCustomObject]@{
                License_Name = $SkuMap[$sku.SkuPartNumber]
                Total_Seats  = $sku.PrepaidUnits.Enabled
                Consumed     = $sku.ConsumedUnits
                Unused       = $sku.PrepaidUnits.Enabled - $sku.ConsumedUnits
                Health       = if ($sku.PrepaidUnits.Enabled -gt $sku.ConsumedUnits) { "Optimizable" } else { "Healthy" }
            })
        }
    }
    $licFile = Join-Path $reportPath "Licenses_Inventory.csv"
    $licInventory | Export-Csv -Path $licFile -NoTypeInformation

    Write-MATLog -OperationName "LicensorMode" -Details "Generated Reports in $reportPath"
    Write-Host "[+] Operation [3] successful. Inventory saved to $outFile" -ForegroundColor Green
    Start-Sleep -Seconds 4
}