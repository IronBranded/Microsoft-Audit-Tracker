function Connect-MAT {
    Write-Host "`n[*] PURGING PREVIOUS SESSIONS..." -ForegroundColor Yellow
    
    # Force logout of all modules to prevent Tenant "Bleed-over"
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Disconnect-MgGraph -ErrorAction SilentlyContinue
    if (Get-Module -ListAvailable -Name Az.Accounts) {
        Disconnect-AzAccount -Confirm:$false -ErrorAction SilentlyContinue
    }
    
    # Clear internal state before new connection
    Initialize-MATState
    Write-Host "[*] Initiating Clean Connection..." -ForegroundColor Cyan

    try {
        # 1. Connect to Graph (Forces Login Prompt)
        Write-Host "[-] Authenticating with Microsoft Graph..." -ForegroundColor Gray
        Connect-MgGraph -Scopes "Directory.Read.All", "AuditLog.Read.All", "User.Read.All", "RoleManagement.Read.Directory" -ErrorAction Stop
        
        # Capture context and tenant information
        $ctx = Get-MgContext
        if (-not $ctx) {
            throw "Failed to establish Graph context"
        }

        # Get tenant information with error handling
        $tenantInfo = Get-MgOrganization -ErrorAction Stop | Select-Object -First 1
        if (-not $tenantInfo) {
            throw "Failed to retrieve tenant information"
        }
        
        # Update State with tenant and user information
        $script:MAT_Global.Status        = "Connected"
        $script:MAT_Global.IsConnected   = $true
        $script:MAT_Global.TenantName    = $tenantInfo.DisplayName
        $script:MAT_Global.TenantId      = $tenantInfo.Id
        $script:MAT_Global.UserPrincipal = $ctx.Account

        Write-Host "[+] Connected to tenant: $($tenantInfo.DisplayName)" -ForegroundColor Green
        Write-Host "[+] Authenticated as: $($ctx.Account)" -ForegroundColor Green

        # 2. Connect to Exchange
        Write-Host "[-] Connecting to Exchange Online..." -ForegroundColor Gray
        try {
            Connect-ExchangeOnline -ShowProgress $false -ErrorAction Stop
            Write-Host "[+] Exchange Online connected successfully" -ForegroundColor Green
        } catch {
            Write-Host "[!] Exchange Online connection failed: $_" -ForegroundColor Yellow
            Write-Host "[!] Some audit functions may be limited" -ForegroundColor Yellow
        }

        # 3. DYNAMIC M365 RBAC DETECTION
        Write-Host "[-] Analyzing M365 Permissions..." -ForegroundColor Gray
        try {
            $memberOf = Get-MgUserMemberOf -UserId $ctx.Account -All -ErrorAction Stop
            $roles = @()
            
            foreach ($r in $memberOf) { 
                if ($r.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.directoryRole") { 
                    $roleName = $r.AdditionalProperties["displayName"]
                    if ($roleName) {
                        $roles += $roleName
                    }
                } 
            }

            # Hierarchy logic for highest privilege (most permissive first)
            if ($roles -contains "Global Administrator") { 
                $m365Role = "Global Administrator" 
            }
            elseif ($roles -contains "Privileged Role Administrator") { 
                $m365Role = "Privileged Role Administrator" 
            }
            elseif ($roles -contains "Security Administrator") { 
                $m365Role = "Security Administrator" 
            }
            elseif ($roles -contains "Compliance Administrator") { 
                $m365Role = "Compliance Administrator" 
            }
            elseif ($roles -contains "Exchange Administrator") { 
                $m365Role = "Exchange Administrator" 
            }
            elseif ($roles -contains "Global Reader") { 
                $m365Role = "Global Reader" 
            }
            elseif ($roles -contains "Security Reader") { 
                $m365Role = "Security Reader" 
            }
            elseif ($roles.Count -gt 0) { 
                $m365Role = $roles[0]  # Use first detected role if none match hierarchy
            }
            else { 
                $m365Role = "Standard User" 
            }
            
            $script:MAT_Global.UserRole = $m365Role
            Write-Host "[+] M365 Role detected: $m365Role" -ForegroundColor Cyan
            
        } catch {
            Write-Host "[!] M365 role detection error: $_" -ForegroundColor Yellow
            $script:MAT_Global.UserRole = "Detection Failed"
        }

        # 4. DYNAMIC AZURE RBAC DETECTION
        Write-Host "[-] Analyzing Azure Permissions..." -ForegroundColor Gray
        $azRole = "No Access"
        
        if (Get-Module -ListAvailable -Name Az.Accounts) {
            try {
                # Connect to Azure with same account
                $azConn = Connect-AzAccount -AccountId $ctx.Account -ErrorAction Stop
                
                if ($azConn) {
                    Write-Host "[+] Azure connected successfully" -ForegroundColor Green
                    
                    # Get role assignments for the user
                    $assignments = Get-AzRoleAssignment -SignInName $ctx.Account -ErrorAction Stop
                    
                    if ($assignments) {
                        $azNames = $assignments.RoleDefinitionName | Select-Object -Unique
                        
                        # Hierarchy logic for highest privilege
                        if ($azNames -contains "Owner") { 
                            $azRole = "Owner" 
                        }
                        elseif ($azNames -contains "Contributor") { 
                            $azRole = "Contributor" 
                        }
                        elseif ($azNames -contains "User Access Administrator") { 
                            $azRole = "User Access Administrator" 
                        }
                        elseif ($azNames -contains "Reader") { 
                            $azRole = "Reader" 
                        }
                        elseif ($azNames.Count -gt 0) { 
                            $azRole = "Custom Access ($($azNames[0]))" 
                        }
                        
                        Write-Host "[+] Azure Role detected: $azRole" -ForegroundColor Cyan
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
            Write-Host "[!] Az.Accounts module not available" -ForegroundColor Yellow
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
        Write-Host "[!] Connection failed. Please verify credentials and permissions." -ForegroundColor Yellow
        
        # Reset state on failure
        Initialize-MATState
        
        Start-Sleep -Seconds 3
        Pause
    }
}
