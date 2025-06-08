/**
 * @file main.c
 * @brief Ultrasonic sensor-triggered timelapse controller.
 * This program uses an HC-SR04 sensor to measure distance.  When the nozzle
 * is detected within a specific range (SNAPSHOTDISTANCE), it triggers a snapshot
 * via the Motion service's web interface. It then waits until the object
 * moves beyond another range (RESETDISTANCE) before resuming normal operation.
 */

#include <stdio.h>
#include <stdlib.h>
#include <wiringPi.h>
#include <sys/time.h>
#include <unistd.h>
#include "gpio_config.h"
#include "distance_config.h"

// Define constants for sensor reading
#define TIMEOUT 20000         // Sensor read timeout in microseconds
#define MEASURE_DELAY 30000  // Delay between each measurement in microseconds.
#define TRYS 5              // Number of readings to take for a stable measurement

/**
 * @brief Get current system time in microseconds.
 * @return The current time as a long integer.
 */
long get_microseconds() {
    struct timeval t;
    gettimeofday(&t, NULL);
    return (t.tv_sec * 1000000L) + t.tv_usec;
}

/**
 * @brief Performs a single distance measurement using the ultrasonic sensor.
 * @return The measured distance in cm, or -1.0 on failure/timeout.
 */
float measure() {
    // Add the variable declarations here at the top
    long pulse_start, pulse_end;
    float distance;

    // Send a 10µs trigger pulse
    digitalWrite(TRIG, LOW);
    delayMicroseconds(2);
    digitalWrite(TRIG, HIGH);
    delayMicroseconds(10);
    digitalWrite(TRIG, LOW);

    // Wait for the echo pulse to begin, with a timeout
    long wait_start = get_microseconds();
    while (digitalRead(ECHO) == LOW) {
        if (get_microseconds() - wait_start > TIMEOUT) return -1.0;
    }
    pulse_start = get_microseconds(); // Now the compiler knows what pulse_start is

    // Measure the duration of the echo pulse, with a timeout
    while (digitalRead(ECHO) == HIGH) {
        if (get_microseconds() - pulse_start > TIMEOUT) return -1.0;
    }
    pulse_end = get_microseconds(); // Now the compiler knows what pulse_end is

    // Calculate distance from the pulse duration
    long duration = pulse_end - pulse_start;
    distance = duration / 58.0;

    // Return the distance if it's within a valid range
    return (distance > 0 && distance < 500) ? distance : -1.0;
}

/**
 * @brief Comparator function for qsort to sort float values.
 */
int compare(const void *a, const void *b) {
    float fa = *(float *)a;
    float fb = *(float *)b;
    return (fa > fb) - (fa < fb);
}

/**
 * @brief Takes multiple readings and returns the median for a stable result.
 * @return The median distance in cm, or -1.0 if no valid readings are obtained.
 */
float stable_measure() {
    float readings[TRYS];
    int valid = 0;

    // Collect multiple readings, filtering out invalid ones.
    for (int i = 0; i < TRYS; i++) {
        float reading = measure();
        if (reading > 0) {
            readings[valid++] = reading;
        }
        usleep(MEASURE_DELAY);
    }

    // Return error if no valid measurements were taken.
    if (valid == 0) return -1;

    // Sort readings and return the median value to filter outliers.
    qsort(readings, valid, sizeof(float), compare);
    return readings[valid / 2];
}

/**
 * @brief Main function to initialize hardware and run the distance measurement loop with timelapse snapshots.
 */
int main() {
    // Initialize GPIO using wiringPi library.
    wiringPiSetup();
    pinMode(TRIG, OUTPUT);
    pinMode(ECHO, INPUT);
    // Ensure trigger pin is low initially.
    digitalWrite(TRIG, LOW);
    sleep(1);// Wait for sensor to settle.

    // Start the Motion service in the background.
    system("sudo motion -c /etc/motion/motion.conf");
    sleep(2); // Give Motion time to start up.

    // Main application loop.
    while (1) {
        float distance = stable_measure();

        // Process a valid reading.
        if (distance > 0) {
            if (distance < SNAPSHOTDISTANCE) {
                // Give camera time to stabilize and take a snapshot.
                sleep(2);
                system("curl -s http://localhost:8081/0/action/snapshot");
                while (distance < RESETDISTANCE) {
                    //Wait for the nozzle to move away.
                    sleep(1);
                    distance = stable_measure();
                }
            } else {
                // Short delay during idle periods to prevent high CPU usage.
                usleep(60000);
            }
        } else {
            // Longer delay on reading failure before retrying.
            usleep(100000);
        }
    }

    return 0;
}
