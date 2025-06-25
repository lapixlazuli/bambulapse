#!/bin/bash
# ==============================================================================
# COMMON FUNCTIONS LIBRARY
#
# Author: @thidiasr
#
# This file contains shared functions (like logging with colors) to be used
# by other scripts in the project, promoting code reuse and consistency.
# ==============================================================================

# Define color codes for logging
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
