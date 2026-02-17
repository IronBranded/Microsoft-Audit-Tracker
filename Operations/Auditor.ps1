function Invoke-AuditorMode {
    <#
    .SYNOPSIS
    Forensic Health Audit Mode
    
    .DESCRIPTION
    Analyzes tenant configuration for forensic readiness, including:
    - Unified Audit Log status
    - Mailbox auditing configuration
    - Entra ID diagnostic settings
    - Azure Activity Log export status
    #>
    
    if (-not $script:MAT_Global.IsConnected) { 
        Write-Host "`n[!] Connection Required." -ForegroundColor Red
        Write-Host "[!] Please use option [C] to connect to a tenant first." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return 
    }
    
    Write-Host "`n[*] Executing Forensic Health Audit..." -ForegroundColor Cyan
    Write-Host "[*] Target Tenant: $($script:MAT_Global.TenantName)" -ForegroundColor White
    Write-Host "[*] Authenticated User: $($script:MAT_Global.UserPrincipal)" -ForegroundColor White
    Write-Host ""
    
    $reportPath = Get-MATReportPath -TenantName $script:MAT_Global.TenantName
    $outFile = Join-Path $reportPath "Auditor_Report.csv"
    $auditResults = New-Object System.Collections.Generic.List[PSObject]

    # Standardized Row Helper (No Remediation Column)
    function Add-AuditRow ($Category, $Control, $Status, $Severity, $CurrentValue, $Risk) {
        $auditResults.Add([PSCustomObject]@{
            Category        = $Category
            Audit_Control   = $Control
            Status          = $Status
            Severity        = $Severity
            Current_Value   = $CurrentValue
            Forensic_Impact = $Risk
        })
    }

    # --- 1. M365 TENANT AUDITING ---
    Write-Host "[-] Auditing M365 Foundation..." -ForegroundColor Gray
    try {
        $ual = Get-AdminAuditLogConfig -ErrorAction Stop | Select-Object UnifiedAuditLogIngestionEnabled, AdminAuditLogAgeLimit
        $ualStatus = if($ual.UnifiedAuditLogIngestionEnabled) {"Healthy"} else {"CRITICAL"}
        Add-AuditRow "M365" "Unified Audit Log (UAL)" $ualStatus "Critical" "$($ual.UnifiedAuditLogIngestionEnabled)" `
            "Core evidence source. If disabled, there is zero visibility into M365 file/admin activity."

        Add-AuditRow "M365" "Admin Audit Log Retention" "Review" "Medium" "$($ual.AdminAuditLogAgeLimit)" `
            "Tracks Exchange-level configuration changes. Short retention limits historical scoping."
    } catch { 
        Write-Host "[!] Warning: Exchange audit query failed - $($_.Exception.Message)" -ForegroundColor Yellow
        Add-AuditRow "M365" "Core Auditing" "Error" "High" "Query Failed" "Check Exchange Online permissions."
    }

    # --- 2. ENTRA ID (IDENTITY) ---
    Write-Host "[-] Auditing Entra ID Telemetry..." -ForegroundColor Gray
    try {
        $entraDiag = Get-AzDiagnosticSetting -ResourceId "/providers/Microsoft.aadiam/diagnosticSettings" -ErrorAction SilentlyContinue
        if ($entraDiag) {
            Add-AuditRow "Identity" "Entra ID Diag Settings" "Healthy" "Low" "Enabled" `
                "Logs are streamed to external storage, extending investigation window beyond 30 days."
        } else {
            Add-AuditRow "Identity" "Entra ID Diagnostic Settings" "Warning" "High" "NOT CONFIGURED" `
                "Sign-in and Audit logs expire in 7-30 days. Critical for historical logs correlation. Validate that the logs are sent to a more long term storage."
        }
    } catch { 
        Write-Host "[!] Info: Entra ID diagnostic check requires Az.Monitor module" -ForegroundColor Yellow
        Add-AuditRow "Identity" "Entra ID Diagnostic" "Manual Check" "Medium" "Unknown" "Verify Azure Monitor permissions."
    }

    # --- 3. AZURE PLATFORM ---
    Write-Host "[-] Auditing Azure Activity..." -ForegroundColor Gray
    try {
        $azCtx = Get-AzContext -ErrorAction SilentlyContinue
        if ($null -ne $azCtx) {
            $subDiag = Get-AzDiagnosticSetting -ResourceId "/subscriptions/$($azCtx.Subscription.Id)" -ErrorAction SilentlyContinue
            if ($subDiag) {
                Add-AuditRow "Platform" "Azure Activity Export" "Healthy" "Low" "Active" `
                    "Evidence of infrastructure tampering (VM deletion, Network changes) is preserved."
            } else {
                Add-AuditRow "Platform" "Azure Activity Export" "Warning" "Medium" "90-Day Default" `
                    "Logs are only available for 90 days. Limits long-term persistence hunting."
            }
        } else {
            Add-AuditRow "Platform" "Azure Context" "Info" "Low" "Not Connected" `
                "Azure subscription context not available. Connect with Az.Accounts if needed."
        }
    } catch { 
        Write-Host "[!] Info: Azure activity check requires active Azure connection" -ForegroundColor Yellow
    }

    # --- 4. MAILBOX SECURITY ---
    Write-Host "[-] Auditing Mailbox Logging..." -ForegroundColor Gray
    try {
        $org = Get-OrganizationConfig -ErrorAction Stop | Select-Object AuditLogAgeLimit, AuditDisabled
        $mbxStatus = if ($org.AuditDisabled -eq $false) { "Healthy" } else { "CRITICAL" }
        Add-AuditRow "Mailbox" "Mailbox Auditing" $mbxStatus "High" "GlobalEnabled:$($org.AuditDisabled -eq $false)" `
            "Records MailBox operations and provide critical data for Business Email Compromise (BEC) response."
        
        Add-AuditRow "Mailbox" "Audit Log Age Limit" "Review" "Medium" "$($org.AuditLogAgeLimit)" `
            "Determines how long mailbox audit records are retained before deletion."
            
    } catch {
        Write-Host "[!] Warning: Mailbox audit query failed - $($_.Exception.Message)" -ForegroundColor Yellow
        Add-AuditRow "Mailbox" "Mailbox Auditing" "Error" "High" "Query Failed" "Verify Exchange Online permissions."
    }

    # --- OUTPUT ---
    Write-Host "`n[-] Generating report..." -ForegroundColor Gray
    $auditResults | Export-Csv -Path $outFile -NoTypeInformation
    
    # Log the operation
    Write-MATLog -OperationName "AuditorMode" -Details "Generated Auditor_Report.csv with forensic impact analysis."
    
    Write-Host "`n[✓] Audit Complete!" -ForegroundColor Green
    Write-Host "[+] Report saved to: $outFile" -ForegroundColor Cyan
    Write-Host "[+] Total checks: $($auditResults.Count)" -ForegroundColor White
    
    # Summary of critical findings
    $criticalCount = ($auditResults | Where-Object { $_.Status -eq "CRITICAL" }).Count
    $warningCount = ($auditResults | Where-Object { $_.Status -eq "Warning" }).Count
    
    if ($criticalCount -gt 0) {
        Write-Host "`n[!] CRITICAL FINDINGS: $criticalCount" -ForegroundColor Red
    }
    if ($warningCount -gt 0) {
        Write-Host "[!] WARNINGS: $warningCount" -ForegroundColor Yellow
    }
    
    Pause
}
