function Invoke-SuperAuditor {
    if (-not $script:MAT_Global.IsConnected) { Write-Host "[!] Connect first." -ForegroundColor Red; Start-Sleep 2; return }
    
    Write-Host "[*] STARTING SUPER AUDITOR..." -ForegroundColor Yellow
    
    Invoke-AuditorMode
    Invoke-ProtectorMode
    Invoke-LicensorMode
    
    Write-MATLog -OperationName "SuperAuditor" -Details "Full spectrum audit executed (1+2+3)"
    
    Write-Host ""
    Write-Host "SUPER AUDITOR COMPLETE." -ForegroundColor Green
    Write-Host "All reports generated in the timestamped folder." -ForegroundColor Gray
    Pause
}