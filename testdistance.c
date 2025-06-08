#include <stdio.h>
#include <stdlib.h>
#include <wiringPi.h>
#include <unistd.h>
#include <sys/time.h>
#include "gpio_config.h"
#include "distance_config.h"

#define TIMEOUT 20000         // 20 ms
#define MEASURE_DELAY 30000   // 30 ms entre tentativas
#define TRYS 5

long get_microseconds() {
    struct timeval t;
    gettimeofday(&t, NULL);
    return (t.tv_sec * 1000000L) + t.tv_usec;
}

float measure() {
    long pulse_start, pulse_end;
    float distance;

    digitalWrite(TRIG, LOW);
    delayMicroseconds(2);
    digitalWrite(TRIG, HIGH);
    delayMicroseconds(10);
    digitalWrite(TRIG, LOW);

    long start_time = get_microseconds();
    while (digitalRead(ECHO) == LOW) {
        if ((get_microseconds() - start_time) > TIMEOUT) return -1.0;
    }
    pulse_start = get_microseconds();

    start_time = get_microseconds();
    while (digitalRead(ECHO) == HIGH) {
        if ((get_microseconds() - start_time) > TIMEOUT) return -1.0;
    }
    pulse_end = get_microseconds();

    long duration = pulse_end - pulse_start;
    distance = duration / 58.0;

    return (distance > 0 && distance < 500) ? distance : -1.0;
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
    sleep(1); // Dá tempo para o sensor estabilizar

    system("clear");
    printf("Start test with SNAPSHOT=%.2f e RESET=%.2f\n", SNAPSHOTDISTANCE, RESETDISTANCE);
    printf("Press ENTER to start measure...");
    getchar();

    while (1) {
        float distance = stable_measure();

        if (distance > 0) {
            printf("Distance measure: %.2f cm\n", distance);
            if (distance < SNAPSHOTDISTANCE) {
                printf("ATTENTION ----> MEASURES <---- ATTENTION");
                printf(">> Inside snapshot distance!");
                printf(">> Last distance measure: %.2f cm\n", distance);
                printf(">> Current snapshot distance config: %.2f cm\n", SNAPSHOTDISTANCE);
                sleep(2);
                printf(">> Waiting to continue printing\n");
                while (distance < RESETDISTANCE) {
                    printf(">> Waiting to continue printing\n");
                    sleep(1);
                    distance = stable_measure();
                }
                printf("ATTENTION ----> MEASURES <---- ATTENTION");
                printf(">> Inside reset distance!");
                printf(">> Last distance measure: %.2f cm\n", distance);
                printf(">> Current reset distance config: %.2f cm\n", RESETDISTANCE);

            } else {
                usleep(60000);
            }
        } else {
            printf("Leitura falhou.\n");
            usleep(100000);
        }
    }
    return 0;
}

