function Connect-MAT {
    Write-Host "`n[*] Initiating Secure Connection..." -ForegroundColor Cyan
    
    try {
        # 1. Connect to Graph
        Write-Host "[-] Connecting to Microsoft Graph..." -ForegroundColor Gray
        Connect-MgGraph -Scopes "Directory.Read.All", "AuditLog.Read.All", "Policy.Read.All", "SecurityEvents.Read.All", "RoleManagement.Read.Directory", "User.Read" -ErrorAction Stop
        
        $ctx = Get-MgContext
        $tenantInfo = Get-MgOrganization | Select-Object -First 1
        
        # 2. Connect to Exchange Online
        Write-Host "[-] Connecting to Exchange Online..." -ForegroundColor Gray
        Connect-ExchangeOnline -ShowProgress $false -ErrorAction Stop

        # 3. Update Basic State
        $script:MAT_Global.Status = "Connected"
        $script:MAT_Global.IsConnected = $true
        $script:MAT_Global.TenantName = $tenantInfo.DisplayName
        $script:MAT_Global.TenantId = $tenantInfo.Id
        $script:MAT_Global.UserPrincipal = $ctx.Account

        # --- NEW: ADVANCED ROLE DETECTION (M365) ---
        Write-Host "[-] Resolving M365 Privileges..." -ForegroundColor Gray
        $m365Role = "User"
        
        # Get Directory Roles via MemberOf for accuracy
        $memberOf = Get-MgUserMemberOf -UserId $ctx.Account -All
        $roleEntries = foreach ($entry in $memberOf) {
            # Filter for Directory Roles specifically
            if ($entry.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.directoryRole") {
                $entry.AdditionalProperties["displayName"]
            }
        }

        if ($roleEntries -contains "Global Administrator") { $m365Role = "Global Admin" }
        elseif ($roleEntries -contains "Security Administrator") { $m365Role = "Security Admin" }
        elseif ($roleEntries -contains "Exchange Administrator") { $m365Role = "Exchange Admin" }
        elseif ($roleEntries.Count -gt 0) { $m365Role = $roleEntries[0] } # Fallback to first role found

        $script:MAT_Global.UserRole = $m365Role

        # --- NEW: AZURE ROLE DETECTION ---
        Write-Host "[-] Resolving Azure Privileges..." -ForegroundColor Gray
        $azRole = "No Access"
        
        # Check if Az.Accounts is actually loaded before trying
        if (Get-Module -ListAvailable -Name Az.Accounts) {
            try {
                # Attempt to connect to Azure if not already
                $azCtx = Get-AzContext -ErrorAction SilentlyContinue
                if (-not $azCtx) { Connect-AzAccount -ErrorAction SilentlyContinue }
                
                $assignments = Get-AzRoleAssignment -SignInName $ctx.Account -ErrorAction SilentlyContinue
                if ($assignments.RoleDefinitionName -contains "Owner") { $azRole = "Owner" }
                elseif ($assignments.RoleDefinitionName -contains "Contributor") { $azRole = "Contributor" }
                elseif ($assignments.RoleDefinitionName -contains "Reader") { $azRole = "Reader" }
            } catch { $azRole = "Auth Limited" }
        } else {
            $azRole = "Module Missing"
        }

        $script:MAT_Global.AzureStatus = $azRole
        Write-Host "[+] Connection Successful." -ForegroundColor Green
        Start-Sleep -Seconds 1

    } catch {
        Write-Host "[!] Connection Failed: $_" -ForegroundColor Red
        $script:MAT_Global.Status = "Not connected"
        Pause
    }
}

function Disconnect-MAT {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Disconnect-MgGraph -ErrorAction SilentlyContinue
    if (Get-Module -ListAvailable -Name Az.Accounts) { Disconnect-AzAccount -ErrorAction SilentlyContinue }
    
    Initialize-MATState 
    Write-Host "[*] Sessions Disconnected." -ForegroundColor Green
    Start-Sleep -Seconds 1
}