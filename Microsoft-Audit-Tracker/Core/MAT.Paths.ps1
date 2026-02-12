function Get-MATDownloadsPath {
    # Cross-platform logic to find the user's download folder
    if ($IsWindows) {
        $basePath = [Environment]::GetFolderPath("UserProfile")
    } else {
        # macOS / Linux fallback
        $basePath = [Environment]::GetFolderPath("UserProfile")
    }
    return Join-Path $basePath "Downloads"
}

function Get-MATReportPath {
    param($TenantName)
    $root = Get-MATDownloadsPath
    $matRoot = Join-Path $root "MAT_Reports"
    
    # Structure: MAT_Reports/<TenantName>/YYYY-MM-DD/
    $dateFolder = (Get-Date).ToString("yyyy-MM-dd")
    $finalPath = Join-Path (Join-Path $matRoot $TenantName) $dateFolder
    
    if (-not (Test-Path $finalPath)) {
        New-Item -Path $finalPath -ItemType Directory -Force | Out-Null
    }
    return $finalPath
}

function Get-MATLogPath {
    $root = Get-MATDownloadsPath
    $logRoot = Join-Path (Join-Path $root "MAT_Reports") "MAT_Operational_Logs"
    
    if (-not (Test-Path $logRoot)) {
        New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
    }
    return $logRoot
}