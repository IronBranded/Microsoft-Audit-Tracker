function Initialize-MATState {
    $script:MAT_Global = @{
        Status          = "Disconnected" # Connected, Partial, Disconnected
        TenantName      = "DISCONNECTED"
        TenantId        = $null
        UserRole        = "Not Authenticated"
        UserPrincipal   = $null
        AzureStatus     = "Not Checked"
        IsConnected     = $false
        SessionStart    = Get-Date
    }
}