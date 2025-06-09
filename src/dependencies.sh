#!/bin/bash
# ==============================================================================
# BAMBULAPSE DEPENDENCIES SCRIPT
#
# This script installs all system-level dependencies required for the project,
# including system packages via apt and the WiringPi library for GPIO control.
# ==============================================================================

# --- Configuration and Safety Nets ---
# -e: exit on error, -u: exit on unset variables, -o pipefail: pipeline exit status
set -e
set -u
set -o pipefail

# --- Source Shared Functions ---
# Load the common library for logging and utility functions.
source "$(dirname "$0")/common.sh"

# --- System Package Installation ---

log_info "Updating package list and installing system dependencies..."
# Use -qq for a quieter output from apt-get, as our logs handle user feedback.
apt-get update -qq

# Install all required packages in a single, non-interactive (-y) command.
# - motion: The core camera streaming and snapshot service.
# - git: Required to clone the WiringPi repository.
# - build-essential: Provides gcc, make, and other compilation tools.
# - curl: Used by the C program to trigger snapshots via Motion's web API.
# - v4l-utils: Provides v4l2-ctl for camera configuration.

apt-get install -y motion git build-essential curl v4l-utils
log_success "System packages installed successfully."

# --- WiringPi Installation ---

log_info "Checking for WiringPi library..."

# Verify that the repository URL variable is set.
: "${WIRINGPI_REPO:?Variable WIRINGPI_REPO is not set. Cannot download WiringPi.}"

# Check if the 'gpio' command (part of WiringPi) is already available.
if ! command -v gpio &> /dev/null; then
    log_info "WiringPi not found. Cloning and building from repository..."
    
    # Clone from the specified repository.
    git clone "$WIRINGPI_REPO"
    
    # Enter the directory, build, and then clean up.
    cd WiringPi
    ./build
    cd ..
    # Remove the cloned repository folder to keep the project directory clean.
    rm -rf WiringPi
    
    log_success "WiringPi successfully installed."
else
    log_success "WiringPi is already installed. Skipping."
fi
