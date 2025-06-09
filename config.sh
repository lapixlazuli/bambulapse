# ==============================================================================
# BAMBULAPSE PROJECT CONFIGURATION
#
# This file contains all the user-configurable variables for the installation.
# Modify these values before running the main 'install.sh' script.
# ==============================================================================

# --- Camera Settings ---
# These values are written to the motion.conf file.
# They can be changed later using the 'sudo cfgcamera' command.

# Camera device number. Find yours with 'v4l2-ctl --list-devices'.
# Usually 0, 2, 4, etc.
VIDEODEVICE=0

# Default resolution for the camera.
WIDTH=1920
HEIGHT=1080

# Default brightness and saturation.
# Brightness is typically 0-255, Saturation -100 to 100.
BRIGHTNESS=52
SATURATION=52

# The camera's pixel format ID for Motion.
# This value can be found and set via the 'cfgcamera' tool after installation.
# 8 (MJPG) is a very common and safe default.
PIXEL_FORMAT=8


# --- Project Settings ---

# The absolute path where timelapse snapshots will be saved.
# Make sure this directory exists and has the correct write permissions.
# Example: "/home/pi/TimelapseShare" or "/mnt/usb_drive/snapshots"
DIR="/home/lehft/TimelapseShare"


# --- Sensor (HC-SR04) Settings ---
# These values define the GPIO pins for the ultrasonic sensor.
# They can be changed later using the 'sudo cfgdistance' command.

# The GPIO pins according to WIRINGPI's numbering scheme.
# Run 'gpio readall' to see the mapping for your Raspberry Pi model.
GPIO_TRIG=2  # wPi pin 4 corresponds to physical pin 16 (GPIO 23)
GPIO_ECHO=5  # wPi pin 5 corresponds to physical pin 18 (GPIO 24)


# --- Dependency Settings ---

# The repository URL for cloning the WiringPi library.
# The original repo is deprecated; this is a well-maintained mirror.
WIRINGPI_REPO="https://github.com/WiringPi/WiringPi.git"
