function Write-MATLog {
    param (
        [string]$OperationName,
        [string]$Details
    )

    $logDir = Get-MATLogPath
    $tenant = if ($script:MAT_Global.TenantName) { $script:MAT_Global.TenantName } else { "UNKNOWN_TENANT" }
    $timestamp = (Get-Date).ToString("yyyy-MM-dd")
    $fileName = "${timestamp}_${tenant}_${OperationName}_OA.txt"
    $fullPath = Join-Path $logDir $fileName
    
    $logEntry = @"
================================================================================
TIMESTAMP   : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
OPERATOR    : $(Whoami)
AZURE USER  : $($script:MAT_Global.UserPrincipal)
OPERATION   : $OperationName
TENANT      : $tenant
STATUS      : SUCCESS
DETAILS     : $Details
================================================================================

"@
    Add-Content -Path $fullPath -Value $logEntry
}