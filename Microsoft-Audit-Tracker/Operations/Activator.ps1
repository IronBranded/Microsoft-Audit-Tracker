function Invoke-ActivatorMode {
    if (-not $script:MAT_Global.IsConnected) { Write-Host "[!] Connect first." -ForegroundColor Red; Start-Sleep 2; return }
    if ($script:MAT_Global.UserRole -notmatch "Global Administrator") {
        Write-Host "[!] ACCESS DENIED. Global Administrator/Compliance Administrator required." -ForegroundColor Red
        Start-Sleep 2
        return
    }

    Write-Host "========================================================" -ForegroundColor Red
    Write-Host " WARNING: ACTIVATOR MODE" -ForegroundColor Red
    Write-Host " This will ENABLE Unified Audit Logging for the tenant." -ForegroundColor Yellow
    Write-Host " This change is visible to other admins." -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Red
    
    $confirm = Read-Host "Type 'ENABLE-UAL' to proceed"
    if ($confirm -eq "ENABLE-UAL") {
        Write-Host "[*] Attempting to enable UAL..." -ForegroundColor Cyan
        try {
            Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true -ErrorAction Stop
            Write-Host "[+] Command sent successfully." -ForegroundColor Green
            Write-Host "[!] Note: It may take up to 60 minutes for changes to propagate." -ForegroundColor Yellow
            Write-MATLog -OperationName "ActivatorMode" -Details "Enabled Unified Audit Log"
        } catch {
            Write-Host "[!] Failed: $_" -ForegroundColor Red
            if ($_ -match "Enable-OrganizationCustomization") {
                Write-Host "Tip: You may need to run Enable-OrganizationCustomization first." -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "[!] Cancelled." -ForegroundColor Yellow
    }
    Write-Host "Validate if ACTIVATOR mode was successful using Auditor Mode [1]." -ForegroundColor Cyan
    Pause
}