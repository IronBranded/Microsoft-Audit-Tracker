# 1. Set Error Preference and Clean Screen
$ErrorActionPreference = "Stop" # Changed to 'Stop' so the try/catch actually catches path errors
Clear-Host

# 2. Path Setup
$scriptPath = $PSScriptRoot

# 3. Load Core & Operations (The "Full Entirety" Method)
try {
    # Define the folders that MUST be loaded for the app to function
    $loadFolders = @("Core", "Data", "UI", "Operations")

    foreach ($folder in $loadFolders) {
        $targetPath = Join-Path $scriptPath $folder
        if (Test-Path $targetPath) {
            # This command pulls the full entirety of the folder's scripts
            Get-ChildItem -Path $targetPath -Filter "*.ps1" -Recurse | ForEach-Object {
                . $_.FullName
            }
        }
    }
}
catch {
    Write-Host "CRITICAL ERROR: Failed to load logic from $targetPath" -ForegroundColor Red
    Write-Host "Details: $_" -ForegroundColor Gray
    Pause
    Exit
}

# 4. Check Module Dependencies
$reqModules = @("Microsoft.Graph.Authentication", "ExchangeOnlineManagement", "Az.Accounts")
foreach ($mod in $reqModules) {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        Write-Host "WARNING: Missing Module: $mod" -ForegroundColor Yellow
    }
}

# 5. Initialize State & Launch UI
# Ensure these functions exist in the files loaded above!
Initialize-MATState
Show-MATMenu