# SINGLE URL to the mod loader
$MOD_LOADER_URL = ""
# SINGLE URL to all the mods (e.g., a direct link to a zipped pack or a specific jar)
$MODS_URL = ""

# Define the standard Windows Minecraft roaming path
$MC_DIR = "$env:APPDATA\.minecraft"
$VERSIONS_DIR = "$MC_DIR\versions"

# 1. Checks if Minecraft directory even exists
if (-not (Test-Path $VERSIONS_DIR)) {
    Write-Error "Error: Minecraft versions folder not found at $VERSIONS_DIR"
    Exit
}
Write-Host "Minecraft Directory Found: $MC_DIR"

# 2. Index all the directories inside the versions folder (Baseline)
Write-Host "Indexing the directories inside Minecraft folder..."
$BaselineDirs = Get-ChildItem -Path $VERSIONS_DIR -Directory | Select-Object -ExpandProperty Name | Sort-Object

# Where the JAR file gets downloaded to
$INSTALLER_JAR = "$env:TEMP\modloader_installer.jar"

# 3. Download the mod loader from the URL provided
Write-Host "Downloading Mod Loader..."
Invoke-WebRequest -Uri $MOD_LOADER_URL -OutFile $INSTALLER_JAR

# 4. Install the mod loader 
Write-Host "Installing Mod Loader... Please interact with the popup installer UI if it appears."
Start-Process java -ArgumentList "-jar `"$INSTALLER_JAR`"" -Wait

# 5. Find the unindexed directory (Current vs Baseline Delta)
Write-Host "Finding the Installed Directory..."
$CurrentDirs = Get-ChildItem -Path $VERSIONS_DIR -Directory | Select-Object -ExpandProperty Name | Sort-Object

# Compare object finds what is unique to the Current directory set
$NewDirName = Compare-Object -ReferenceObject $BaselineDirs -DifferenceObject $CurrentDirs | 
               Where-Object { $_.SideIndicator -eq "=>" } | 
               Select-Object -First 1 -ExpandProperty InputObject

if (-not $NewDirName) {
    Write-Error "Error: Dynamic unindexed directory NOT found."
    Write-Host "Cleaning up baseline files and exiting..."
    Remove-Item -Path $INSTALLER_JAR -Force -ErrorAction SilentlyContinue
    Exit
}

$NEW_DIR = Join-Path $VERSIONS_DIR $NewDirName

Write-Host "Printing out new directory target:"
Write-Host "$MC_DIR\mods"
Write-Host "YOUR CURRENT MODS WILL BE SAVED INSIDE ANOTHER FOLDER IN THE SAME DIRECTORY."
Write-Host "IF THIS IS A FOLDER YOU DO NOT WANT CHANGED OR DELETED, close this window now!"
Write-Host "You have 10 seconds to decide..."
Start-Sleep -Seconds 10

$MODS_FOLDER = Join-Path $MC_DIR "mods"

# 6. Safe Backup Logic: If the mods folder exists and contains items, rename it
if ((Test-Path $MODS_FOLDER) -and (Get-ChildItem -Path $MODS_FOLDER)) {
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $BACKUP_NAME = "${MODS_FOLDER}_backup_$Timestamp"
    Write-Host "Warning: Existing mods detected! Creating safety backup at: $BACKUP_NAME"
    Rename-Item -Path $MODS_FOLDER -NewName (Split-Path $BACKUP_NAME -Leaf)
}

# 7. Create a fresh, pristine folder purely for your server mods
Write-Host "Creating clean mods directory..."
$null = New-Item -ItemType Directory -Path $MODS_FOLDER -Force
Write-Host "Mods Directory Ready: $MODS_FOLDER"

# 8. Download mods directly into the target folder
Write-Host "Downloading Mods to the mods directory..."
# Automatically determines if the link points to a .zip file or a single .jar
$OutputFileName = Split-Path $MODS_URL -Leaf
if (-not $OutputFileName.EndsWith(".zip") -and -not $OutputFileName.EndsWith(".jar")) {
    $OutputFileName = "mods.zip" # Fallback if URL hides extension
}
$TargetModFile = Join-Path $MODS_FOLDER $OutputFileName

Invoke-WebRequest -Uri $MODS_URL -OutFile $TargetModFile

# 9. Automation Feature: If you downloaded a zip package, automatically extract it cleanly
if ($OutputFileName.EndsWith(".zip")) {
    Write-Host "Zip archive detected. Extracting mod pack..."
    Expand-Archive -Path $TargetModFile -DestinationPath $MODS_FOLDER -Force
    Remove-Item -Path $TargetModFile -Force
    Write-Host "Extraction complete!"
}

# 10. Clean Up temporary files
Write-Host "Cleaning up temporary installation files..."
Remove-Item -Path $INSTALLER_JAR -Force -ErrorAction SilentlyContinue
Write-Host "Finished Installation successfully!"
Pause
