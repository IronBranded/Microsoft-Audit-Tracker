function Invoke-Diagnostic {
    <#
    .SYNOPSIS
    MAT Diagnostic Check — v1.2
    .DESCRIPTION
    Four sections:
      1. Endpoint connectivity (network layer)
      2. PowerShell module availability and version gates
      3. Current MAT session state including live Exchange Online status
      4. Active Graph scopes vs required scopes

    Fixes vs previous version:
      - String interpolation bug: nested double-quotes inside PS subexpressions
        inside double-quoted strings are unreliable in PS5.1. All conditional
        labels are now pre-computed as separate variables before Write-Host.
      - Exchange connectivity URL changed from /autodiscover/ (returns HTTP 400,
        looks alarming) to root URL (returns 200 or a clean auth challenge).
      - Exchange Online live session status added via Get-ConnectionInformation.
      - Tenant ID now shows abbreviated GUID instead of "(not set)" / "[set]".
    #>
    Clear-Host
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  MAT DIAGNOSTICS" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    # ─── 1. ENDPOINT CONNECTIVITY ─────────────────────────────────────────────
    Write-Host "[1] Endpoint Connectivity" -ForegroundColor Yellow

    $endpoints = @(
        @{ Name = "Microsoft Graph API"  ; Uri = "https://graph.microsoft.com/";       Required = $true  }
        @{ Name = "Entra ID (login)"     ; Uri = "https://login.microsoftonline.com/"; Required = $true  }
        @{ Name = "Exchange Online"      ; Uri = "https://outlook.office365.com/";     Required = $true  }
        @{ Name = "Azure Management API" ; Uri = "https://management.azure.com/";      Required = $false }
    )

    foreach ($ep in $endpoints) {
        Write-Host "    $($ep.Name.PadRight(24)) ..." -NoNewline
        try {
            $r = Invoke-WebRequest -Uri $ep.Uri -UseBasicParsing -TimeoutSec 7 -ErrorAction Stop
            Write-Host " [OK] HTTP $($r.StatusCode)" -ForegroundColor Green
        } catch {
            # Distinguish "server responded with auth error" from "network failure".
            # If the exception carries a Response, the server was reached — network is fine.
            if ($_.Exception.Response) {
                $code = [int]$_.Exception.Response.StatusCode
                Write-Host " [REACHABLE] HTTP $code (auth required — network OK)" -ForegroundColor Green
            } else {
                $msg   = $_.Exception.Message.Split([Environment]::NewLine)[0].Trim()
                $color = if ($ep.Required) { "Red" } else { "Yellow" }
                Write-Host " [FAIL] $msg" -ForegroundColor $color
            }
        }
    }

    # ─── 2. POWERSHELL MODULE VERSIONS ────────────────────────────────────────
    Write-Host ""
    Write-Host "[2] PowerShell Modules" -ForegroundColor Yellow

    $modules = @(
        @{ Name = "Microsoft.Graph.Authentication"; Required = $true;  MinVersion = $null;            Note = "Core Graph connectivity" }
        @{ Name = "ExchangeOnlineManagement";       Required = $true;  MinVersion = [Version]"3.2.0"; Note = "v3.2+ required for CopilotInteraction RecordType in UAL probes" }
        @{ Name = "Az.Accounts";                    Required = $false; MinVersion = $null;            Note = "Optional — Azure RBAC detection and activity log checks" }
        @{ Name = "Az.Monitor";                     Required = $false; MinVersion = $null;            Note = "Optional — Entra ID diagnostic settings (requires Monitoring Reader role)" }
    )

    foreach ($m in $modules) {
        # Check if already loaded in this session first — avoids unnecessary re-import
        # and prevents resetting module-level state in some environments.
        $mod = Get-Module -Name $m.Name -ErrorAction SilentlyContinue
        if (-not $mod) {
            # Not loaded — attempt a real import to catch broken installs.
            # Get-Module -ListAvailable only checks disk presence, not importability.
            try { $mod = Import-Module $m.Name -PassThru -ErrorAction Stop } catch {}
        }

        if ($mod) {
            $v = $mod.Version
            $vOk = ($null -eq $m.MinVersion) -or ($v -ge $m.MinVersion)

            # Pre-compute all conditional label strings before Write-Host.
            # Nested double-quotes inside $(if(...){" ... "}) in a double-quoted
            # string are unreliable in PS5.1 — they parse as separate string tokens.
            $icon     = if ($vOk) { "[✓]" } else { "[!]" }
            $verLabel = if ($vOk) { " v$v" } else { " v$v [needs $($m.MinVersion)+]" }
            $col      = if ($vOk) { "Green" } else { "Yellow" }

            Write-Host "    $icon $($m.Name)$verLabel" -ForegroundColor $col
            if (-not $vOk) {
                Write-Host "        Reason : $($m.Note)" -ForegroundColor Gray
                Write-Host "        Fix    : Update-Module $($m.Name) -Force" -ForegroundColor Gray
            }
        } else {
            if ($m.Required) {
                Write-Host "    [✗] $($m.Name) — MISSING or BROKEN (required)" -ForegroundColor Red
                Write-Host "        Fix : Install-Module $($m.Name) -Force" -ForegroundColor Gray
            } else {
                Write-Host "    [!] $($m.Name) — not installed (optional)" -ForegroundColor Yellow
                Write-Host "        Info: $($m.Note)" -ForegroundColor Gray
            }
        }
    }

    # ─── 3. SESSION STATE ─────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[3] Session State" -ForegroundColor Yellow

    $connected  = $script:MAT_Global.IsConnected
    $statusCol  = if ($connected) { "Green" } else { "Red" }
    $tenantDisp = if ([string]::IsNullOrWhiteSpace($script:MAT_Global.TenantName) -or
                      $script:MAT_Global.TenantName -eq "DISCONNECTED") {
        "(not connected)"
    } else { $script:MAT_Global.TenantName }

    # Show abbreviated Tenant ID — useful for confirming which tenant you are in
    $tidDisp = if ($script:MAT_Global.TenantId) {
        $script:MAT_Global.TenantId.Substring(0,8) + "..."
    } else { "(not set)" }

    Write-Host "    Status     : $($script:MAT_Global.Status)" -ForegroundColor $statusCol
    Write-Host "    Tenant     : $tenantDisp"  -ForegroundColor White
    Write-Host "    Tenant ID  : $tidDisp"     -ForegroundColor Gray
    Write-Host "    User       : $($script:MAT_Global.UserPrincipal)" -ForegroundColor White
    Write-Host "    M365 Role  : $($script:MAT_Global.UserRole)"      -ForegroundColor Yellow
    Write-Host "    Azure Role : $($script:MAT_Global.AzureStatus)"   -ForegroundColor Cyan

    # SKU cache status
    if ($script:MAT_Global.SkuCache -and $script:MAT_Global.SkuCacheTime) {
        $ageMin    = [math]::Round(((Get-Date) - $script:MAT_Global.SkuCacheTime).TotalMinutes, 1)
        $stale     = $ageMin -ge 60
        $staleNote = if ($stale) { " [STALE — will refresh on next mode run]" } else { "" }
        $cacheCol  = if ($stale) { "Yellow" } else { "Green" }
        Write-Host "    SKU Cache  : $($script:MAT_Global.SkuCache.Count) SKUs — age ${ageMin}m$staleNote" -ForegroundColor $cacheCol
    } else {
        Write-Host "    SKU Cache  : empty — will fetch on first mode run" -ForegroundColor Yellow
    }

    # Exchange Online live session check
    # Get-ConnectionInformation is available in ExchangeOnlineManagement v3+.
    Write-Host ""
    Write-Host "    Exchange Online Session:" -ForegroundColor Gray
    try {
        $exoInfo = Get-ConnectionInformation -ErrorAction Stop
        if ($exoInfo) {
            $exoState = $exoInfo | Select-Object -First 1
            $exoCol   = if ($exoState.State -eq "Connected") { "Green" } else { "Yellow" }
            Write-Host "    [✓] $($exoState.State) as $($exoState.UserPrincipalName)" -ForegroundColor $exoCol
            if ($exoState.State -ne "Connected") {
                Write-Host "        Use [C] to reconnect." -ForegroundColor Gray
            }
        } else {
            Write-Host "    [!] Not connected" -ForegroundColor Yellow
        }
    } catch {
        if ($_ -match "Get-ConnectionInformation|not recognized") {
            Write-Host "    [!] Get-ConnectionInformation unavailable — ExchangeOnlineManagement v3+ required" -ForegroundColor Yellow
        } else {
            Write-Host "    [!] Not connected to Exchange Online" -ForegroundColor Yellow
        }
    }

    # ─── 4. GRAPH SCOPE VERIFICATION ──────────────────────────────────────────
    Write-Host ""
    Write-Host "[4] Graph Scopes" -ForegroundColor Yellow

    $requiredScopes = @(
        "Directory.Read.All",
        "AuditLog.Read.All",
        "User.Read.All",
        "RoleManagement.Read.Directory",
        "Policy.Read.All",
        "Reports.Read.All"
    )

    $ctx = Get-MgContext -ErrorAction SilentlyContinue
    if ($ctx -and $ctx.Scopes) {
        # Safe conversion: ReadOnlyCollection[string] → string[] → HashSet.
        # A direct [string[]] cast of a ReadOnlyCollection fails in PS5.1 on some
        # Graph SDK builds where the collection type is not IEnumerable[string].
        $scopeArray    = @($ctx.Scopes | ForEach-Object { [string]$_ })
        $grantedScopes = [System.Collections.Generic.HashSet[string]]::new(
            $scopeArray, [System.StringComparer]::OrdinalIgnoreCase
        )

        $allPresent = $true
        foreach ($scope in $requiredScopes) {
            if ($grantedScopes.Contains($scope)) {
                Write-Host "    [✓] $scope" -ForegroundColor Green
            } else {
                Write-Host "    [✗] $scope — MISSING" -ForegroundColor Red
                $allPresent = $false
            }
        }
        if (-not $allPresent) {
            Write-Host ""
            Write-Host "    [!] Missing scopes — use [C] to re-connect and re-authorize." -ForegroundColor Yellow
        }
    } else {
        Write-Host "    [!] Not connected to Graph — use [C] to connect first." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Pause
}
