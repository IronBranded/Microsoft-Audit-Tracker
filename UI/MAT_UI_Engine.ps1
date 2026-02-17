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
    
    # Truncate user principal if needed
    $displayUser = if ($user.Length -gt 35) {
        $user.Substring(0,32) + "..."
    } else {
        $user
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

function Invoke-LicensorMode {
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
        $allSkus = Get-MgSubscribedSku -Property SkuPartNumber, PrepaidUnits, ConsumedUnits, ServicePlans -ErrorAction Stop
        Write-Host "[✓] Retrieved $($allSkus.Count) SKUs from tenant" -ForegroundColor Green
    } catch {
        Write-Host "[!] ERROR: Failed to query licenses - $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[!] Ensure you have Organization.Read.All permissions" -ForegroundColor Yellow
        Pause
        return
    }

    # Initialize License Maps if not already loaded
    if (-not $global:SkuMap) {
        Write-Host "[-] Initializing License Mappings..." -ForegroundColor Gray
        $global:SkuMap = @{
            "SPE_E5"                    = "Microsoft 365 E5"
            "SPE_E3"                    = "Microsoft 365 E3"
            "ENTERPRISEPACK"            = "Office 365 E3"
            "ENTERPRISEPREMIUM"         = "Office 365 E5"
            "ENTERPRISEPREMIUM_NOPSTNCONF" = "Office 365 E5 (without Audio Conferencing)"
            "O365_BUSINESS_ESSENTIALS"  = "Microsoft 365 Business Basic"
            "O365_BUSINESS_PREMIUM"     = "Microsoft 365 Business Standard"
            "SMB_BUSINESS_PREMIUM"      = "Microsoft 365 Business Premium"
            "PROJECTPROFESSIONAL"       = "Project Plan 5"
            "PROJECTESSENTIALS"         = "Project Plan 3"
            "VISIOCLIENT"               = "Visio Plan 2"
            "POWER_BI_PRO"              = "Power BI Pro"
            "POWER_BI_STANDARD"         = "Power BI (free)"
            "FLOW_FREE"                 = "Power Automate Free"
            "POWERAPPS_VIRAL"           = "Power Apps Trial"
            "TEAMS_EXPLORATORY"         = "Microsoft Teams Exploratory"
            "RIGHTSMANAGEMENT_ADHOC"    = "Rights Management Adhoc"
            "AAD_PREMIUM"               = "Azure Active Directory Premium P1"
            "AAD_PREMIUM_P2"            = "Azure Active Directory Premium P2"
            "EMS"                       = "Enterprise Mobility + Security E3"
            "EMSPREMIUM"                = "Enterprise Mobility + Security E5"
            "IDENTITY_THREAT_PROTECTION" = "Microsoft Defender for Identity"
            "M365_F1"                   = "Microsoft 365 F1"
            "M365_F3"                   = "Microsoft 365 F3"
            "SPE_F1"                    = "Microsoft 365 F3"
            "EXCHANGESTANDARD"          = "Exchange Online (Plan 1)"
            "EXCHANGEENTERPRISE"        = "Exchange Online (Plan 2)"
            "MCOSTANDARD"               = "Skype for Business Online (Plan 2)"
            "SHAREPOINTSTANDARD"        = "SharePoint Online (Plan 1)"
            "SHAREPOINTENTERPRISE"      = "SharePoint Online (Plan 2)"
            "ATP_ENTERPRISE"            = "Microsoft Defender for Office 365 (Plan 1)"
            "THREAT_INTELLIGENCE"       = "Microsoft Defender for Office 365 (Plan 2)"
            "INTUNE_A"                  = "Microsoft Intune"
            "ENTERPRISEPACK_B_PILOT"    = "Office 365 E3 Trial"
            "DEVELOPERPACK_E5"          = "Microsoft 365 E5 Developer"
            "INFORMATION_PROTECTION_COMPLIANCE" = "Microsoft 365 E5 Compliance"
            "IDENTITY_THREAT_PROTECTION_FOR_EMS_E5" = "Microsoft 365 E5 Security"
        }
    }

    if (-not $global:DefenderMap) {
        $global:DefenderMap = @{
            "*THREAT_INTELLIGENCE*"     = "Defender for Office 365"
            "*ATP*"                     = "Defender for Office 365"
            "*DEFENDER*ENDPOINT*"       = "Defender for Endpoint"
            "*MDE*"                     = "Defender for Endpoint"
            "*DEFENDER*IDENTITY*"       = "Defender for Identity"
            "*AAD*IDENTITY*"            = "Defender for Identity"
            "*DEFENDER*CLOUD*APP*"      = "Defender for Cloud Apps"
            "*ADALLOM*"                 = "Defender for Cloud Apps"
            "*DEFENDER*XDR*"            = "Defender XDR"
            "*M365D*"                   = "Defender XDR"
            "*SENTINEL*"                = "Microsoft Sentinel"
            "*SIEM*"                    = "Microsoft Sentinel"
            "*DEFENDER*IOT*"            = "Defender for IoT"
        }
    }
    
    $defensiveStack = New-Object System.Collections.Generic.List[PSObject]
    $RequiredSolutions = @("Microsoft Sentinel", "Defender for Endpoint", "Defender for Office 365", "Defender for Identity", "Defender XDR", "Defender for Cloud Apps", "Defender for IoT")

    Write-Host "[-] Extracting Defender & Sentinel Status..." -ForegroundColor Gray
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
    Write-Host "[✓] Defensive Stack report generated" -ForegroundColor Green

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
    Write-Host "[✓] License inventory report generated" -ForegroundColor Green

    Write-MATLog -OperationName "LicensorMode" -Details "Generated Reports in $reportPath"
    
    Write-Host "`n[✓] Licensor Mode Complete!" -ForegroundColor Green
    Write-Host "[+] Reports saved to: $reportPath" -ForegroundColor Cyan
    Write-Host "    - Defensive_Stack.csv (Security solutions: $($defensiveStack.Count) items)" -ForegroundColor White
    Write-Host "    - Licenses_Inventory.csv (All SKUs: $($licInventory.Count) items)" -ForegroundColor White
    
    Pause
}

