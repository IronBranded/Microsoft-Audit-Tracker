function Write-MATLog {
    param (
        [Parameter(Mandatory=$true)]
        [string]$OperationName,

        [Parameter(Mandatory=$true)]
        [string]$Details,

        # Bug Fix #5: Status was hardcoded to "SUCCESS" regardless of what actually happened.
        # Callers can now pass "ERROR", "WARNING", etc. to produce accurate audit trails.
        [ValidateSet("SUCCESS","ERROR","WARNING","INFO")]
        [string]$Status = "SUCCESS"
    )

    $logDir    = Get-MATLogPath
    $tenant    = if ($script:MAT_Global.TenantName) { $script:MAT_Global.TenantName } else { "UNKNOWN_TENANT" }

    # Bug Fix #6: Tenant names can contain characters illegal in Windows/Linux file paths.
    # Strip them before constructing the file name so the write never silently fails.
    $safeTenant = $tenant -replace '[\\/:*?"<>|]', '_'

    $timestamp = (Get-Date).ToString("yyyy-MM-dd")
    $fileName  = "${timestamp}_${safeTenant}_${OperationName}_OA.txt"
    $fullPath  = Join-Path $logDir $fileName

    $logEntry = @"
================================================================================
TIMESTAMP   : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
OPERATOR    : $(Whoami)
AZURE USER  : $($script:MAT_Global.UserPrincipal)
OPERATION   : $OperationName
TENANT      : $tenant
STATUS      : $Status
DETAILS     : $Details
================================================================================

"@
    Add-Content -Path $fullPath -Value $logEntry
}
