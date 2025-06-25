#!/bin/bash
# ==============================================================================
# BAMBULAPSE CAMERA CONFIG SCRIPT INSTALLER
#
# Author: @thidiasr
#
# This script creates the 'cfgcamera' utility in /usr/local/bin.
# The 'cfgcamera' utility provides an interactive menu to configure
# the Motion service settings for the connected camera.
# ==============================================================================

# --- Configuration and Safety Nets ---
# -e: exit on error, -u: exit on unset variables, -o pipefail: pipeline exit status
set -euo pipefail

# --- Source Shared Functions ---
# Load the common library for logging and utility functions.
# This makes the installation process more verbose and user-friendly.
source "$(dirname "$0")/common.sh"

log_info "Creating the camera configuration utility: 'cfgcamera'..."

# --- Create the 'cfgcamera' script using a Heredoc ---
# This entire block of code will be written to /usr/local/bin/cfgcamera.
# Using 'EOF' with quotes prevents shell expansion within the heredoc,
# ensuring that variables like $MOTION_CONF are interpreted when cfgcamera is run, not now.
tee /usr/local/bin/cfgcamera > /dev/null << 'EOF'
#!/bin/bash
# ==============================================================================
# Camera Configuration Utility (cfgcamera)
#
# Author: @thidiasr
#
# This utility provides an interactive TUI menu to safely edit the
# /etc/motion/motion.conf file. It detects connected cameras and their
# capabilities to guide the user through the configuration process.
# ==============================================================================

# --- Configuration and Safety Nets ---
set -euo pipefail

# --- Global Constants and Variables ---
# Main configuration file for the Motion service.
MOTION_CONF="/etc/motion/motion.conf"
# Location for the one-time backup of the original configuration.
BACKUP_CONF="/etc/motion/motion.conf.bambulapse.bak"
# Arrays to cache device information, preventing repeated slow calls.
declare -a DEVICE_NAMES
declare -a DEVICE_PATHS
declare -a seen_names
REGISTERED_ALIAS=""

# --- Logging Functions ---
# Provides consistent, colored feedback to the user.
# These are self-contained so the script has no external dependencies.
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_RED='\033[0;31m'
COLOR_RESET='\033[0m'
log_info() { echo -e "${COLOR_YELLOW}[INFO] $1${COLOR_RESET}"; }
log_success() { echo -e "${COLOR_GREEN}[SUCCESS] $1${COLOR_RESET}"; }
log_error() { echo -e "${COLOR_RED}[ERROR] $1${COLOR_RESET}" >&2; exit 1; }

# --- Pre-flight Checks ---
# Ensure the script runs in a valid environment before proceeding.
if [ "$(id -u)" -ne 0 ]; then log_error "This script must be run with sudo."; fi
if ! command -v v4l2-ctl &> /dev/null; then log_error "'v4l2-ctl' not found. Please install 'v4l-utils'."; fi
if [ ! -f "$MOTION_CONF" ]; then log_error "Motion config file not found at '$MOTION_CONF'."; fi

# --- Core Functions ---

