/* Model-independent exact integer control. No process/system tuning. */
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define COUNT 65536u
#define STEPS 32u
static unsigned long long processor_histogram[64];

static int save_vector(const char *folder, const uint32_t *data) {
    char path[1024]; FILE *file;
    snprintf(path, sizeof(path), "%s/native_vector.bin", folder);
    file = fopen(path, "wb");
    if (!file) return 0;
    if (fwrite(data, sizeof(uint32_t), COUNT, file) != COUNT) { fclose(file); return 0; }
    return fclose(file) == 0;
}

static int save_status(const char *folder, const char *name, unsigned cycle,
                      ULONGLONG elapsed, int passed, unsigned cpu, uint32_t actual) {
    char path[1024]; FILE *file;
    snprintf(path, sizeof(path), "%s/%s", folder, name);
    file = fopen(path, "w");
    if (!file) return 0;
    fprintf(file, "{\"cycles\":%u,\"elapsed_ms\":%llu,\"all_passed\":%s,"
                  "\"last_processor_index\":%u,\"actual_fnv1a32_hex\":\"%08x\","
                  "\"process_id\":%lu,\"simulation_starts\":0}\n",
            cycle, (unsigned long long)elapsed, passed ? "true" : "false", cpu,
            (unsigned)actual, (unsigned long)GetCurrentProcessId());
    return fclose(file) == 0;
}

int main(int argc, char **argv) {
    uint32_t *data, expected, digest = 0, endian = 1;
    unsigned cycle = 0, j, k, cpu = 0; size_t b;
    ULONGLONG start, now, last_progress; DWORD_PTR mask = 0, system_mask = 0;
    if (argc != 3 || *(unsigned char *)&endian != 1) return 2;
    expected = (uint32_t)strtoul(argv[2], NULL, 16);
    data = (uint32_t *)malloc(COUNT * sizeof(uint32_t));
    if (!data) return 3;
    if (!GetProcessAffinityMask(GetCurrentProcess(), &mask, &system_mask)) { free(data); return 12; }
    printf("OBSERVED_AFFINITY=%llu\n", (unsigned long long)mask); fflush(stdout);
    start = last_progress = GetTickCount64();
    do {
        for (j = 0; j < COUNT; ++j) data[j] = j;
        for (k = 0; k < STEPS; ++k)
            for (j = 0; j < COUNT; ++j) data[j] = 1664525u * data[j] + 1013904223u;
        digest = 2166136261u;
        for (b = 0; b < COUNT * sizeof(uint32_t); ++b)
            digest = (digest ^ ((unsigned char *)data)[b]) * 16777619u;
        ++cycle; cpu = GetCurrentProcessorNumber(); now = GetTickCount64();
        if (cpu < 64) ++processor_histogram[cpu];
        if (digest != expected) {
            save_vector(argv[1], data);
            save_status(argv[1], "native_result.json", cycle, now - start, 0, cpu, digest);
            free(data); return 10;
        }
        if (now - last_progress >= 5000) {
            if (!save_status(argv[1], "native_progress.json", cycle, now - start, 1, cpu, digest)) { free(data); return 4; }
            last_progress = now;
        }
    } while ((now - start < 60000 || cycle < 4) && cycle < 100000);
    if (!save_vector(argv[1], data)) { free(data); return 4; }
    {
        char path[1024]; FILE *file;
        snprintf(path, sizeof(path), "%s/native_processor_histogram.json", argv[1]);
        file = fopen(path, "w");
        if (!file) { free(data); return 4; }
        fprintf(file, "[");
        for (j = 0; j < 64; ++j) fprintf(file, "%s%llu", j ? "," : "", processor_histogram[j]);
        fprintf(file, "]\n"); fclose(file);
    }
    free(data);
    if (!save_status(argv[1], "native_result.json", cycle, now - start,
                     now - start >= 60000 && cycle >= 4, cpu, digest)) return 4;
    return now - start >= 60000 && cycle >= 4 ? 0 : 11;
}
