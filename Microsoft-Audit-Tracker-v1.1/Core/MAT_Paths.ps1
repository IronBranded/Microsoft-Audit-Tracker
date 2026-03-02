function Get-MATDownloadsPath {
    # Bug Fix #4: Both branches were identical. On macOS/Linux,
    # GetFolderPath("UserProfile") returns empty string, breaking all report paths.
    if ($IsWindows -or (-not $IsWindows -and -not $IsMacOS -and -not $IsLinux)) {
        $basePath = [Environment]::GetFolderPath("UserProfile")
    } else {
        # macOS / Linux: use $HOME which is always populated
        $basePath = $env:HOME
    }

    if ([string]::IsNullOrWhiteSpace($basePath)) {
        # Last-resort fallback: current working directory
        $basePath = $PWD.Path
    }

    return Join-Path $basePath "Downloads"
}

function Get-SafeTenantName {
    # Improvement: centralised sanitisation so every path-building call is consistent.
    param([string]$TenantName)
    if ([string]::IsNullOrWhiteSpace($TenantName)) { return "Unknown_Tenant" }
    return ($TenantName -replace '[\\/:*?"<>|]', '_').Trim()
}

function Get-MATReportPath {
    param([string]$TenantName)
    $root        = Get-MATDownloadsPath
    $matRoot     = Join-Path $root "MAT_Reports"

    # Bug Fix #6: Sanitise tenant name before embedding it in a folder path.
    $safeTenant  = Get-SafeTenantName $TenantName
    $dateFolder  = (Get-Date).ToString("yyyy-MM-dd")
    $finalPath   = Join-Path (Join-Path $matRoot $safeTenant) $dateFolder

    if (-not (Test-Path $finalPath)) {
        New-Item -Path $finalPath -ItemType Directory -Force | Out-Null
    }
    return $finalPath
}

function Get-MATLogPath {
    $root    = Get-MATDownloadsPath
    $logRoot = Join-Path (Join-Path $root "MAT_Reports") "MAT_Operational_Logs"

    if (-not (Test-Path $logRoot)) {
        New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
    }
    return $logRoot
}
