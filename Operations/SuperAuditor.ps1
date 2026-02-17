# ================================================================================
# MODULE: SuperAuditor.ps1
# DESCRIPTION: Orchestrates full spectrum audit and generates executive HTML report
# VERSION: 1.0 
# ================================================================================

function Invoke-SuperAuditor {
    <#
    .SYNOPSIS
    Executes comprehensive security audit across all MAT modules
    
    .DESCRIPTION
    Runs Auditor, Protector, and Licensor modes in sequence, then generates
    a consolidated executive HTML dashboard combining all findings.
    #>
    
    if (-not $script:MAT_Global.IsConnected) { 
        Write-Host "`n[!] Connection Required." -ForegroundColor Red
        Write-Host "[!] Please use option [C] to connect to a tenant first." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return 
    }
    
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  SUPER AUDITOR - COMPREHENSIVE SECURITY ASSESSMENT" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[*] Target Tenant    : $($script:MAT_Global.TenantName)" -ForegroundColor White
    Write-Host "[*] Authenticated As : $($script:MAT_Global.UserPrincipal)" -ForegroundColor White
    Write-Host "[*] M365 Role        : $($script:MAT_Global.UserRole)" -ForegroundColor Cyan
    Write-Host "[*] Azure Role       : $($script:MAT_Global.AzureStatus)" -ForegroundColor Cyan
    Write-Host ""
    
    # Confirm execution
    Write-Host "[!] This will run ALL audit operations and may take several minutes." -ForegroundColor Yellow
    $confirm = Read-Host "Continue? (Y/N)"
    
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-Host "[!] Super Audit cancelled." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }
    
    $startTime = Get-Date
    
    # 1. Resolve Tenant Identity for pathing
    $tenantName = $script:MAT_Global.TenantName
    if ([string]::IsNullOrWhiteSpace($tenantName) -or $tenantName -eq "DISCONNECTED") {
        Write-Host "[!] Warning: Using fallback tenant name" -ForegroundColor Yellow
        $tenantName = "Unknown_Tenant"
    }

    # 2. Calculate paths using MAT structure
    $targetPath = Get-MATReportPath -TenantName $tenantName
    Write-Host "[+] Report Directory: $targetPath" -ForegroundColor Gray
    Write-Host ""

    # 3. Execute Operational Modes with error handling
    $successCount = 0
    $totalModes = 3
    
    # Mode 1: Auditor
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host " [1/3] AUDITOR MODE - Forensic Health Check" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
    try {
        Invoke-AuditorMode
        $successCount++
        Write-Host "[✓] Auditor Mode completed successfully" -ForegroundColor Green
    } catch {
        Write-Host "[✗] Auditor Mode failed: $_" -ForegroundColor Red
    }
    Write-Host ""
    
    # Mode 2: Protector
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host " [2/3] PROTECTOR MODE - Security Posture Assessment" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
    try {
        Invoke-ProtectorMode
        $successCount++
        Write-Host "[✓] Protector Mode completed successfully" -ForegroundColor Green
    } catch {
        Write-Host "[✗] Protector Mode failed: $_" -ForegroundColor Red
    }
    Write-Host ""
    
    # Mode 3: Licensor
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host " [3/3] LICENSOR MODE - License & Defensive Stack Analysis" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
    try {
        Invoke-LicensorMode
        $successCount++
        Write-Host "[✓] Licensor Mode completed successfully" -ForegroundColor Green
    } catch {
        Write-Host "[✗] Licensor Mode failed: $_" -ForegroundColor Red
    }
    Write-Host ""
    
    # 4. Generate the Executive HTML Dashboard
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host " GENERATING EXECUTIVE DASHBOARD..." -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
    
    try {
        $htmlPath = New-MATHtmlReport -ReportDirectory $targetPath -TenantName $tenantName
        Write-Host "[✓] Executive HTML Report generated" -ForegroundColor Green
        Write-Host "[+] Location: $htmlPath" -ForegroundColor Cyan
    } catch {
        Write-Host "[✗] HTML generation failed: $_" -ForegroundColor Red
        $htmlPath = $null
    }
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).ToString("mm\:ss")
    
    # 5. Final Summary
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  SUPER AUDIT COMPLETE" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Tenant          : $tenantName" -ForegroundColor White
    Write-Host "  Operations      : $successCount/$totalModes successful" -ForegroundColor $(if ($successCount -eq $totalModes) {"Green"} else {"Yellow"})
    Write-Host "  Duration        : $duration" -ForegroundColor White
    Write-Host "  Report Location : $targetPath" -ForegroundColor Cyan
    
    if ($htmlPath) {
        Write-Host ""
        Write-Host "   Executive Dashboard: " -NoNewline -ForegroundColor White
        Write-Host "$htmlPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   Tip: Open the HTML file in your browser for interactive dashboard" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    
    # Log the operation
    Write-MATLog -OperationName "SuperAuditor" -Details "Full spectrum audit executed ($successCount/$totalModes successful). Duration: $duration. HTML: $htmlPath"
    
    Pause
}

