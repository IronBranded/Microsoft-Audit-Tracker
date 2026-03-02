function Initialize-MATState {
    <#
    .SYNOPSIS
    Initializes or resets the global MAT state object
    
    .DESCRIPTION
    Creates a clean state with disconnected status. This is called:
    - At script startup
    - Before new connections (to prevent tenant bleed-over)
    - When connection attempts fail
    #>
    
    $script:MAT_Global = @{
        Status        = "Disconnected"
        IsConnected   = $false
        TenantName    = "DISCONNECTED"
        TenantId      = $null
        UserPrincipal = "None"
        UserRole      = "Not Authenticated"
        AzureStatus   = "Not Checked"
    }
    
    # Verbose output for debugging if needed
    Write-Verbose "MAT Global State Initialized/Reset"
}

function Get-MATConnectionStatus {
    <#
    .SYNOPSIS
    Returns the current connection status
    
    .DESCRIPTION
    Utility function to check if MAT is connected to a tenant
    
    .OUTPUTS
    Boolean indicating connection status
    #>
    
    return $script:MAT_Global.IsConnected
}

function Get-MATTenantInfo {
    <#
    .SYNOPSIS
    Returns current tenant information
    
    .DESCRIPTION
    Returns a hashtable with current tenant details
    
    .OUTPUTS
    Hashtable with tenant information
    #>
    
    return @{
        TenantName    = $script:MAT_Global.TenantName
        TenantId      = $script:MAT_Global.TenantId
        UserPrincipal = $script:MAT_Global.UserPrincipal
        M365Role      = $script:MAT_Global.UserRole
        AzureRole     = $script:MAT_Global.AzureStatus
        Status        = $script:MAT_Global.Status
    }
}
