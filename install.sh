#!/bin/bash

source config.sh

sudo apt-get update
sudo apt-get install -y motion git build-essential curl
sudo apt-get install -y v4l-utils

if ! command -v gpio &> /dev/null; then
    git clone "$WIRINGPI_REPO"
    cd WiringPi
    ./build
    cd ..
    rm -rf WiringPi
fi

MOTION_CONF="/etc/motion/motion.conf"
BACKUP_CONF="/etc/motion/motion.conf.bak"

CONF_BASE="daemon on
target_dir $DIR
video_device /dev/video$VIDEODEVICE
video_params width=$WIDTH,height=$HEIGHT,framerate=2,v4l2_palette=$PIXEL_FORMAT,palette=$PIXEL_FORMAT,ID09963776=${BRIGHTNESS},ID09963778=${SATURATION}
picture_type jpeg
width $WIDTH
height $HEIGHT
snapshot_filename %m-%d-%Y_%H-%M-%S-snapshot
camera_id 0
framerate 2
text_left
text_right
text_scale 0
text_event
noise_level 1
noise_tune off
picture_quality 95
snapshot_interval 0
stream_port 8080
stream_localhost off
picture_output off
movie_output off
webcontrol_port 8081
webcontrol_localhost off
"

if [ -f "$MOTION_CONF" ]; then
    if [ ! -f "$BACKUP_CONF" ]; then
        sudo cp "$MOTION_CONF" "$BACKUP_CONF"
    fi
else
    echo "$CONF_BASE" | sudo tee "$MOTION_CONF" > /dev/null
    sudo cp "$MOTION_CONF" "$BACKUP_CONF"
fi

add_or_replace() {
    local key="$1"
    local value="$2"
    if grep -Eq "^[;#]*\s*${key}" "$MOTION_CONF"; then
        sudo sed -i -E "s|^[;#]*\s*${key}.*|${key} ${value}|" "$MOTION_CONF"
    else
        echo "${key} ${value}" | sudo tee -a "$MOTION_CONF" > /dev/null
    fi
}

update_video_params() {
    local PARAMS="width=${WIDTH},height=${HEIGHT},framerate=2,v4l2_palette=${PIXEL_FORMAT},palette=${PIXEL_FORMAT},ID09963776=${BRIGHTNESS},ID09963778=${SATURATION}"

    if grep -Eq "^[;#]*\s*video_params" "$MOTION_CONF"; then
        sudo sed -i -E "s|^[;#]*\s*video_params.*|video_params ${PARAMS}|" "$MOTION_CONF"
    else
        echo "video_params ${PARAMS}" | sudo tee -a "$MOTION_CONF" > /dev/null
    fi
}

add_or_replace "daemon" "on"
add_or_replace "log_level" "4"
add_or_replace "target_dir" "$DIR"
add_or_replace "video_device" "/dev/video$VIDEODEVICE"
add_or_replace "width" "$WIDTH"
add_or_replace "height" "$HEIGHT"
add_or_replace "text_left" ""
add_or_replace "framerate" "2"
add_or_replace "stream_localhost" "off"
add_or_replace "snapshot_filename" "%m-%d-%Y_%H-%M-%S-snapshot"
add_or_replace "text_scale" "0"
add_or_replace "text_event" ""
add_or_replace "noise_tune" "off"
add_or_replace "picture_quality" "95"
add_or_replace "text_right" ""
add_or_replace "noise_level" "1"
add_or_replace "picture_output" "off"
add_or_replace "movie_output" "off"
add_or_replace "webcontrol_port" "8081"
add_or_replace "webcontrol_localhost" "off"
update_video_params

echo "// Auto-generated GPIO config" > gpio_config.h
echo "#define TRIG $GPIO_TRIG" >> gpio_config.h
echo "#define ECHO $GPIO_ECHO" >> gpio_config.h

gcc timelapse.c -o timelapse -lwiringPi
sudo mv timelapse /usr/local/bin/
sudo chmod +x /usr/local/bin/timelapse

echo -e '#!/bin/bash\nnohup timelapse > ~/timelapse.log 2>&1 &' | sudo tee /usr/local/bin/start-timelapse > /dev/null
sudo chmod +x /usr/local/bin/start-timelapse

echo -e '#!/bin/bash\ncurl -s http://localhost:8081/0/action/snapshot' | sudo tee /usr/local/bin/snapshot > /dev/null
sudo chmod +x /usr/local/bin/snapshot

sudo tee /usr/local/bin/stop-timelapse > /dev/null << 'EOF'
#!/bin/bash

MOTION_PID=$(pgrep -f motion)
if [ ! -z "$MOTION_PID" ]; then
    sudo kill $MOTION_PID
    echo "Finish Timelapse (PID $MOTION_PID)"
else
    echo "No processes found"
fi

pkill timelapse
EOF

sudo chmod +x /usr/local/bin/stop-timelapse