# Loads all current camera settings from motion.conf in a single pass.
load_current_values() {
    log_info "Loading current configuration from $MOTION_CONF..."
    #//***This uses awk to parse the config file once for efficiency.***
    #//***'eval' is used here to set multiple shell variables from awk's output.***
    #//***It's safe because the input is the trusted motion.conf file.***
    eval $(awk -F'[[:space:]]+' '
        /^[[:space:]]*video_device/ {gsub("/dev/video", "", $2); print "VIDEO_DEVICE=" $2}
        /^[[:space:]]*width/ {print "WIDTH=" $2}
        /^[[:space:]]*height/ {print "HEIGHT=" $2}
        /^[[:space:]]*target_dir/ {print "TARGET_DIR=" $2}
        /^[[:space:]]*video_params/ {
            gsub(/.*width=[^,]+,height=[^,]+,framerate=[^,]+,palette=/, "", $0);
            gsub(/,ID09963776=/, ";", $0); gsub(/,ID09963778=/, ";", $0);
            split($0, p, ";");
            print "PIXELFORMAT=" p[1]; print "BRIGHTNESS=" p[2]; print "SATURATION=" p[3];
        }
    ' "$MOTION_CONF")
}

# Creates a one-time backup of the original motion.conf file for safety.
create_backup() {
    if [ ! -f "$BACKUP_CONF" ]; then
        log_info "Creating configuration backup at $BACKUP_CONF..."
        cp "$MOTION_CONF" "$BACKUP_CONF"
        log_success "Backup created."
    fi
}

# Writes the staged changes from shell variables back into the motion.conf file.
apply_config() {
    local alias="${1:-}"  # <- Aqui está a correção: evita erro se $1 não for passado

    log_info "Applying new configuration..."

    local device_path
    if [ -n "$alias" ]; then
        device_path="/dev/$alias"
    else
        device_path="/dev/video${VIDEO_DEVICE}"
    fi

    sed -i -E "s|^video_device .*|video_device $device_path|" "$MOTION_CONF"
    sed -i -E "s|^width .*|width $WIDTH|" "$MOTION_CONF"
    sed -i -E "s|^height .*|height $HEIGHT|" "$MOTION_CONF"
    sed -i -E "s|^target_dir .*|target_dir $TARGET_DIR|" "$MOTION_CONF"

    local new_video_params="video_params width=${WIDTH},height=${HEIGHT},framerate=30,palette=${PIXELFORMAT},ID09963776=${BRIGHTNESS},ID09963778=${SATURATION}"
    sed -i -E "s|^video_params .*|$new_video_params|" "$MOTION_CONF"

    log_success "Configuration saved successfully!"
}

# --- Device and Format Logic ---

# Caches the list of available USB devices to avoid slow, repeated v4l2-ctl calls.
update_device_cache() {
    DEVICE_NAMES=()
    DEVICE_PATHS=()
    declare -A seen_names

    local full_output
    full_output=$(v4l2-ctl --list-devices 2>/dev/null || true)
    if [ -z "$full_output" ]; then return; fi

    local device_list
    device_list=$(echo "$full_output" | awk '
        /^[^\t]/ {
            if ($0 ~ /usb-/) {
                is_usb = 1
                name = $0
                sub(/ \(usb-.*/, "", name)
            } else {
                is_usb = 0
            }
        }
        /^\t/ && is_usb == 1 {
            if ($1 ~ /^\/dev\/video[0-9]+/) {
                print name ";" $1
            }
        }
    ')

    if [ -n "$device_list" ]; then
        while IFS=';' read -r current_name current_path; do
            # Corrige espaços nos nomes
            current_name="$(echo "$current_name" | xargs)"
            if [[ -z "${seen_names[$current_name]+_}" ]]; then
                seen_names["$current_name"]=1
                DEVICE_NAMES+=("$current_name")
                DEVICE_PATHS+=("$current_path")
            fi
        done <<< "$device_list"
    fi
}

register_webcam_alias() {
    VIDEO_DEVICE="${VIDEO_DEVICE##*/video}"
    local dev_path="/dev/video${VIDEO_DEVICE}"
    local udev_rule_file="/etc/udev/rules.d/99-local.rules"

    if [ ! -e "$dev_path" ]; then
        log_error "Device $dev_path does not exist."
        return 1
    fi

    local id_vendor id_product
    id_vendor=$(udevadm info --query=all --name="$dev_path" | grep "ID_VENDOR_ID" | cut -d'=' -f2)
    id_product=$(udevadm info --query=all --name="$dev_path" | grep "ID_MODEL_ID" | cut -d'=' -f2)

    if [ -z "$id_vendor" ] || [ -z "$id_product" ]; then
        log_info "idVendor/idProduct not found. Using original path (/dev/videoX)."
        REGISTERED_ALIAS=""
        return 0
    fi

    local existing_line=""
    if [ -f "$udev_rule_file" ]; then
        existing_line=$(grep "$id_vendor" "$udev_rule_file" | grep "$id_product" || true)
    fi

    if [ -n "$existing_line" ]; then
        REGISTERED_ALIAS=$(echo "$existing_line" | grep -oP 'SYMLINK\+="\K[^"]+')
        return 0
    fi

    # if no alias exists, create a new one
    while [ -f "$udev_rule_file" ] && grep -q "webcam$i" "$udev_rule_file"; do
        ((i++))
    done
    alias="webcam$i"

    echo "Creating alias: $alias"

    # Create the udev rule to create a symlink for the webcam
    sudo bash -c "echo 'SUBSYSTEM==\"video4linux\", ATTRS{idVendor}==\"$id_vendor\", ATTRS{idProduct}==\"$id_product\", SYMLINK+=\"$alias\"' >> \"$udev_rule_file\""
    sudo udevadm control --reload-rules
    sudo udevadm trigger

    REGISTERED_ALIAS="$alias"
    log_success "Webcam registered as /dev/$REGISTERED_ALIAS"
    return 0
}

# Gets the friendly name (e.g., "HD Logitech Webcam") of the current device from the cache.
get_current_device_name() {
    local target_path="/dev/video${VIDEO_DEVICE}"
    for i in "${!DEVICE_PATHS[@]}"; do
        if [[ "${DEVICE_PATHS[$i]}" == "$target_path" ]]; then
            echo "${DEVICE_NAMES[$i]}"
            return
        fi
    done
    echo "$target_path (Name not found)" # Fallback if not found in cache.
}

# Maps a V4L2 format name (FourCC code) to its corresponding Motion palette ID.
map_format_to_palette_id() {
    #//***These numeric IDs correspond to Motion's internal 'palette' enum.***
    #//***Refer to Motion documentation for a complete list if needed.***
    local format_name=$1
    case $format_name in
        "S910") echo 0 ;; "BYR2") echo 1 ;; "BA81") echo 2 ;; "S561") echo 3 ;;
        "GBRG") echo 4 ;; "GRBG") echo 5 ;; "P207") echo 6 ;; "PJPG") echo 7 ;;
        "MJPG") echo 8 ;; "JPEG") echo 9 ;; "RGB3") echo 10 ;; "S501") echo 11 ;;
        "S505") echo 12 ;; "S508") echo 13 ;; "UYVY") echo 14 ;; "YUYV") echo 15 ;;
        "422P") echo 16 ;; "YU12") echo 17 ;; "Y10") echo 18 ;; "Y12") echo 19 ;;
        "GREY") echo 20 ;; "H264") echo 8 ;; # H264 is often handled as MJPG by Motion.
        *)
            log_info "Unsupported format '$1', defaulting to palette 8 (JPEG)."
            echo 8
            ;;
    esac
}

