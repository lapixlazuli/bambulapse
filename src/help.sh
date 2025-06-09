#!/bin/bash
# ==============================================================================
# BAMBULAPSE HELP SCRIPT INSTALLER
#
# This script creates the main 'bambulapse' command, which acts as a
# help menu, displaying all available commands for the user.
# ==============================================================================

# --- Configuration and Safety Nets ---
set -euo pipefail

# --- Source Shared Functions ---
source "$(dirname "$0")/common.sh"

log_info "Creating the main 'bambulapse' help command..."

# --- Create 'bambulapse' Utility ---
# This command simply displays a formatted help text.
tee /usr/local/bin/bambulapse > /dev/null << 'EOF'
#!/bin/bash
# This script displays the available commands for the Bambulapse system.

# Define color codes for a more appealing output.
C_BLUE=$'\033[1;34m'
C_GREEN=$'\033[0;32m'
C_RESET=$'\033[0m'
# Use a Here Document (cat << "EOM") to print the multi-line help message.
# Quoting "EOM" prevents any variable expansion inside the block.
cat << EOM

${C_BLUE}Bambulapse - Timelapse Control System${C_RESET}
-----------------------------------------
A collection of commands to manage your timelapse setup.

${C_GREEN}CORE COMMANDS:${C_RESET}
  startlapse      Starts the main timelapse service in the background.
  stoplapse       Stops the timelapse and all related processes.

${C_GREEN}UTILITIES:${C_RESET}
  snapshot        Manually triggers a single photo.
  cfgcamera       Opens the interactive menu to adjust camera settings.
  cfgdistance     Opens the menu to adjust sensor distance and GPIO pins.
  testdistance    Runs a live test of the ultrasonic distance sensor.

${C_GREEN}HELP:${C_RESET}
  bambulapse      Displays this help menu.

EOM
EOF

# Set execute permission for the main command.
chmod +x /usr/local/bin/bambulapse

log_success "Main 'bambulapse' help command created successfully."
