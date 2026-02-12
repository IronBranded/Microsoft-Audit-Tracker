function Invoke-AuditorMode {
    if (-not $script:MAT_Global.IsConnected) { Write-Host "[!] Connect first." -ForegroundColor Red; return }
    
    Write-Host "[*] Executing Forensic Health Audit..." -ForegroundColor Cyan
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
        $ual = Get-AdminAuditLogConfig | Select-Object UnifiedAuditLogIngestionEnabled, AdminAuditLogAgeLimit
        $ualStatus = if($ual.UnifiedAuditLogIngestionEnabled) {"Healthy"} else {"CRITICAL"}
        Add-AuditRow "M365" "Unified Audit Log (UAL)" $ualStatus "Critical" "$($ual.UnifiedAuditLogIngestionEnabled)" `
            "Core evidence source. If disabled, there is zero visibility into M365 file/admin activity."

        Add-AuditRow "M365" "Admin Audit Log Retention" "Review" "Medium" "$($ual.AdminAuditLogAgeLimit)" `
            "Tracks Exchange-level configuration changes. Short retention limits historical scoping."
    } catch { 
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
            Add-AuditRow "Identity" "Entra ID Diag Settings" "Warning" "High" "NOT CONFIGURED" `
                "Sign-in and Audit logs expire in 7-30 days. Critical for Patient Zero identification."
        }
    } catch { 
        Add-AuditRow "Identity" "Entra ID Diag" "Manual Check" "Medium" "Unknown" "Verify Azure Monitor permissions."
    }

    # --- 3. AZURE PLATFORM ---
    Write-Host "[-] Auditing Azure Activity..." -ForegroundColor Gray
    try {
        $azCtx = Get-AzContext
        if ($null -ne $azCtx) {
            $subDiag = Get-AzDiagnosticSetting -ResourceId "/subscriptions/$($azCtx.Subscription.Id)" -ErrorAction SilentlyContinue
            if ($subDiag) {
                Add-AuditRow "Platform" "Azure Activity Export" "Healthy" "Low" "Active" `
                    "Evidence of infrastructure tampering (VM deletion, Network changes) is preserved."
            } else {
                Add-AuditRow "Platform" "Azure Activity Export" "Warning" "Medium" "90-Day Default" `
                    "Logs are only available for 90 days. Limits long-term persistence hunting."
            }
        }
    } catch { }

    # --- 4. MAILBOX SECURITY ---
    Write-Host "[-] Auditing Mailbox Logging..." -ForegroundColor Gray
    try {
        $org = Get-OrganizationConfig | Select-Object AuditLogAgeLimit, AuditDisabled
        $mbxStatus = if ($org.AuditDisabled -eq $false) { "Healthy" } else { "CRITICAL" }
        Add-AuditRow "Mailbox" "Mailbox Auditing" $mbxStatus "High" "GlobalEnabled:$($org.AuditDisabled -eq $false)" `
            "Critical for BEC. Required to see if 'MailItemsAccessed' was triggered by an attacker."
    } catch { }

    # --- OUTPUT ---
    $auditResults | Export-Csv -Path $outFile -NoTypeInformation
    Write-MATLog -OperationName "AuditorMode" -Details "Generated Auditor_Report.csv with forensic impact analysis."
    Write-Host "`n[✔] Audit Complete. Report: $outFile" -ForegroundColor Green
}
