function Invoke-AuditorMode {
    if (-not $script:MAT_Global.IsConnected) { Write-Host "[!] Connect first." -ForegroundColor Red; Start-Sleep 2; return }
    
    Write-Host "[*] Running Auditor Mode..." -ForegroundColor Cyan
    
    $reportPath = Get-MATReportPath -TenantName $script:MAT_Global.TenantName
    $outFile = Join-Path $reportPath "Auditor_Report.csv"
    
    # FIX: Initialize as a dynamic List instead of a fixed-size array
    $auditResults = New-Object System.Collections.Generic.List[PSObject]
    
    # 1. Check UAL
    Write-Host "[-] Checking Unified Audit Log..." -ForegroundColor Gray
    try {
        $ualStatus = Get-AdminAuditLogConfig | Select-Object UnifiedAuditLogIngestionEnabled
        $auditResults.Add([PSCustomObject]@{
            Check = "Unified Audit Log"
            Status = if($ualStatus.UnifiedAuditLogIngestionEnabled) {"Enabled"} else {"DISABLED"}
            Details = "Critical for forensic visibility"
        })
    } catch {
        $auditResults.Add([PSCustomObject]@{ Check = "UAL"; Status = "Error"; Details = $_.Exception.Message })
    }

    # 2. Check Retention & Get Org Config
    Write-Host "[-] Checking Retention Policy..." -ForegroundColor Gray
    try {
        # Fetching AuditDisabled here so it's available for Section 3
        $orgConfig = Get-OrganizationConfig | Select-Object AuditLogAgeLimit, AuditDisabled
        $retention = if ($orgConfig.AuditLogAgeLimit) { $orgConfig.AuditLogAgeLimit } else { "Default (90 Days)" }
        $auditResults.Add([PSCustomObject]@{
            Check = "Audit Retention"
            Status = $retention
            Details = "Duration logs are kept"
        })
    } catch {
        $auditResults.Add([PSCustomObject]@{ Check = "Audit Retention"; Status = "Error"; Details = "Query failed" })
    }

    # 3. Mailbox Auditing
    Write-Host "[-] Checking Global Mailbox Auditing..." -ForegroundColor Gray
    try {
        # AuditDisabled = $false means Auditing is ON
        $mbxStatus = if ($orgConfig.AuditDisabled -eq $false) { "Enabled" } else { "Disabled" }
        $auditResults.Add([PSCustomObject]@{
            Check = "Mailbox Auditing"
            Status = $mbxStatus
            Details = "Global tenant-wide mailbox logging status"
        })
    } catch {
        $auditResults.Add([PSCustomObject]@{ Check = "Mailbox Auditing"; Status = "Error"; Details = "Query failed" })
    }

    # Output
    $auditResults | Export-Csv -Path $outFile -NoTypeInformation
    
    Write-MATLog -OperationName "AuditorMode" -Details "Generated Auditor_Report.csv"
    Write-Host "Operation [1] successful. See MAT Reports folder in Downloads." -ForegroundColor Green
    Start-Sleep -Seconds 3
}