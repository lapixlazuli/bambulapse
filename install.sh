#!/bin/bash
# ==============================================================================
# BAMBULAPSE INSTALLER
#
# Author: @thidiasr
# Version: 1.0
#
# This script orchestrates the complete installation of the project in a modular way.
# ==============================================================================

# --- Configuration and Safety Nets ---
set -e
set -u
set -o pipefail

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root. Please use 'sudo'."
fi

# --- Source Shared Functions ---
source "src/common.sh"

# --- Logging Functions with Colors ---

# Define color codes
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_RED='\033[0;31m'
COLOR_RESET='\033[0m'

# Log an informational message (yellow)
log_info() {
    echo -e "${COLOR_YELLOW}[INFO] $1${COLOR_RESET}"
}

# Log a success message (green)
log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS] $1${COLOR_RESET}"
}

# Log an error message and exit (red)
log_error() {
    echo -e "${COLOR_RED}[ERROR] $1${COLOR_RESET}" >&2
    exit 1
}

# --- Main Script Logic ---

# Define the directory containing the installation modules
SCRIPTS_DIR="src"

# Verify if the scripts directory exists
if [ ! -d "$SCRIPTS_DIR" ]; then
    log_error "Scripts directory '$SCRIPTS_DIR' not found. Aborting."
fi

# Load user settings from the configuration file
if [ -f "config.sh" ]; then
    log_info "Loading user settings from config.sh..."
    source config.sh
else
    log_error "Configuration file 'config.sh' not found. Aborting."
fi

# Export variables to be used by sub-scripts
export VIDEODEVICE WIDTH HEIGHT BRIGHTNESS SATURATION PIXEL_FORMAT
export DIR GPIO_TRIG GPIO_ECHO WIRINGPI_REPO
export SNAPSHOT_DISTANCE=4.1
export RESET_DISTANCE=7.0
export PAUSE_SECS=1

# Grant execute permissions to all scripts in the directory
log_info "Setting execute permissions for installation scripts..."
chmod +x "$SCRIPTS_DIR"/*.sh

# --- Script Runner Function ---

# A function to execute and validate each installation step.
run_script() {
    local script_path="$1"
    local step_name="$2"

    echo "" # Add a newline for better spacing
    log_info "Starting step: $step_name"

    if [ ! -f "$script_path" ]; then
        log_error "Script for '$step_name' not found at '$script_path'."
    fi

    # Execute the script with a visual spinner
    bash "$script_path" &
    local pid=$!
    local spin='-\|/'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\rRunning... ${spin:$i:1}"
        sleep .1
    done
    printf "\r" # Clear the spinner line

    # Wait for the script to finish and check its exit code
    wait $pid
    if [ $? -ne 0 ]; then
        log_error "Step '$step_name' failed. Installation interrupted."
    fi

    log_success "Step '$step_name' finished."
}

# --- Installation Steps ---

log_info "Starting Bambulapse installation..."

run_script "$SCRIPTS_DIR/dependencies.sh" "Installing dependencies"
run_script "$SCRIPTS_DIR/motion.sh" "Configuring Motion"
run_script "$SCRIPTS_DIR/build.sh" "Compiling the project"
run_script "$SCRIPTS_DIR/cameraConfig.sh" "Creating camera config script"
run_script "$SCRIPTS_DIR/timelapseScripts.sh" "Creating timelapse script"
run_script "$SCRIPTS_DIR/distanceConfig.sh" "Creating distance config script"
run_script "$SCRIPTS_DIR/help.sh" "Creating help command"

# --- Finalization ---
echo ""
log_success "Installation completed successfully!"
log_info "You can now run the application using the 'bambulapse' command."
