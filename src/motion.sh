#!/bin/bash
# ==============================================================================
# BAMBULAPSE MOTION CONFIGURATION SCRIPT
#
# Author: @thidiasr
#
# This script configures the /etc/motion/motion.conf file with the
# optimal settings for the Bambulapse project. It ensures that essential
# parameters are set, whether they exist in the file already or not.
# ==============================================================================

# --- Configuration and Safety Nets ---
# -e: exit on error, -u: exit on unset variables, -o pipefail: pipeline exit status
set -e
set -u
set -o pipefail

# --- Source Shared Functions ---
# Load the common library for logging and utility functions.
source "$(dirname "$0")/common.sh"

# --- Define Constants ---
MOTION_CONF="/etc/motion/motion.conf"
BACKUP_CONF="/etc/motion/motion.conf.bambulapse.bak" # Using a unique backup name

# --- Initial Check and Backup ---

log_info "Verifying Motion configuration..."
if [ ! -f "$MOTION_CONF" ]; then
    log_error "Motion is not installed or configuration file not found at '$MOTION_CONF'."
    exit 1
fi

# Create a one-time backup if it doesn't already exist.
if [ ! -f "$BACKUP_CONF" ]; then
    log_info "Creating a backup of the original motion.conf..."
    cp "$MOTION_CONF" "$BACKUP_CONF"
    log_success "Backup created at $BACKUP_CONF"
fi

# --- Core Configuration Function ---

# Adds a new key-value pair or replaces the value of an existing key.
# It handles commented-out keys by uncommenting and replacing them.
# This function is the core logic and will not be changed.
add_or_replace() {
    local key="$1"
    local value="$2"
    # Check if the key exists, even if commented out.
    if grep -Eq "^[;#]*\s*${key}" "$MOTION_CONF"; then
        # If it exists, replace the entire line.
        sed -i -E "s|^[;#]*\s*${key}.*|${key} ${value}|" "$MOTION_CONF"
    else
        # If it doesn't exist, append it to the end of the file.
        echo "${key} ${value}" >> "$MOTION_CONF"
    fi
}

# --- Applying Configuration Settings ---

# --- Applying Configuration Settings ---

log_info "Applying Bambulapse settings to motion.conf..."

# --- General Settings ---
add_or_replace "daemon" "on"                  # Run Motion as a background process.
add_or_replace "log_level" "4"                # Set log level to ERR, WAR, and CRITICAL for cleaner logs.

# --- Target and Device ---
add_or_replace "target_dir" "$DIR"            # Set the directory for saving snapshots.
add_or_replace "video_device" "/dev/video$VIDEODEVICE" # Set the camera device.

# --- Image Dimensions and Rate ---
add_or_replace "width" "$WIDTH"               # Set image width.
add_or_replace "height" "$HEIGHT"             # Set image height.
add_or_replace "framerate" "30"               # Set a higher framerate for smooth streaming if needed.

# --- Output Settings ---
# We disable Motion's internal picture/movie saving because we trigger snapshots externally.
add_or_replace "picture_output" "off"         # Disable automatic picture saving.
add_or_replace "movie_output" "off"           # Disable automatic movie recording.
add_or_replace "snapshot_filename" "%Y%m%d-%H%M%S-snapshot" # Set filename format for snapshots.
add_or_replace "picture_quality" "95"         # Set JPEG quality for snapshots.

# --- Web Control Interface ---
# This interface is crucial for triggering snapshots via 'curl'.
add_or_replace "webcontrol_port" "8081"       # Set the port for the web control interface.
add_or_replace "webcontrol_localhost" "off"   # Allow access from any IP (including from the host itself).
add_or_replace "stream_localhost" "off"       # Allow the video stream to be viewed from other machines.

# --- Text Overlay ---
# Disable all text overlays for clean snapshot images.
add_or_replace "text_left" ""
add_or_replace "text_right" ""
add_or_replace "text_event" ""
add_or_replace "text_scale" "0"

# --- Video Parameters ---
# This special parameter string passes multiple settings directly to the v4l2 driver.
#//***This is the most complex line, combining multiple camera settings.***
#//***It's encapsulated in a function for clarity.***
update_video_params() {
    local PARAMS="width=${WIDTH},height=${HEIGHT},framerate=30,palette=${PIXEL_FORMAT},ID09963776=${BRIGHTNESS},ID09963778=${SATURATION}"
    add_or_replace "video_params" "$PARAMS"
}

update_video_params

log_success "Motion configuration has been updated successfully."
