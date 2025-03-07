#!/bin/bash

# Determine available dialog tool
if command -v whiptail &> /dev/null; then
    DIALOG_TOOL="whiptail"
elif command -v dialog &> /dev/null; then
    DIALOG_TOOL="dialog"
else
    echo "Error: whiptail or dialog is required but not installed."
    exit 1
fi

# Define common variables
SCRIPT_NAME="jirasik"  # primary executable filename

# Define installation directories for each scope
INSTALL_BIN_SYSTEM="/usr/local/bin"
INSTALL_BIN_USER="$HOME/.local/bin"
INSTALL_DIR_SYSTEM="/opt/jirasik"
INSTALL_DIR_USER="$HOME/.local/share/jirasik"

# Function to prompt using the available dialog tool
prompt_menu() {
    local title="$1"
    local prompt="$2"
    local height="$3"
    local width="$4"
    local menu_height="$5"
    shift 5
    local options=("$@")
    if [[ "$DIALOG_TOOL" == "whiptail" ]]; then
        whiptail --title "$title" --menu "$prompt" "$height" "$width" "$menu_height" "${options[@]}" 3>&1 1>&2 2>&3
    else
        dialog --title "$title" --menu "$prompt" "$height" "$width" "$menu_height" "${options[@]}" 3>&1 1>&2 2>&3
    fi
}

# Prompt for main action
ACTION=$(prompt_menu "Jirasik Installer" "Choose an option:" 15 60 2 \
    "1" "Install Jirasik" \
    "2" "Uninstall Jirasik")

if [[ "$ACTION" == "1" ]]; then
    # Installation process
    INSTALL_TYPE=$(prompt_menu "Installation Type" "Where do you want to install?" 15 60 2 \
        "1" "User-level (Installs in $INSTALL_BIN_USER)" \
        "2" "System-wide (Requires sudo; Installs in $INSTALL_BIN_SYSTEM)")

    if [[ "$INSTALL_TYPE" == "1" ]]; then
        INSTALL_BIN="$INSTALL_BIN_USER"
        INSTALL_DIR="$INSTALL_DIR_USER"
    elif [[ "$INSTALL_TYPE" == "2" ]]; then
        INSTALL_BIN="$INSTALL_BIN_SYSTEM"
        INSTALL_DIR="$INSTALL_DIR_SYSTEM"
        # Require sudo for system-wide
        if [[ $EUID -ne 0 ]]; then
            echo "System-wide installation requires sudo."
            exit 1
        fi
    else
        echo "Installation cancelled."
        exit 1
    fi

    # Prompt for installation method
    METHOD=$(prompt_menu "Installation Method" "Choose installation method:" 15 60 2 \
        "1" "Symlink mode (link 'jirasik' from current folder)" \
        "2" "Standalone mode (copy folder to install dir and link executable)")

    # Ensure bin directory exists
    mkdir -p "$INSTALL_BIN"

    if [[ "$METHOD" == "1" ]]; then
        # Symlink mode: Link the executable in the current folder.
        TARGET="$PWD/$SCRIPT_NAME"
        if [[ ! -f "$TARGET" ]]; then
            echo "Error: '$SCRIPT_NAME' not found in the current directory."
            exit 1
        fi
        ln -sf "$TARGET" "$INSTALL_BIN/$SCRIPT_NAME"
        echo "Symlink created: $INSTALL_BIN/$SCRIPT_NAME -> $TARGET"
    elif [[ "$METHOD" == "2" ]]; then
        # Standalone mode: Copy the folder to the installation directory,
        # then link the executable from the copied folder.
        mkdir -p "$INSTALL_DIR"
        # Copy all files (including hidden ones) from current folder into INSTALL_DIR.
        # Using rsync for robust copying (if available) or fallback to cp.
        if command -v rsync &> /dev/null; then
            rsync -a --delete "$PWD"/ "$INSTALL_DIR"/
        else
            cp -r "$PWD"/. "$INSTALL_DIR"
        fi

        # Create a marker file to denote a standalone install.
        touch "$INSTALL_DIR/.jirasik_installed"

        # Ensure the executable is executable
        chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

        # Create symlink from the installed executable to the bin directory
        ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$INSTALL_BIN/$SCRIPT_NAME"
        echo "Standalone installation complete:"
        echo "  Folder installed to: $INSTALL_DIR"
        echo "  Symlink created: $INSTALL_BIN/$SCRIPT_NAME -> $INSTALL_DIR/$SCRIPT_NAME"
    else
        echo "Installation cancelled."
        exit 1
    fi

    # For user-level, add INSTALL_BIN to PATH if not already there
    if [[ "$INSTALL_BIN" == "$INSTALL_BIN_USER" && ":$PATH:" != *":$INSTALL_BIN:"* ]]; then
        SHELL_RC=""
        if [[ -n "$ZSH_VERSION" ]]; then
            SHELL_RC="$HOME/.zshrc"
        elif [[ -n "$BASH_VERSION" ]]; then
            SHELL_RC="$HOME/.bashrc"
            [[ -f "$HOME/.bash_profile" ]] && SHELL_RC="$HOME/.bash_profile"
        else
            SHELL_RC="$HOME/.profile"
        fi
        echo "export PATH=\"$INSTALL_BIN:\$PATH\"" >> "$SHELL_RC"
        echo "Added $INSTALL_BIN to PATH in $SHELL_RC. Please restart your terminal or run: source $SHELL_RC"
    fi

    echo "Installation complete! You can now run '$SCRIPT_NAME' from anywhere."

elif [[ "$ACTION" == "2" ]]; then
    # Uninstallation process
    UNINSTALL_TYPE=$(prompt_menu "Uninstall Jirasik" "Which installation do you want to remove?" 15 60 2 \
        "1" "User-level ($INSTALL_BIN_USER)" \
        "2" "System-wide ($INSTALL_BIN_SYSTEM) [Requires sudo]")

    if [[ "$UNINSTALL_TYPE" == "1" ]]; then
        INSTALL_BIN="$INSTALL_BIN_USER"
        INSTALL_DIR="$INSTALL_DIR_USER"
    elif [[ "$UNINSTALL_TYPE" == "2" ]]; then
        INSTALL_BIN="$INSTALL_BIN_SYSTEM"
        INSTALL_DIR="$INSTALL_DIR_SYSTEM"
        if [[ $EUID -ne 0 ]]; then
            echo "System-wide uninstallation requires sudo."
            exit 1
        fi
    else
        echo "Uninstallation cancelled."
        exit 1
    fi

    # Remove the symlink from the bin directory
    if [[ -L "$INSTALL_BIN/$SCRIPT_NAME" ]]; then
        rm -f "$INSTALL_BIN/$SCRIPT_NAME"
        echo "Removed symlink: $INSTALL_BIN/$SCRIPT_NAME"
    else
        echo "No symlink found at $INSTALL_BIN/$SCRIPT_NAME"
    fi

    # If the installation directory contains the marker file, remove it.
    if [[ -f "$INSTALL_DIR/.jirasik_installed" ]]; then
        rm -rf "$INSTALL_DIR"
        echo "Removed standalone installation directory: $INSTALL_DIR"
    else
        echo "No standalone installation found in $INSTALL_DIR (symlink installation remains intact)."
    fi

    echo "Uninstallation complete!"

else
    echo "No valid action selected. Exiting."
    exit 1
fi

