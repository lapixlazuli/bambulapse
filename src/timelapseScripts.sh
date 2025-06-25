#!/bin/bash
# ==============================================================================
# BAMBULAPSE CONTROL SCRIPTS INSTALLER
#
# Author: @thidiasr
#
# This script creates the core control utilities for the timelapse system:
# - startlapse: Starts the main timelapse application in the background.
# - stoplapse:  Stops the timelapse application and the motion service.
# - snapshot:   Manually triggers a single snapshot.
# ==============================================================================

# --- Configuration and Safety Nets ---
set -e
set -u
set -o pipefail

# --- Source Shared Functions ---
source "$(dirname "$0")/common.sh"

log_info "Creating control scripts (startlapse, stoplapse, snapshot)..."

# --- Create 'startlapse' Utility ---
# This command starts the main C application in the background.
log_info "Creating 'startlapse'..."
tee /usr/local/bin/startlapse > /dev/null << 'EOF'
#!/bin/bash
# Starts the timelapse sensor application in the background.

# Use 'nohup' to ensure the process keeps running even if the terminal is closed.
# Logs (stdout and stderr) are redirected to a file in the user's home directory.
nohup timelapse > ~/timelapse.log 2>&1 &

# Provide feedback to the user.
echo "Timelapse process started in the background."
echo "Logs are being written to ~/timelapse.log"
EOF
# Set execute permission.
chmod +x /usr/local/bin/startlapse

# --- Create 'stoplapse' Utility ---
# This command gracefully stops all related processes.
log_info "Creating 'stoplapse'..."
tee /usr/local/bin/stoplapse > /dev/null << 'EOF'
#!/bin/bash
# Stops all running processes related to the Bambulapse system.

echo "Attempting to stop Bambulapse processes..."

# Stop the main timelapse sensor application.
# Use pkill to find and kill the process by its name.
if pgrep -f "timelapse" > /dev/null; then
    pkill -f "timelapse"
    echo "-> 'timelapse' process stopped."
else
    echo "-> 'timelapse' process was not running."
fi

# Stop the Motion service.
# The '-f' flag matches the full command line, making it more specific.
if pgrep -f "motion -c" > /dev/null; then
    pkill -f "motion -c"
    echo "-> 'motion' service stopped."
else
    echo "-> 'motion' service was not running."
fi

echo "All processes stopped."
EOF
# Set execute permission.
chmod +x /usr/local/bin/stoplapse

# --- Create 'snapshot' Utility ---
# This command provides a simple way to manually trigger a photo.
log_info "Creating 'snapshot'..."
tee /usr/local/bin/snapshot > /dev/null << 'EOF'
#!/bin/bash
# Manually triggers a single snapshot via the Motion web control API.

echo "Triggering a manual snapshot..."
if pgrep -f "motion -c" > /dev/null; then
    if curl -s -o /dev/null http://localhost:8081/0/action/snapshot; then
        echo "Snapshot taken successfully."
    else
        echo "Command failed. Could not connect to Motion's web control on port 8081."
    fi
    else
    # If pgrep fails, it means the process was not found.
    echo "Motion service is not running."
    echo "Please start the service with the 'startlapse' command before taking a snapshot."
    exit 1
fi
EOF
# Set execute permission.
chmod +x /usr/local/bin/snapshot

log_success "Control scripts created successfully."
