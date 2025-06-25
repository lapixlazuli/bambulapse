#!/bin/bash
# ==============================================================================
# BAMBULAPSE BUILD SCRIPT (SMART VERSION)
#
# Author: @thidiasr
#
# This script compiles the C programs. It now intelligently checks if
# config headers exist before creating them, preserving user changes.
# ==============================================================================

# --- Configuration and Safety Nets ---
set -euo pipefail

# --- Source Shared Functions ---
source "$(dirname "$0")/common.sh"

# --- Header File Generation (INTELLIGENT CHECK) ---
# This block only runs if the config files do not already exist.
# This prevents overwriting changes made by the 'cfgdistance' utility.
if [ ! -f "gpio_config.h" ] || [ ! -f "distance_config.h" ]; then
    log_info "Configuration files (.h) not found. Creating initial versions..."

    # Check that the main config file was sourced and variables are available.
    : "${GPIO_TRIG:?Variable GPIO_TRIG is not set. Check config.sh and install.sh}"
    : "${SNAPSHOT_DISTANCE:?Variable SNAPSHOT_DISTANCE is not set. Check config.sh and install.sh}"

    # Write distance_config.h
    {
        echo "// Auto-generated during initial installation"
        printf "#define SNAPSHOTDISTANCE %.1ff\n" "$SNAPSHOT_DISTANCE"
        printf "#define RESETDISTANCE %.1ff\n" "$RESET_DISTANCE"
        printf "#define PAUSESECS %.1ff\n" "$PAUSE_SECS"
    } > "distance_config.h"

    # Write gpio_config.h
    {
        echo "// Auto-generated during initial installation"
        echo "#define TRIG $GPIO_TRIG"
        echo "#define ECHO $GPIO_ECHO"
    } > "gpio_config.h"

    log_success "Initial .h configuration files created."
else
    log_info "Existing configuration files found. Skipping creation."
fi


# --- Compilation and Installation ---

# Reusable function to compile, move, and set permissions for a C program.
build_and_install() {
    local source_file="$1"
    local binary_name="$2"
    local dest_dir="/usr/local/bin"

    log_info "Compiling '$source_file' into '$binary_name'..."

    # The -I. flag tells gcc to look for #include files in the current directory.
    if gcc "$source_file" -o "$binary_name" -I. -lwiringPi; then
        log_success "'$binary_name' compiled successfully."
        mv "$binary_name" "$dest_dir/"
        chmod +x "$dest_dir/$binary_name"
        log_success "'$binary_name' installed to '$dest_dir'."
    else
        log_error "Failed to compile '$source_file'. Build stopped."
    fi
}

# Build and install the main timelapse application
build_and_install "timelapse.c" "timelapse"

# Build and install the distance testing utility
build_and_install "testdistance.c" "testdistance"

log_success "All programs compiled and installed!"
