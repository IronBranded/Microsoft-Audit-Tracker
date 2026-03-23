function Initialize-MATState {
    <#
    .SYNOPSIS
    Initializes or resets the global MAT state object.
    .DESCRIPTION
    Called at startup, before new connections, and on connection failure.
    SkuCache / SkuCacheTime are reset here so a new tenant connection
    always fetches a fresh license catalog.
    #>
    $script:MAT_Global = @{
        Status        = "Disconnected"
        IsConnected   = $false
        TenantName    = "DISCONNECTED"
        TenantId      = $null
        UserPrincipal = "None"
        UserRole      = "Not Authenticated"
        AzureStatus   = "Not Checked"
        SkuCache      = $null      # Populated by Connect-MAT; reused by all audit modes
        SkuCacheTime  = $null      # DateTime stamp used to enforce 60-min cache TTL
    }
    Write-Verbose "MAT Global State initialized/reset"
}

function Get-MATConnectionStatus {
    return $script:MAT_Global.IsConnected
}

function Get-MATTenantInfo {
    return @{
        TenantName    = $script:MAT_Global.TenantName
        TenantId      = $script:MAT_Global.TenantId
        UserPrincipal = $script:MAT_Global.UserPrincipal
        M365Role      = $script:MAT_Global.UserRole
        AzureRole     = $script:MAT_Global.AzureStatus
        Status        = $script:MAT_Global.Status
    }
}

function Get-MATSkuData {
    <#
    .SYNOPSIS
    Returns tenant SKU data from cache, refreshing if stale or absent.
    .DESCRIPTION
    All audit modes call this helper instead of Get-MgSubscribedSku directly.
    Cache is valid for 60 minutes. On a refresh failure the stale cache is
    returned so in-progress audits are not interrupted by a transient Graph error.
    .OUTPUTS
    Array of MgSubscribedSku objects, or $null if data has never been fetched.
    #>
    $ageMin = if ($script:MAT_Global.SkuCacheTime) {
        ((Get-Date) - $script:MAT_Global.SkuCacheTime).TotalMinutes
    } else { 999 }

    if ($script:MAT_Global.SkuCache -and $ageMin -lt 60) {
        Write-Verbose "Get-MATSkuData: cache hit (age: $([math]::Round($ageMin,1)) min)"
        return $script:MAT_Global.SkuCache
    }

    try {
        Write-Verbose "Get-MATSkuData: refreshing from Graph"
        $skus = Get-MgSubscribedSku `
            -Property SkuPartNumber, SkuId, PrepaidUnits, ConsumedUnits, ServicePlans `
            -ErrorAction Stop
        $script:MAT_Global.SkuCache     = $skus
        $script:MAT_Global.SkuCacheTime = Get-Date
        return $skus
    } catch {
        Write-Host "[!] SKU cache refresh failed: $($_.Exception.Message)" -ForegroundColor Yellow
        if ($script:MAT_Global.SkuCache) {
            Write-Host "[!] Returning stale SKU cache." -ForegroundColor Yellow
            return $script:MAT_Global.SkuCache
        }
        return $null
    }
}
