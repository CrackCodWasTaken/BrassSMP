#!/bin/bash

# SINGLE URL to the mod loader
MOD_LOADER_URL=""
# SINGLE URL to all the mods (e.g., a direct link to a zipped pack or a specific jar)
MODS_URL=""

# Differentiate between macOS or Linux to run separate commands
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Running on macOS..."
    echo "This Installer File is not built for macOS, please install mods manually."
    exit 1
    
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Running on Linux..."
    
    # Universal Linux path mapping via the $HOME variable
    MC_DIR="$HOME/.minecraft"
    
    # Checks if Minecraft directory even exists
    if [ ! -d "$MC_DIR" ]; then
        echo "Error: Minecraft folder not found at $MC_DIR"
        exit 1
    fi
    echo "Minecraft Directory Found: $MC_DIR"
    
    # Index all the directories inside the Minecraft folder
    echo "Indexing the directories inside Minecraft folder..."
    find "$MC_DIR/versions" -maxdepth 1 -type d | sort > /tmp/mc_baseline.txt
    
    # Where the JAR file gets downloaded to
    INSTALLER_JAR="/tmp/modloader_installer.jar"
    
    # Download the mod loader from the URL provided
    echo "Downloading Mod Loader..."
    curl -L "$MOD_LOADER_URL" -o "$INSTALLER_JAR"
    
    # Install the mod loader 
    echo "Installing Mod Loader... Please interact with the popup installer UI if it appears."
    java -jar "$INSTALLER_JAR"
    
    # Find the unindexed directory
    echo "Finding the Installed Directory..."
    find "$MC_DIR/versions" -maxdepth 1 -type d | sort > /tmp/mc_current.txt

    NEW_DIR=$(comm -13 /tmp/mc_baseline.txt /tmp/mc_current.txt | head -n 1 | xargs)
	
    # If NEW_DIR is blank, it means the version already existed or they closed the installer.
    # We only stop them if the variable has text but physically isn't a directory.
    if [ -z "$NEW_DIR" ]; then
        echo "No new directory detected (it may already be installed). Proceeding..."
    elif [ ! -d "$NEW_DIR" ]; then
        echo "Installation not complete or invalid folder, exiting..."
        rm -f /tmp/mc_baseline.txt /tmp/mc_current.txt "$INSTALLER_JAR"
        exit 1
    else
        echo "Successfully installed Mod Loader to: $NEW_DIR"
    fi
	
	# Check for mods folder
	if [ ! -d "$MC_DIR/mods" ]; then
		echo "mods folder doesnt exist, creating new folder"
		mkdir "$MC_DIR/mods"
	fi
    
    echo "Printing out new directory target:"
    echo "$MC_DIR/mods"
    echo "YOUR CURRENT MODS WILL BE SAVED INSIDE A ANOTHER FOLDER IN THE SAME DIRECTORY. IF THIS IS A FOLDER YOU DO NOT WANT CHANGED, stop installation now by pressing CTRL + C. You have 10 seconds to decide!"
    sleep 10
    
    MODS_FOLDER="$MC_DIR/mods"
    
    # Ensure the mods folder physical path exists
    if [ -d "$MODS_FOLDER" ] && [ "$(ls -A "$MODS_FOLDER")" ]; then
        BACKUP_NAME="${MODS_FOLDER}_backup_$(date +%Y%m%d_%H%M%S)"
        echo "Warning: Existing mods detected! Creating safety backup at: $BACKUP_NAME"
        mv "$MODS_FOLDER" "$BACKUP_NAME"
    fi

    # Create a fresh, pristine folder purely for your server mods
    echo "Creating clean mods directory..."
    mkdir -p "$MODS_FOLDER"

    
    echo "Mods Directory Ready: $MODS_FOLDER"
    
    # Download mods directly into the target folder
    cd "$MODS_FOLDER" || exit 1
    echo "Downloading Mods to the mods directory..."
    
    # Fixed curl: -O ensures the downloaded file saves to disk using its original name
    curl -LO "$MODS_URL"
    
    # Clean Up
    echo "Cleaning up temporary installation files..."
    rm -f "$INSTALLER_JAR" /tmp/mc_baseline.txt /tmp/mc_current.txt
    echo "Finished Installation successfully!"
else
    echo "Unknown operating system."
    echo "This Install file is built strictly for linux-gnu."
fi
