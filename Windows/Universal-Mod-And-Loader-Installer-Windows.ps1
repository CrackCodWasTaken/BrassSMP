# SINGLE URL to the mod loader
$MOD_LOADER_URL = "https://github.com/CrackCodWasTaken/BrassSMP/raw/refs/heads/main/ModLoader/neoforge-21.1.243-installer.jar"
# SINGLE URL to all the mods (e.g., a direct link to a zipped pack or a specific jar)
$MODS_URL = "https://github.com/CrackCodWasTaken/BrassSMP/raw/refs/heads/main/Mods/ModsZIP.zip"

# Define the standard Windows Minecraft roaming path
$MC_DIR = "$env:APPDATA\.minecraft"
$VERSIONS_DIR = "$MC_DIR\versions"
$MODS_FOLDER = Join-Path $MC_DIR "mods"

# Extract the target version string directly from your URL string (e.g. "neoforge-21.1.243")
$TargetVersionName = "neoforge-21.1.243"

# Checks if Minecraft directory even exists
if (-not (Test-Path $VERSIONS_DIR)) {
    Write-Error "Error: Minecraft versions folder not found at $VERSIONS_DIR"
    Exit
}

Clear-Host
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "      BRASS SMP UNIFIED INSTALLER & UPDATER   " -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " Full Install (Downloads Mod Loader + Mods)"
Write-Host " Update Mods Only (Skips Mod Loader Install)"
Write-Host "----------------------------------------------"
$Choice = Read-Host "Please enter your choice (1 or 2)"

if ($Choice -eq "1") {
    # ==============================================================================
    # PATH A: FULL FIRST-TIME INSTALLATION
    # ==============================================================================
    Write-Host "`nStarting Full Installation..." -ForegroundColor Yellow

    $INSTALLER_JAR = "$env:TEMP\modloader_installer.jar"
    Write-Host "Downloading Mod Loader..."
    Invoke-WebRequest -Uri $MOD_LOADER_URL -OutFile $INSTALLER_JAR

    # FIXED: Runs Java natively via cmd execution layer to handle GUI thread binding properly
    Write-Host "Launching NeoForge GUI Installer Window..." -ForegroundColor Cyan
    Write-Host "CRITICAL: Make sure 'Install Client' is selected, click 'OK/Proceed', and wait for success!" -ForegroundColor Yellow
    
    # Executes via native command layer and securely holds code until process exits
    cmd.exe /c "java -jar `"$INSTALLER_JAR`""

    # Hard Target: Verify if the expected version folder exists after closing
    $NEW_DIR = Join-Path $VERSIONS_DIR $TargetVersionName
    if (-not (Test-Path $NEW_DIR)) {
        Write-Warning "Target directory $TargetVersionName was not detected. Scanning fallback..."
        $NewDirName = Get-ChildItem -Path $VERSIONS_DIR -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty Name
        $NEW_DIR = Join-Path $VERSIONS_DIR $NewDirName
    }
    
    Write-Host "Successfully targeted profile version: $(Split-Path $NEW_DIR -Leaf)" -ForegroundColor Green
    Remove-Item -Path $INSTALLER_JAR -Force -ErrorAction SilentlyContinue

} elseif ($Choice -eq "2") {
    # ==============================================================================
    # PATH B: QUICK MOD UPDATE (Lists versions dynamically)
    # ==============================================================================
    Write-Host "`nScanning existing Minecraft installation profiles..." -ForegroundColor Yellow
    $ExistingVersions = Get-ChildItem -Path $VERSIONS_DIR -Directory | Select-Object -ExpandProperty Name
    
    if ($ExistingVersions.Count -eq 0) {
        Write-Error "No existing versions found in your Minecraft directory! Please run a Full Install first."
        Exit
    }

    Write-Host "`nAvailable Profiles Found:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $ExistingVersions.Count; $i++) {
        Write-Host "[$i] $($ExistingVersions[$i])"
    }
    Write-Host "----------------------------------------------"
    
    $Selection = Read-Host "Select the index number of your NeoForge/Fabric profile"
    
    if ($Selection -match '^\d+$' -and [int]$Selection -lt $ExistingVersions.Count) {
        $NewDirName = $ExistingVersions[[int]$Selection]
        $NEW_DIR = Join-Path $VERSIONS_DIR $NewDirName
        Write-Host "Target locked on: $NewDirName" -ForegroundColor Green
    } else {
        Write-Error "Invalid selection. Exiting script."
        Exit
    }
} else {
    Write-Error "Invalid choice. Exiting script."
    Exit
}

# ==============================================================================
# UNIFIED DOWNLOADING & BACKUP CORE (Shared by both options)
# ==============================================================================
Write-Host "`nPreparing mods injection to target: $MC_DIR\mods"
Write-Host "YOUR CURRENT MODS WILL BE BACKED UP INSIDE ANOTHER FOLDER IN THE SAME DIRECTORY."
Write-Host "If this is okay, wait 5 seconds. Otherwise, close this window now!"
Start-Sleep -Seconds 5

# Safe Backup Logic
if ((Test-Path $MODS_FOLDER) -and (Get-ChildItem -Path $MODS_FOLDER)) {
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $BACKUP_NAME = "${MODS_FOLDER}_backup_$Timestamp"
    Write-Host "Existing mods detected! Creating safety backup at: $BACKUP_NAME" -ForegroundColor Yellow
    Rename-Item -Path $MODS_FOLDER -NewName (Split-Path $BACKUP_NAME -Leaf)
}

# Create a clean folder purely for the server pack
Write-Host "Creating clean mods directory..."
$null = New-Item -ItemType Directory -Path $MODS_FOLDER -Force

# Download mods from RAW GitHub Link stream
Write-Host "Downloading Mods archive from GitHub..."
$TargetModFile = Join-Path $MODS_FOLDER "ModsZIP.zip"
Invoke-WebRequest -Uri $MODS_URL -OutFile $TargetModFile

# Extract mods safely
if ((Test-Path $TargetModFile) -and ((Get-Item $TargetModFile).Length -gt 0)) {
    Write-Host "Extracting mod pack contents..." -ForegroundColor Yellow
    Expand-Archive -Path $TargetModFile -DestinationPath $MODS_FOLDER -Force
    Remove-Item -Path $TargetModFile -Force
    Write-Host "Extraction complete!" -ForegroundColor Green
} else {
    Write-Error "Error: The downloaded mod pack archive is empty or invalid."
    Exit
}

Write-Host "`nFinished successfully! You are ready to play on the server." -ForegroundColor Green
Pause