function New-MATHtmlReport {
    <#
    .SYNOPSIS
    Generates executive HTML dashboard from audit reports
    
    .DESCRIPTION
    Combines all MAT audit outputs into a single, styled HTML executive report
    with conditional formatting and professional presentation.
    
    .PARAMETER ReportDirectory
    Directory containing the CSV reports to consolidate
    
    .PARAMETER TenantName
    Name of the audited tenant (for display)
    
    .OUTPUTS
    String path to the generated HTML file
    #>
    
    param (
        [Parameter(Mandatory=$true)]
        [string]$ReportDirectory,
        
        [string]$TenantName = "Unknown Tenant"
    )

    # Metadata
    $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $currentUser = $script:MAT_Global.UserPrincipal
    if ([string]::IsNullOrWhiteSpace($currentUser) -or $currentUser -eq "None") {
        $currentUser = [Environment]::UserName
    }
    
    $htmlFileName = "MAT_Executive_Report_$((Get-Date).ToString('yyyyMMdd_HHmmss')).html"
    $destinationPath = Join-Path -Path $ReportDirectory -ChildPath $htmlFileName

    # Helper function to convert CSV data to HTML rows with conditional formatting
    function Get-HtmlTableRows {
        param(
            [string]$CsvPath,
            [int]$MaxColumns = 10
        )
        
        if (-not (Test-Path $CsvPath)) {
            return "<tr><td colspan='$MaxColumns' style='text-align:center; color:#8b949e; padding:30px;'>📋 Report component not found or not yet generated.</td></tr>"
        }
        
        try {
            $data = Import-Csv $CsvPath -ErrorAction Stop
            
            if ($data.Count -eq 0) { 
                return "<tr><td colspan='$MaxColumns' style='text-align:center; color:#8b949e; padding:30px;'>✓ No significant findings recorded.</td></tr>" 
            }
            
            $rows = foreach ($item in $data) {
                $row = "<tr>"
                foreach ($prop in $item.PSObject.Properties) {
                    $value = $prop.Value
                    $propName = $prop.Name
                    $style = ""
                    
                    # Conditional styling based on content
                    if ($value -match "CRITICAL|Fail|Failed|Error|Disabled|Not Found|Not Licensed|High Risk") { 
                        $style = "style='color: #ff7b72; font-weight: 600;'" 
                    }
                    elseif ($value -match "Warning|Medium|Review|Optimizable|Auth Limited") { 
                        $style = "style='color: #d29922; font-weight: 500;'" 
                    }
                    elseif ($value -match "Success|Pass|Healthy|Enabled|Licensed|Active|Connected|Low") { 
                        $style = "style='color: #3fb950; font-weight: 500;'" 
                    }
                    elseif ($value -match "Info|Manual|Unknown") {
                        $style = "style='color: #58a6ff;'"
                    }
                    
                    # Smart truncation - don't truncate description/impact columns
                    $noTruncateColumns = @("Forensic_Impact", "Description", "Notes", "Details", "Impact", "Forensic Impact", "Current_Value")
                    if ($value.Length -gt 200 -and $propName -notin $noTruncateColumns) {
                        $value = $value.Substring(0, 197) + "..."
                    }
                    
                    # HTML escape to prevent injection
                    $value = [System.Net.WebUtility]::HtmlEncode($value)
                    
                    $row += "<td $style>$value</td>"
                }
                $row += "</tr>"
                $row
            }
            return $rows -join "`n"
            
        } catch {
            return "<tr><td colspan='$MaxColumns' style='text-align:center; color:#ff7b72; padding:30px;'>⚠️ Error reading report: $_</td></tr>"
        }
    }

    # Helper function to get CSV headers for dynamic table headers
    function Get-CsvHeaders {
        param([string]$CsvPath)
        
        if (-not (Test-Path $CsvPath)) { return @() }
        
        try {
            $data = Import-Csv $CsvPath -ErrorAction Stop | Select-Object -First 1
            return $data.PSObject.Properties.Name
        } catch {
            return @()
        }
    }

    # Data Ingestion
    Write-Host "[-] Processing Auditor Report..." -ForegroundColor Gray
    $auditorPath = Join-Path $ReportDirectory "Auditor_Report.csv"
    $auditorHeaders = Get-CsvHeaders $auditorPath
    $auditorRows = Get-HtmlTableRows $auditorPath -MaxColumns ($auditorHeaders.Count)
    
    Write-Host "[-] Processing Protector Inventory..." -ForegroundColor Gray
    $protectorPath = Join-Path $ReportDirectory "Protector_Inventory.csv"
    $protectorHeaders = Get-CsvHeaders $protectorPath
    $protectorRows = Get-HtmlTableRows $protectorPath -MaxColumns ($protectorHeaders.Count)
    
    Write-Host "[-] Processing License Inventory..." -ForegroundColor Gray
    $licensorPath = Join-Path $ReportDirectory "Licenses_Inventory.csv"
    $licensorHeaders = Get-CsvHeaders $licensorPath
    $licensorRows = Get-HtmlTableRows $licensorPath -MaxColumns ($licensorHeaders.Count)
    
    Write-Host "[-] Processing Defensive Stack..." -ForegroundColor Gray
    $defensivePath = Join-Path $ReportDirectory "Defensive_Stack.csv"
    $defensiveHeaders = Get-CsvHeaders $defensivePath
    $defensiveRows = Get-HtmlTableRows $defensivePath -MaxColumns ($defensiveHeaders.Count)

    # Generate dynamic table headers
    $auditorHeaderHtml = ($auditorHeaders | ForEach-Object { "<th>$_</th>" }) -join ""
    $protectorHeaderHtml = ($protectorHeaders | ForEach-Object { "<th>$_</th>" }) -join ""
    $licensorHeaderHtml = ($licensorHeaders | ForEach-Object { "<th>$_</th>" }) -join ""
    $defensiveHeaderHtml = ($defensiveHeaders | ForEach-Object { "<th>$_</th>" }) -join ""

    # Calculate statistics
    $totalFindings = 0
    $criticalCount = 0
    $warningCount = 0
    
    if (Test-Path $auditorPath) {
        $auditorData = Import-Csv $auditorPath
        $totalFindings += $auditorData.Count
        $criticalCount += ($auditorData | Where-Object { $_.Status -match "CRITICAL" }).Count
        $warningCount += ($auditorData | Where-Object { $_.Status -match "Warning" }).Count
    }

    # Build HTML Report
    Write-Host "[-] Compiling HTML dashboard..." -ForegroundColor Gray
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Executive Audit Report | $TenantName</title>
    <style>
        :root { 
            --primary: #58a6ff; 
            --success: #3fb950;
            --warning: #d29922;
            --danger: #ff7b72;
            --bg: #0d1117; 
            --card: #161b22; 
            --text: #c9d1d9; 
            --border: #30363d; 
            --header-bg: #21262d;
            --muted: #8b949e;
        }
        
        * { box-sizing: border-box; margin: 0; padding: 0; }
        
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif;
            background-color: var(--bg); 
            color: var(--text); 
            line-height: 1.6;
            padding: 40px 20px;
        }
        
        .container { 
            max-width: 1400px; 
            margin: 0 auto; 
        }
        
        .header { 
            border-bottom: 2px solid var(--primary); 
            padding-bottom: 30px; 
            margin-bottom: 40px; 
            display: flex; 
            justify-content: space-between; 
            align-items: flex-start;
            flex-wrap: wrap;
            gap: 20px;
        }
        
        .header-title {
            flex: 1;
            min-width: 300px;
        }
        
        h1 { 
            color: var(--primary); 
            font-size: 36px; 
            font-weight: 700;
            letter-spacing: -0.5px; 
            margin-bottom: 8px;
        }
        
        .subtitle { 
            font-weight: 300; 
            font-size: 20px; 
            color: var(--muted);
        }
        
        .header-meta {
            text-align: right;
            min-width: 200px;
        }
        
        .classification { 
            color: var(--danger); 
            font-weight: 700; 
            font-size: 11px; 
            letter-spacing: 2px;
            text-transform: uppercase;
            margin-bottom: 8px;
        }
        
        .tagline { 
            font-size: 13px; 
            color: var(--muted);
        }
        
        .stats-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); 
            gap: 20px; 
            margin-bottom: 50px; 
        }
        
        .stat-card { 
            background: var(--card); 
            border: 1px solid var(--border); 
            padding: 24px; 
            border-radius: 12px;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        .stat-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 24px rgba(0,0,0,0.4);
        }
        
        .stat-label { 
            font-size: 11px; 
            text-transform: uppercase; 
            color: var(--muted); 
            margin-bottom: 10px; 
            font-weight: 600; 
            letter-spacing: 1px; 
        }
        
        .stat-value { 
            font-size: 24px; 
            color: #fff; 
            font-weight: 600;
            line-height: 1.2;
        }
        
        .stat-value.large {
            font-size: 32px;
        }
        
        .stat-sublabel {
            font-size: 12px;
            color: var(--muted);
            margin-top: 8px;
        }
        
        .section { 
            background: var(--card); 
            border: 1px solid var(--border); 
            border-radius: 12px; 
            margin-bottom: 40px; 
            overflow: hidden; 
            box-shadow: 0 4px 16px rgba(0,0,0,0.3); 
        }
        
        .section-header { 
            background: var(--header-bg); 
            padding: 24px 30px; 
            border-bottom: 1px solid var(--border); 
        }
        
        .section-number {
            display: inline-block;
            background: var(--primary);
            color: var(--bg);
            width: 28px;
            height: 28px;
            border-radius: 50%;
            text-align: center;
            line-height: 28px;
            font-weight: 700;
            font-size: 14px;
            margin-right: 12px;
        }
        
        .section-title { 
            font-size: 20px; 
            font-weight: 600; 
            color: #fff; 
            margin: 0;
            display: inline;
        }
        
        .section-desc { 
            font-size: 14px; 
            color: var(--muted); 
            margin-top: 8px;
            line-height: 1.5;
        }
        
        .table-container {
            overflow-x: auto;
        }
        
        table { 
            width: 100%; 
            border-collapse: collapse; 
            table-layout: auto;
        }
        
        th { 
            background: rgba(88, 166, 255, 0.08); 
            color: var(--primary); 
            text-align: left; 
            padding: 16px 20px; 
            font-size: 12px; 
            text-transform: uppercase; 
            font-weight: 600;
            border-bottom: 2px solid var(--border);
            position: sticky;
            top: 0;
            z-index: 10;
            white-space: nowrap;
        }
        
        td { 
            padding: 16px 20px; 
            font-size: 14px; 
            border-bottom: 1px solid var(--border);
            vertical-align: top;
            word-wrap: break-word;
            max-width: 500px;
        }
        
        /* Special handling for long text columns */
        td:nth-last-child(1),
        td:nth-last-child(2) {
            max-width: 400px;
            white-space: normal;
            line-height: 1.5;
        }
        
        tr:last-child td { 
            border-bottom: none; 
        }
        
        tbody tr:hover { 
            background: rgba(255,255,255,0.03); 
        }
        
        .footer { 
            text-align: center; 
            margin-top: 60px; 
            padding-top: 30px; 
            border-top: 1px solid var(--border); 
        }
        
        .footer-text {
            font-size: 13px; 
            color: var(--muted);
            margin-bottom: 8px;
        }
        
        .footer-legal {
            font-size: 11px;
            color: #484f58;
        }
        
        .badge {
            display: inline-block;
            padding: 4px 10px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .badge-critical { background: rgba(255, 123, 114, 0.15); color: var(--danger); }
        .badge-warning { background: rgba(210, 153, 34, 0.15); color: var(--warning); }
        .badge-success { background: rgba(63, 185, 80, 0.15); color: var(--success); }
        
        @media print {
            body { background: white; color: black; }
            .section { box-shadow: none; border: 1px solid #ddd; page-break-inside: avoid; }
            .stat-card { border: 1px solid #ddd; }
            td { max-width: none; }
        }
        
        @media (max-width: 768px) {
            .header { flex-direction: column; }
            .header-meta { text-align: left; }
            h1 { font-size: 28px; }
            .stats-grid { grid-template-columns: 1fr; }
            td { padding: 12px 10px; font-size: 13px; }
            th { padding: 12px 10px; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="header-title">
                <h1>Microsoft Audit Tracker</h1>
                <div class="subtitle">Executive Security Assessment Report</div>
            </div>
            <div class="header-meta">
                <div class="classification"> CONFIDENTIAL REPORT</div>
                <div class="tagline">Cloud Response & Auditing Utility</div>
            </div>
        </div>

        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-label"> Target Tenant</div>
                <div class="stat-value">$TenantName</div>
            </div>
            <div class="stat-card">
                <div class="stat-label"> Auditor Principal</div>
                <div class="stat-value" style="font-size: 18px;">$currentUser</div>
            </div>
            <div class="stat-card">
                <div class="stat-label"> Audit Timestamp</div>
                <div class="stat-value" style="font-size: 18px;">$timeStamp</div>
            </div>
            <div class="stat-card">
                <div class="stat-label"> Total Findings</div>
                <div class="stat-value large">$totalFindings</div>
                <div class="stat-sublabel">
                    <span class="badge badge-critical">Critical: $criticalCount</span>
                    <span class="badge badge-warning">Warnings: $warningCount</span>
                </div>
            </div>
        </div>

        <div class="section">
            <div class="section-header">
                <span class="section-number">1</span>
                <div class="section-title">Forensic Health Check (Auditor Mode)</div>
                <div class="section-desc">
                    Critical audit log configurations, retention policies, and evidence preservation capabilities. 
                    Identifies gaps in forensic visibility that could impair incident response and threat hunting operations.
                </div>
            </div>
            <div class="table-container">
                <table>
                    <thead>
                        <tr>$auditorHeaderHtml</tr>
                    </thead>
                    <tbody>$auditorRows</tbody>
                </table>
            </div>
        </div>

        <div class="section">
            <div class="section-header">
                <span class="section-number">2</span>
                <div class="section-title">Identity & Posture Check (Protector Mode)</div>
                <div class="section-desc">
                    Evaluation of identity protection controls including Conditional Access policies, Security Defaults, 
                    and authentication enforcement mechanisms. Critical for preventing unauthorized access and lateral movement.
                </div>
            </div>
            <div class="table-container">
                <table>
                    <thead>
                        <tr>$protectorHeaderHtml</tr>
                    </thead>
                    <tbody>$protectorRows</tbody>
                </table>
            </div>
        </div>

        <div class="section">
            <div class="section-header">
                <span class="section-number">3</span>
                <div class="section-title">Defensive Stack Analysis (Licensor Mode)</div>
                <div class="section-desc">
                    Deployment status and licensing of Microsoft Defender suite and Sentinel SIEM. 
                    Validates presence of detection and response capabilities across endpoint, email, identity, and cloud apps.
                </div>
            </div>
            <div class="table-container">
                <table>
                    <thead>
                        <tr>$defensiveHeaderHtml</tr>
                    </thead>
                    <tbody>$defensiveRows</tbody>
                </table>
            </div>
        </div>

        <div class="section">
            <div class="section-header">
                <span class="section-number">4</span>
                <div class="section-title">License & SKU Inventory (Licensor Mode)</div>
                <div class="section-desc">
                    Comprehensive Microsoft 365 license allocation analysis. Identifies unused capacity, 
                    optimization opportunities, and alignment with security service plan requirements.
                </div>
            </div>
            <div class="table-container">
                <table>
                    <thead>
                        <tr>$licensorHeaderHtml</tr>
                    </thead>
                    <tbody>$licensorRows</tbody>
                </table>
            </div>
        </div>

        <div class="footer">
            <div class="footer-text">
                <strong>Generated by Microsoft Audit Tracker (MAT)</strong><br>
                Cloud Response & Auditing Utility - Complete Report
            </div>
            <div class="footer-legal">
                This report contains confidential security information. Distribution limited to authorized personnel only.
            </div>
        </div>
    </div>
</body>
</html>
"@

    try {
        Set-Content -Path $destinationPath -Value $html -Encoding UTF8 -ErrorAction Stop
        Write-Host "[✓] HTML report written successfully" -ForegroundColor Green
        return $destinationPath
    } catch {
        Write-Host "[✗] Failed to write HTML report: $_" -ForegroundColor Red
        throw
    }
}