sudo tee /usr/local/bin/config-camera > /dev/null << 'EOF'
#!/bin/bash
source "/home/lehft/bambulapse/config.sh"
MOTION_CONF="/etc/motion/motion.conf"
BACKUP_CONF="/etc/motion/motion.conf.bak"

update_video_params() {
    local PARAMS="width=${WIDTH},height=${HEIGHT},framerate=2,v4l2_palette=${PIXEL_FORMAT},palette=${PIXEL_FORMAT},ID09963776=${BRIGHTNESS},ID09963778=${SATURATION}"

    if grep -q "^[;#]*\?\s*video_params" "$MOTION_CONF"; then
        sudo sed -i "s|^[;#]*\?\s*video_params.*|video_params ${PARAMS}|" "$MOTION_CONF"
    else
        echo "video_params ${PARAMS}" | sudo tee -a "$MOTION_CONF" > /dev/null
    fi
}
update_target_dir() {
    if grep -q "^target_dir" "$MOTION_CONF"; then
        sudo sed -i "s|^target_dir .*|target_dir $TARGET_DIR|" "$MOTION_CONF"
    else
        echo "target_dir $TARGET_DIR" | sudo tee -a "$MOTION_CONF" > /dev/null
    fi
}

update_video_device() {
    if grep -q "^video_device" "$MOTION_CONF"; then
        sudo sed -i "s|^video_device .*|video_device /dev/video$VIDEO_DEVICE|" "$MOTION_CONF"
    else
        echo "video_device /dev/video$VIDEO_DEVICE" | sudo tee -a "$MOTION_CONF" > /dev/null
    fi
}

if [ ! -f "$MOTION_CONF" ]; then 
   echo "File $MOTION_CONF not found."
    exit 1
fi

if [ ! -f "$BACKUP_CONF" ]; then
    sudo cp "$MOTION_CONF" "$BACKUP_CONF"
fi

NOWBRIGHTNESS=$(grep -oP 'ID09963776=\\K[0-9]+' "$MOTION_CONF" || echo 50)
NOWSATURATION=$(grep -oP 'ID09963778=\\K-?[0-9]+' "$MOTION_CONF" || echo 50)
TARGET_DIR=$(grep "^target_dir" "$MOTION_CONF" | awk '{print $2}')
[ -z "$TARGET_DIR" ] && TARGET_DIR="/var/lib/motion"

apply_config() {
    update_video_params
    update_target_dir
    update_video_device
}

while true; do
    clear
    echo "===== Camera Configuration ====="
    echo "Brightness (ID09963776): $NOWBRIGHTNESS"
    echo "Saturation (ID09963778): $NOWSATURATION"
    echo "Snapshot Directory: $TARGET_DIR"
    echo "================================"
    echo "1) Change Brightness"
    echo "2) Change Saturation"
    echo "3) Change Snapshot Directory"
    echo "4) Change Video Device"
    echo "5) Apply Configuration"
    echo "6) Restore Backup"
    echo "0) Exit"
    echo "================================"
    read -p "Select an option: " OPTION

    case $OPTION in
        1)
            read -p "New Brightness (0-127): " NOWBRIGHTNESS
            ;;
        2)
            read -p "New Saturation (-100 to 100): " NOWSATURATION
            ;;
        3)
            read -p "New Snapshot Directory: " NEW_DIR
            if [ -d "$NEW_DIR" ]; then
                TARGET_DIR="$NEW_DIR"
            else
                echo "Directory does not exist."
                sleep 2
            fi
            ;;
        4)
            read -p "Enter Video Device Number (e.g., 0 for /dev/video0): " NEW_DEVICE
            if [[ "$NEW_DEVICE" =~ ^[0-9]+$ ]]; then
                VIDEO_DEVICE="$NEW_DEVICE"
            else
                echo "Invalid device number."
                sleep 2
            fi
            ;;    
        5)
            apply_config
            read -p "Press ENTER to continue..."
            ;;
        6)
            sudo cp "$BACKUP_CONF" "$MOTION_CONF"
            NOWBRIGHTNESS=$(grep -oP 'ID09963776=\\K[0-9]+' "$MOTION_CONF" || echo 50)
            NOWSATURATION=$(grep -oP 'ID09963778=\\K-?[0-9]+' "$MOTION_CONF" || echo 0)
            TARGET_DIR=$(grep "^target_dir" "$MOTION_CONF" | awk '{print $2}')
            [ -z "$TARGET_DIR" ] && TARGET_DIR="/var/lib/motion"
            VIDEO_DEVICE=$(grep "^video_device" "$MOTION_CONF" | awk -F'/dev/video' '{print $2}')
            [ -z "$VIDEO_DEVICE" ] && VIDEO_DEVICE="0"
            read -p "Backup restored. Press ENTER to continue..."
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Invalid option."
            sleep 1
            ;;
    esac
done

EOF

sudo chmod +x /usr/local/bin/config-camera

echo "Installation completed!"
echo "Use:"
echo "tart-timelapse to start"
echo "top-timelapse to stop"
echo "napshot to take snapshot"
echo "config-camera to adjust camera settings"