function New-SuperAuditorHTMLReport {
    param(
        [string]$ReportPath,
        [string]$TenantName,
        [string]$Auditor,
        [string]$TimeStamp
    )

    # Read CSV files with error handling
    $auditorFile = Join-Path $ReportPath "Auditor_Report.csv"
    $protectorFile = Join-Path $ReportPath "Protector_Inventory.csv"
    $defensiveFile = Join-Path $ReportPath "Defensive_Stack.csv"
    $licensesFile = Join-Path $ReportPath "Licenses_Inventory.csv"

    # Import CSV data with error handling
    try {
        $auditorData = if (Test-Path $auditorFile) { 
            $data = Import-Csv $auditorFile
            Write-Host "  [✓] Loaded $($data.Count) auditor records" -ForegroundColor Gray
            $data
        } else { 
            Write-Host "  [!] Auditor file not found" -ForegroundColor Yellow
            @() 
        }
    } catch {
        Write-Host "  [!] Failed to load Auditor data: $($_.Exception.Message)" -ForegroundColor Red
        $auditorData = @()
    }

    try {
        $protectorData = if (Test-Path $protectorFile) { 
            $data = Import-Csv $protectorFile
            Write-Host "  [✓] Loaded $($data.Count) protector records" -ForegroundColor Gray
            $data
        } else { 
            Write-Host "  [!] Protector file not found" -ForegroundColor Yellow
            @() 
        }
    } catch {
        Write-Host "  [!] Failed to load Protector data: $($_.Exception.Message)" -ForegroundColor Red
        $protectorData = @()
    }

    try {
        $defensiveData = if (Test-Path $defensiveFile) { 
            $data = Import-Csv $defensiveFile
            Write-Host "  [✓] Loaded $($data.Count) defensive records" -ForegroundColor Gray
            $data
        } else { 
            Write-Host "  [!] Defensive file not found" -ForegroundColor Yellow
            @() 
        }
    } catch {
        Write-Host "  [!] Failed to load Defensive data: $($_.Exception.Message)" -ForegroundColor Red
        $defensiveData = @()
    }

    try {
        $licensesData = if (Test-Path $licensesFile) { 
            $data = Import-Csv $licensesFile
            Write-Host "  [✓] Loaded $($data.Count) license records" -ForegroundColor Gray
            $data
        } else { 
            Write-Host "  [!] Licenses file not found" -ForegroundColor Yellow
            @() 
        }
    } catch {
        Write-Host "  [!] Failed to load Licenses data: $($_.Exception.Message)" -ForegroundColor Red
        $licensesData = @()
    }

    # Generate HTML with your preferred styling
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Microsoft Audit Tracker - Executive Report</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #0a0e27 0%, #1a1f3a 100%);
            color: #e0e0e0;
            padding: 20px;
            min-height: 100vh;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
        }

        .header {
            background: linear-gradient(135deg, #1e2139 0%, #252a45 100%);
            border: 1px solid #2d3348;
            border-radius: 8px;
            padding: 30px;
            margin-bottom: 30px;
            position: relative;
        }

        .header h1 {
            color: #4a9eff;
            font-size: 2em;
            margin-bottom: 5px;
            font-weight: 300;
            letter-spacing: 1px;
        }

        .header .subtitle {
            color: #8b92b0;
            font-size: 1.1em;
            margin-bottom: 20px;
        }

        .confidential {
            position: absolute;
            top: 30px;
            right: 30px;
            color: #ff6b6b;
            font-weight: 600;
            font-size: 1.2em;
            letter-spacing: 3px;
        }

        .meta-info {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 20px;
            margin-top: 25px;
        }

        .meta-card {
            background: rgba(74, 158, 255, 0.1);
            border: 1px solid rgba(74, 158, 255, 0.3);
            border-radius: 6px;
            padding: 15px;
        }

        .meta-label {
            color: #8b92b0;
            font-size: 0.85em;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 5px;
        }

        .meta-value {
            color: #ffffff;
            font-size: 1.1em;
            font-weight: 500;
        }

        .section {
            background: linear-gradient(135deg, #1e2139 0%, #252a45 100%);
            border: 1px solid #2d3348;
            border-radius: 8px;
            padding: 25px;
            margin-bottom: 25px;
        }

        .section-title {
            color: #ffffff;
            font-size: 1.3em;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 2px solid #4a9eff;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }

        thead {
            background: rgba(74, 158, 255, 0.15);
        }

        th {
            color: #4a9eff;
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.85em;
            letter-spacing: 1px;
            padding: 15px;
            text-align: left;
            border-bottom: 2px solid #4a9eff;
        }

        td {
            padding: 12px 15px;
            border-bottom: 1px solid #2d3348;
            color: #e0e0e0;
        }

        tr:hover {
            background: rgba(74, 158, 255, 0.05);
        }

        .status-active, .status-healthy, .status-enabled {
            color: #51cf66;
            font-weight: 600;
        }

        .status-inactive, .status-disabled {
            color: #ff6b6b;
            font-weight: 600;
        }

        .status-warning, .status-review {
            color: #ffd43b;
            font-weight: 600;
        }

        .severity-high {
            color: #ff6b6b;
            font-weight: 600;
        }

        .severity-medium {
            color: #ffd43b;
            font-weight: 600;
        }

        .severity-low {
            color: #51cf66;
            font-weight: 600;
        }

        .no-data {
            text-align: center;
            padding: 30px;
            color: #8b92b0;
            font-style: italic;
        }

        .footer {
            text-align: center;
            margin-top: 40px;
            padding: 20px;
            color: #6c7293;
            font-size: 0.9em;
        }

        @media (max-width: 768px) {
            .meta-info { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <span class="confidential">CONFIDENTIAL</span>
            <h1>Microsoft Audit Tracker</h1>
            <div class="subtitle">Executive Audit Report</div>
            <div class="meta-info">
                <div class="meta-card">
                    <div class="meta-label">TARGET TENANT</div>
                    <div class="meta-value">$TenantName</div>
                </div>
                <div class="meta-card">
                    <div class="meta-label">AUDITOR</div>
                    <div class="meta-value">$Auditor</div>
                </div>
                <div class="meta-card">
                    <div class="meta-label">SCAN TIMESTAMP</div>
                    <div class="meta-value">$TimeStamp</div>
                </div>
            </div>
        </div>

        <div class="section">
            <div class="section-title">[1] Forensic Readiness Check (Auditor)</div>
"@

    if ($auditorData.Count -gt 0) {
        $html += @"
            <table>
                <thead>
                    <tr>
                        <th>CATEGORY</th>
                        <th>AUDIT CONTROL</th>
                        <th>STATUS</th>
                        <th>SEVERITY</th>
                        <th>CURRENT VALUE</th>
                        <th>FORENSIC IMPACT</th>
                    </tr>
                </thead>
                <tbody>
"@
        foreach ($row in $auditorData) {
            $statusClass = switch -Regex ($row.Status) {
                "^Healthy$|^Enabled$|^Active$" { "status-healthy" }
                "^Warning$|^Partial$" { "status-warning" }
                "^Review$" { "status-review" }
                default { "status-disabled" }
            }
            
            $severityClass = switch -Regex ($row.Severity) {
                "High|Critical" { "severity-high" }
                "Medium" { "severity-medium" }
                default { "severity-low" }
            }
            
            $html += @"
                    <tr>
                        <td>$($row.Category)</td>
                        <td>$($row.Audit_Control)</td>
                        <td class="$statusClass">$($row.Status)</td>
                        <td class="$severityClass">$($row.Severity)</td>
                        <td>$($row.Current_Value)</td>
                        <td>$($row.Forensic_Impact)</td>
                    </tr>
"@
        }
        $html += "</tbody></table>"
    } else {
        $html += '<div class="no-data">No auditor data available</div>'
    }

    $html += @"
        </div>

        <div class="section">
            <div class="section-title">[2] Identity & Posture (Protector)</div>
"@

    if ($protectorData.Count -gt 0) {
        $html += @"
            <table>
                <thead>
                    <tr>
                        <th>TYPE</th>
                        <th>NAME</th>
                        <th>STATE</th>
                    </tr>
                </thead>
                <tbody>
"@
        foreach ($row in $protectorData) {
            $policyName = if ($row.Name) { $row.Name } else { "Unknown" }
            $policyType = if ($row.Type) { $row.Type } else { "Policy" }
            $policyState = if ($row.State) { $row.State } else { "Unknown" }
            
            $stateClass = switch -Regex ($policyState) {
                "^Enabled$|^Active$" { "status-enabled" }
                "^Warning$" { "status-warning" }
                "^Review$" { "status-review" }
                default { "status-disabled" }
            }
            
            $html += @"
                    <tr>
                        <td>$policyType</td>
                        <td>$policyName</td>
                        <td class="$stateClass">$policyState</td>
                    </tr>
"@
        }
        $html += "</tbody></table>"
    } else {
        $html += '<div class="no-data">No protector data available</div>'
    }

    $html += @"
        </div>

        <div class="section">
            <div class="section-title">[3] Licenses Inventory</div>
"@

    if ($licensesData.Count -gt 0) {
        $html += @"
            <table>
                <thead>
                    <tr>
                        <th>LICENSE NAME</th>
                        <th>TOTAL SEATS</th>
                        <th>CONSUMED</th>
                        <th>UNUSED</th>
                        <th>HEALTH</th>
                    </tr>
                </thead>
                <tbody>
"@
        foreach ($row in $licensesData) {
            $healthClass = if ($row.Health -eq "Optimizable") { "severity-medium" } else { "status-enabled" }
            
            $html += @"
                    <tr>
                        <td>$($row.License_Name)</td>
                        <td>$($row.Total_Seats)</td>
                        <td>$($row.Consumed)</td>
                        <td>$($row.Unused)</td>
                        <td class="$healthClass">$($row.Health)</td>
                    </tr>
"@
        }
        $html += "</tbody></table>"
    } else {
        $html += '<div class="no-data">No licenses data available</div>'
    }

    $html += @"
        </div>

        <div class="section">
            <div class="section-title">[4] Defensive Stack</div>
"@

    if ($defensiveData.Count -gt 0) {
        $html += @"
            <table>
                <thead>
                    <tr>
                        <th>SOLUTION</th>
                        <th>STATUS</th>
                        <th>SERVICE PLAN</th>
                        <th>TOTAL SEATS</th>
                        <th>CONSUMED</th>
                        <th>UNUSED</th>
                        <th>SOURCE SKU</th>
                    </tr>
                </thead>
                <tbody>
"@
        foreach ($row in $defensiveData) {
            $statusClass = switch -Regex ($row.Status) {
                "^Active$|^Enabled$|^Licensed$" { "status-active" }
                "^Warning$" { "status-warning" }
                "^Review$" { "status-review" }
                default { "status-inactive" }
            }
            
            $html += @"
                    <tr>
                        <td>$($row.Solution)</td>
                        <td class="$statusClass">$($row.Status)</td>
                        <td>$($row.ServicePlan)</td>
                        <td>$($row.TotalSeats)</td>
                        <td>$($row.Consumed)</td>
                        <td>$($row.Unused)</td>
                        <td>$($row.SourceSKU)</td>
                    </tr>
"@
        }
        $html += "</tbody></table>"
    } else {
        $html += '<div class="no-data">No defensive stack data available</div>'
    }

    $html += @"
        </div>

        <div class="footer">
            Generated by Microsoft Audit Tracker (MAT) | Cloud Response & Auditing Utility<br>
            Creator: M. Decayette (IronBranded) | "To be prepared is half the victory"
        </div>
    </div>
</body>
</html>
"@

    return $html
}

function Invoke-SuperAuditor {
    if (-not $script:MAT_Global.IsConnected) { 
        Write-Host "`n[!] Connection Required." -ForegroundColor Red
        Write-Host "[!] Please use option [C] to connect to a tenant first." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return 
    }

    Write-Host "`n[*] Initiating Super Auditor Mode - Full Spectrum Analysis..." -ForegroundColor Cyan
    Write-Host "[*] Target Tenant: $($script:MAT_Global.TenantName)" -ForegroundColor White
    Write-Host "[*] Authenticated User: $($script:MAT_Global.UserPrincipal)" -ForegroundColor White
    Write-Host ""
    
    $reportPath = Get-MATReportPath -TenantName $script:MAT_Global.TenantName
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $timeStampDisplay = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $superAuditFolder = Join-Path $reportPath "SuperAudit_$timestamp"
    
    try {
        # Create dedicated folder for this super audit
        if (-not (Test-Path $superAuditFolder)) {
            New-Item -ItemType Directory -Path $superAuditFolder -Force | Out-Null
        }
        
        Write-Host "[1/6] Running Auditor Mode - Logging Health Check..." -ForegroundColor Cyan
        if (Get-Command Invoke-AuditorMode -ErrorAction SilentlyContinue) {
            Invoke-AuditorMode
        } else {
            Write-Host "    [!] Auditor Mode function not available" -ForegroundColor Yellow
        }
        
        Write-Host "[2/6] Running Protector Mode - Identity & Access Posture Audit..." -ForegroundColor Cyan
        if (Get-Command Invoke-ProtectorMode -ErrorAction SilentlyContinue) {
            Invoke-ProtectorMode
        } else {
            Write-Host "    [!] Protector Mode function not available" -ForegroundColor Yellow
        }
        
        Write-Host "[3/6] Running Licensor Mode - License Inventory..." -ForegroundColor Cyan
        Invoke-LicensorMode
        
        Write-Host "[4/6] Collecting Additional Tenant Information..." -ForegroundColor Cyan
        $auditorName = try { (Get-MgContext).Account } catch { "Unknown" }
        
        $tenantInfo = [PSCustomObject]@{
            TenantName = $script:MAT_Global.TenantName
            TenantID = $script:MAT_Global.TenantId
            Status = $script:MAT_Global.Status
            UserRole = $script:MAT_Global.UserRole
            AzureStatus = $script:MAT_Global.AzureStatus
            AuditDate = $timeStampDisplay
            AuditPerformedBy = $auditorName
        }
        
        $tenantInfoFile = Join-Path $superAuditFolder "Audit_Summary.csv"
        $tenantInfo | Export-Csv -Path $tenantInfoFile -NoTypeInformation
        
        Write-Host "[5/6] Consolidating Reports..." -ForegroundColor Cyan
        
        # Copy key report files
        $reportFiles = @(
            "Auditor_Report.csv",
            "Protector_Inventory.csv",
            "Defensive_Stack.csv",
            "Licenses_Inventory.csv"
        )
        
        foreach ($fileName in $reportFiles) {
            $sourceFile = Join-Path $reportPath $fileName
            if (Test-Path $sourceFile) {
                Copy-Item -Path $sourceFile -Destination $superAuditFolder -Force
                Write-Host "    [✓] Copied $fileName" -ForegroundColor Gray
            } else {
                Write-Host "    [!] Warning: $fileName not found" -ForegroundColor Yellow
            }
        }
        
        Write-Host "[6/6] Generating Executive HTML Report..." -ForegroundColor Cyan
        
        $htmlReport = New-SuperAuditorHTMLReport -ReportPath $superAuditFolder `
                                                   -TenantName $script:MAT_Global.TenantName `
                                                   -Auditor $auditorName `
                                                   -TimeStamp $timeStampDisplay
        
        $htmlFile = Join-Path $superAuditFolder "Executive_Audit_Report.html"
        $htmlReport | Out-File -FilePath $htmlFile -Encoding UTF8
        
        Write-MATLog -OperationName "SuperAuditor" -Details "Comprehensive audit completed. Reports in $superAuditFolder"
        
        Write-Host ""
        Write-Host "[✓] Super Audit Complete!" -ForegroundColor Green
        Write-Host "[+] All reports saved to:" -ForegroundColor Cyan
        Write-Host "    $superAuditFolder" -ForegroundColor White
        Write-Host "[+] Executive HTML Report:" -ForegroundColor Cyan
        Write-Host "    $htmlFile" -ForegroundColor Yellow
        Write-Host ""
        
    } catch {
        Write-Host "[!] ERROR during Super Audit: $($_.Exception.Message)" -ForegroundColor Red
        Write-MATLog -OperationName "SuperAuditor" -Details "ERROR: $($_.Exception.Message)"
    }
    
    Pause
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