# --- Selection Menus ---

# Builds and displays an interactive menu manually to ensure a consistent, single-column layout.
# This avoids the default multi-column behavior of the 'select' command on wide terminals.
select_usb_device() {
    # (The logic of the select functions is clear, so comments are minimal)
    if [ ${#DEVICE_NAMES[@]} -eq 0 ]; then log_error "No USB cameras found."; fi
    local options=(); for i in "${!DEVICE_NAMES[@]}"; do options+=("${DEVICE_NAMES[$i]} (${DEVICE_PATHS[$i]})"); done; options+=("Cancel")
    clear; echo "Please select a USB camera:"; for i in "${!options[@]}"; do echo "  $((i+1))) ${options[$i]}"; done
    while true; do
        read -p "Your choice: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#options[@]} ]; then
            local chosen_index=$((choice - 1)); if [[ "${options[$chosen_index]}" == "Cancel" ]]; then log_info "Selection cancelled."; return 1; fi
            VIDEO_DEVICE="${DEVICE_PATHS[$chosen_index]//[^0-9]/}"; log_success "Selected device: ${options[$chosen_index]}"; sleep 1; return 0;
        else echo "Invalid option. Please try again."; fi
    done
}

select_pixel_format() {
    log_info "Fetching available pixel formats for /dev/video$VIDEO_DEVICE..."
    local options=($(v4l2-ctl --list-formats-ext --device="/dev/video$VIDEO_DEVICE" | grep -oP "'\K[^']+(?=')"))
    if [ ${#options[@]} -eq 0 ]; then log_error "Could not find any pixel formats."; fi
    options+=("Cancel"); clear; echo "Select a pixel format:"; for i in "${!options[@]}"; do echo "  $((i+1))) ${options[$i]}"; done
    while true; do
        read -p "Your choice: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#options[@]} ]; then
            local chosen_index=$((choice - 1)); local selection="${options[$chosen_index]}"; if [[ "$selection" == "Cancel" ]]; then return 1; fi
            SELECTED_PIXEL_FORMAT=$selection; return 0;
        else echo "Invalid option. Please try again."; fi
    done
}

# Presents a menu for selecting a resolution, handling different camera output formats.
select_resolution() {
    local format_to_find=$1
    log_info "Fetching resolutions for format '$format_to_find'..."
    # This awk script is designed to handle both "Size: Discrete" and "Size: Stepwise" outputs from v4l2-ctl.
    local options
    options=($(v4l2-ctl --list-formats-ext --device="/dev/video$VIDEO_DEVICE" \
        | awk -v format="'$format_to_find'" '
            $0 ~ format {in_block=1}
            /\[[0-9]+\]:/ && !($0 ~ format) {in_block=0}
            in_block && /Size: Discrete/ {print $3}
            in_block && /Size: Stepwise/ {print $4}
        '))

    if [ ${#options[@]} -eq 0 ]; then
        log_error "No resolutions found for format $format_to_find. The camera may not support it properly."
    fi

    # Sort resolutions numerically by width, then height (descending) and remove duplicates.
    # -t'x': use 'x' as delimiter.
    # -k1,1nr: sort by 1st field, numeric, reverse.
    # -k2,2nr: sort by 2nd field, numeric, reverse (tie-breaker).
    # uniq: remove duplicate entries.
    options=($(printf "%s\n" "${options[@]}" | sort -t'x' -k1,1nr -k2,2nr | uniq))
    options+=("Cancel")

    clear
    echo "Select a resolution for $format_to_find:"
    for i in "${!options[@]}"; do echo "  $((i+1))) ${options[$i]}"; done

    while true; do
        read -p "Your choice: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#options[@]} ]; then
            local chosen_index=$((choice - 1)); local selection="${options[$chosen_index]}"
            if [[ "$selection" == "Cancel" ]]; then return 1; fi
            WIDTH=$(echo "$selection"|cut -d'x' -f1); HEIGHT=$(echo "$selection"|cut -d'x' -f2); return 0;
        else echo "Invalid option. Please try again."; fi
    done
}


# --- Main Menu Loop ---

# Perform initial setup once.
create_backup
load_current_values
update_device_cache

# The main event loop for the user interface.
while true; do
    CURRENT_DEVICE_NAME=$(get_current_device_name)
    clear
    echo "==================== Camera Configuration Menu ===================="
    echo " 1) Brightness (0-255)   : $BRIGHTNESS"
    echo " 2) Saturation (-100-100): $SATURATION"
    echo " 3) Snapshot Path        : $TARGET_DIR"
    echo " 4) Video Device         : $CURRENT_DEVICE_NAME (/dev/video$VIDEO_DEVICE)"
    echo " 5) Resolution & Format  : ${WIDTH}x${HEIGHT}"
    echo "-----------------------------------------------------------------"
    echo " S) Save and Apply Changes   Q) Quit Without Saving"
    echo " R) Restore from Backup"
    echo "================================================================="
    read -p "Select an option: " -n 1 -r OPTION; echo

    case $OPTION in
        1) read -p "Enter new brightness (0-255): " val; if [[ "$val" =~ ^[0-9]+$ && "$val" -ge 0 && "$val" -le 255 ]]; then BRIGHTNESS="$val"; else log_info "Invalid input." && sleep 2; fi ;;
        2) read -p "Enter new saturation (-100 to 100): " val; if [[ "$val" =~ ^-?[0-9]+$ && "$val" -ge -100 && "$val" -le 100 ]]; then SATURATION="$val"; else log_info "Invalid input." && sleep 2; fi ;;
        3) read -e -p "Enter new snapshot path: " -i "$TARGET_DIR" val; if [ -d "$val" ]; then TARGET_DIR="$val"; else log_info "Directory does not exist." && sleep 2; fi ;;
        4) if select_usb_device; then update_device_cache; fi ;;
        5) if select_pixel_format && select_resolution "$SELECTED_PIXEL_FORMAT"; then PIXELFORMAT=$(map_format_to_palette_id "$SELECTED_PIXEL_FORMAT"); log_success "Selection updated."; else log_info "Selection cancelled."; fi; sleep 2 ;;
        [sS])
            register_webcam_alias
            if [ -n "$REGISTERED_ALIAS" ]; then
                log_success "Alias registrado: /dev/$REGISTERED_ALIAS"
            else
                log_info "Nenhum alias registrado. Usando /dev/video$VIDEO_DEVICE"
            fi
            apply_config "${REGISTERED_ALIAS:-}"
            log_info "Exiting."
            exit 0
        ;;
        [rR]) if [ -f "$BACKUP_CONF" ]; then cp "$BACKUP_CONF" "$MOTION_CONF"; log_success "Backup restored!"; load_current_values; else log_info "No backup file found."; fi; sleep 2 ;;
        [qQ]) log_info "Exiting without saving changes."; exit 0 ;;
        *) log_info "Invalid option." && sleep 1 ;;
    esac
done
EOF

# --- Finalization ---
# Set execute permission for the newly created utility
chmod +x /usr/local/bin/cfgcamera
log_success "'cfgcamera' utility has been created successfully."
log_info "You can now run 'sudo cfgcamera' to configure your camera."