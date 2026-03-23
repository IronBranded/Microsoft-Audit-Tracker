function Connect-MAT {
    Write-Host "`n[*] PURGING PREVIOUS SESSIONS..." -ForegroundColor Yellow

    # Disconnect all services from the PREVIOUS session before resetting state.
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Disconnect-MgGraph -ErrorAction SilentlyContinue
    if (Get-Module -Name Az.Accounts -ErrorAction SilentlyContinue) {
        Disconnect-AzAccount -Confirm:$false -ErrorAction SilentlyContinue
    }

    Initialize-MATState
    Write-Host "[*] Initiating Clean Connection..." -ForegroundColor Cyan

    try {
        Write-Host "[-] Authenticating with Microsoft Graph..." -ForegroundColor Gray

        Connect-MgGraph -Scopes `
            "Directory.Read.All",
            "AuditLog.Read.All",
            "User.Read.All",
            "RoleManagement.Read.Directory",
            "Policy.Read.All",
            "Reports.Read.All" `
            -ErrorAction Stop

        $ctx = Get-MgContext
        if (-not $ctx) { throw "Graph context is null after successful authentication." }

        # ── TENANT NAME RESOLUTION ─────────────────────────────────────────────
        $tenantInfo = Get-MgOrganization -Property DisplayName, Id -ErrorAction Stop |
                      Select-Object -First 1

        if ($tenantInfo -and [string]::IsNullOrWhiteSpace($tenantInfo.DisplayName)) {
            Write-Verbose "DisplayName was null with -Property; retrying without -Property"
            $tenantInfo = Get-MgOrganization -ErrorAction Stop | Select-Object -First 1
        }

        if (-not $tenantInfo) { throw "Get-MgOrganization returned no results." }

        $script:MAT_Global.Status      = "Connected"
        $script:MAT_Global.IsConnected = $true
        $script:MAT_Global.TenantId    = $tenantInfo.Id

        $script:MAT_Global.TenantName =
            if (-not [string]::IsNullOrWhiteSpace($tenantInfo.DisplayName)) {
                $tenantInfo.DisplayName.Trim()
            } elseif (-not [string]::IsNullOrWhiteSpace($tenantInfo.Id)) {
                "Tenant-$($tenantInfo.Id.Substring(0,8))"
            } else {
                "Unknown Tenant"
            }

        $script:MAT_Global.UserPrincipal = $ctx.Account

        Write-Host "[+] Connected to tenant : $($script:MAT_Global.TenantName)" -ForegroundColor Green
        Write-Host "[+] Authenticated as    : $($ctx.Account)" -ForegroundColor Green

        # Pre-warm SKU cache
        Write-Host "[-] Pre-caching license data..." -ForegroundColor Gray
        try {
            $script:MAT_Global.SkuCache     = Get-MgSubscribedSku `
                -Property SkuPartNumber, SkuId, PrepaidUnits, ConsumedUnits, ServicePlans `
                -ErrorAction Stop
            $script:MAT_Global.SkuCacheTime = Get-Date
            Write-Host "[+] License cache ready ($($script:MAT_Global.SkuCache.Count) SKUs)" -ForegroundColor Green
        } catch {
            Write-Host "[!] SKU pre-cache failed — modes will fetch on-demand: $_" -ForegroundColor Yellow
        }

        # Exchange Online
        Write-Host "[-] Connecting to Exchange Online as $($ctx.Account)..." -ForegroundColor Gray
        try {
            Connect-ExchangeOnline -UserPrincipalName $ctx.Account -ShowProgress $false -ErrorAction Stop
            Write-Host "[+] Exchange Online connected" -ForegroundColor Green
        } catch {
            Write-Host "[!] Exchange Online connection failed: $_" -ForegroundColor Yellow
            Write-Host "[!] Auditor and Copilot telemetry checks will be limited." -ForegroundColor Yellow
        }

        # M365 RBAC detection
        Write-Host "[-] Analyzing M365 Permissions..." -ForegroundColor Gray
        try {
            $memberOf = Get-MgUserMemberOf -UserId $ctx.Account -All -ErrorAction Stop
            $roles    = @()
            foreach ($r in $memberOf) {
                if ($r.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.directoryRole") {
                    $n = $r.AdditionalProperties["displayName"]
                    if (-not [string]::IsNullOrWhiteSpace($n)) { $roles += $n }
                }
            }

            $m365Role = if     ($roles -contains "Global Administrator")          { "Global Administrator" }
                        elseif ($roles -contains "Privileged Role Administrator") { "Privileged Role Administrator" }
                        elseif ($roles -contains "Security Administrator")        { "Security Administrator" }
                        elseif ($roles -contains "Compliance Administrator")      { "Compliance Administrator" }
                        elseif ($roles -contains "Compliance Data Administrator") { "Compliance Data Administrator" }
                        elseif ($roles -contains "Exchange Administrator")        { "Exchange Administrator" }
                        elseif ($roles -contains "Reports Reader")                { "Reports Reader" }
                        elseif ($roles -contains "Global Reader")                 { "Global Reader" }
                        elseif ($roles -contains "Security Reader")               { "Security Reader" }
                        elseif ($roles.Count -gt 0)                               { $roles[0] }
                        else                                                      { "Standard User" }

            $script:MAT_Global.UserRole = $m365Role
            Write-Host "[+] M365 Role detected: $m365Role" -ForegroundColor Cyan

        } catch {
            Write-Host "[!] M365 role detection error: $_" -ForegroundColor Yellow
            $script:MAT_Global.UserRole = "Detection Failed"
        }

        # Azure RBAC detection
        Write-Host "[-] Analyzing Azure Permissions..." -ForegroundColor Gray
        $azRole = "No Access"

        if (Get-Module -ListAvailable -Name Az.Accounts -ErrorAction SilentlyContinue) {
            try {
                $azConn = Connect-AzAccount -AccountId $ctx.Account -ErrorAction Stop
                if ($azConn) {
                    Write-Host "[+] Azure connected" -ForegroundColor Green
                    $assignments = Get-AzRoleAssignment -SignInName $ctx.Account -ErrorAction Stop
                    if ($assignments) {
                        $azNames = $assignments.RoleDefinitionName | Select-Object -Unique
                        $azRole  = if     ($azNames -contains "Owner")                     { "Owner" }
                                   elseif ($azNames -contains "Contributor")               { "Contributor" }
                                   elseif ($azNames -contains "User Access Administrator") { "User Access Administrator" }
                                   elseif ($azNames -contains "Monitoring Contributor")    { "Monitoring Contributor" }
                                   elseif ($azNames -contains "Monitoring Reader")         { "Monitoring Reader" }
                                   elseif ($azNames -contains "Reader")                   { "Reader" }
                                   elseif ($azNames.Count -gt 0)                          { "Custom ($($azNames[0]))" }
                                   else                                                    { "No Assignments" }
                        Write-Host "[+] Azure Role: $azRole" -ForegroundColor Cyan

                        if ($azRole -eq "Reader") {
                            Write-Host "[!] Note: Entra ID diagnostic endpoint requires Monitoring Reader, not just Reader." -ForegroundColor Yellow
                        }
                    } else {
                        $azRole = "No Assignments"
                        Write-Host "[!] No Azure role assignments found" -ForegroundColor Yellow
                    }
                }
            } catch {
                Write-Host "[!] Azure detection error: $_" -ForegroundColor Yellow
                $azRole = "Auth Limited"
            }
        } else {
            Write-Host "[!] Az.Accounts not installed — Azure checks unavailable" -ForegroundColor Yellow
            $azRole = "Module Not Installed"
        }

        $script:MAT_Global.AzureStatus = $azRole

        Write-Host "`n[+] CONNECTION SUCCESSFUL" -ForegroundColor Green
        Write-Host "    Tenant  : $($script:MAT_Global.TenantName)" -ForegroundColor White
        Write-Host "    User    : $($script:MAT_Global.UserPrincipal)" -ForegroundColor White
        Write-Host "    M365    : $($script:MAT_Global.UserRole)" -ForegroundColor Cyan
        Write-Host "    Azure   : $($script:MAT_Global.AzureStatus)" -ForegroundColor Cyan

        Start-Sleep -Seconds 3

    } catch {
        Write-Host "`n[!] CONNECTION ERROR: $_" -ForegroundColor Red
        Write-Host "[!] Connection failed. Verify credentials and permissions." -ForegroundColor Yellow

        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue

        Initialize-MATState

        Start-Sleep -Seconds 3
        Pause
    }
}
