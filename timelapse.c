#include <stdio.h>
#include <stdlib.h>
#include <wiringPi.h>
#include <sys/time.h>
#include <unistd.h>
#include "gpio_config.h"

#define TIMEOUT 20000

#define MEASURE_DELAY 30000
#define TRYS 5

long get_microseconds() {
    struct timeval t;
    gettimeofday(&t, NULL);
    return (t.tv_sec * 1000000L) + t.tv_usec;
}

float measure() {
    long start_time, end_time;
    float distance;

    digitalWrite(TRIG, LOW);
    delayMicroseconds(2);
    digitalWrite(TRIG, HIGH);
    delayMicroseconds(10);
    digitalWrite(TRIG, LOW);

    start_time = get_microseconds();
    while (digitalRead(ECHO) == LOW && (get_microseconds() - start_time) < TIMEOUT);

    start_time = get_microseconds();
    while (digitalRead(ECHO) == HIGH && (get_microseconds() - start_time) < TIMEOUT);

    end_time = get_microseconds();

    long duration = end_time - start_time;
    distance = duration / 58.0;

    return distance > 0 && distance < 500 ? distance : -1.0;
}

int compare(const void *a, const void *b) {
    float fa = *(float *)a;
    float fb = *(float *)b;
    return (fa > fb) - (fa < fb);
}

float stable_measure() {
    float readings[TRYS];
    int valid = 0;

    for (int i = 0; i < TRYS; i++) {
        float reading = measure();
        if (reading > 0) {
            readings[valid++] = reading;
        }
        usleep(MEASURE_DELAY);
    }

    if (valid == 0) return -1;

    qsort(readings, valid, sizeof(float), compare);
    return readings[valid / 2];
}

int main() {
    wiringPiSetup();

    pinMode(TRIG, OUTPUT);
    pinMode(ECHO, INPUT);

    digitalWrite(TRIG, LOW);

    system("sudo motion -c /etc/motion/motion.conf");

    while (1) {
        float distance = stable_measure();

        if (distance > 0) {
            if (distance < 4.5) {
                sleep(2);
                system("curl -s http://localhost:8081/0/action/snapshot");
                while (distance < 5 || distance > 36) {
                    sleep(1);
                    distance = stable_measure();
                }
            } else {
                usleep(60000);
            }
        } else {
            usleep(100000);
        }
    }

    return 0;
}
