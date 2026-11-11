#include <stdint.h>
#include <stdio.h>
#include <sys/resource.h>
#include <time.h>
#include "webrtc/common_audio/vad/include/webrtc_vad.h"

int main(void) {
    VadInst *vad = WebRtcVad_Create();
    if (!vad || WebRtcVad_Init(vad) || WebRtcVad_set_mode(vad, 2)) return 2;
    int16_t pcm[320];
    unsigned long frames = 0, speech = 0;
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    size_t count;
    while ((count = fread(pcm, sizeof(int16_t), 320, stdin)) != 0) {
        if (count != 320) return 3;
        int value = WebRtcVad_Process(vad, 16000, pcm, 320);
        if (value < 0) return 4;
        frames++; speech += value;
    }
    if (ferror(stdin)) return 5;
    clock_gettime(CLOCK_MONOTONIC, &end);
    struct rusage usage;
    getrusage(RUSAGE_SELF, &usage);
    double elapsed = end.tv_sec - start.tv_sec + (end.tv_nsec - start.tv_nsec) / 1e9;
    printf("{\"frames\":%lu,\"speech_frames\":%lu,\"media_seconds\":%.3f,\"wall_seconds\":%.6f,\"user_seconds\":%.6f,\"system_seconds\":%.6f,\"maxrss_kib\":%ld}\n",
        frames, speech, frames * .02, elapsed,
        usage.ru_utime.tv_sec + usage.ru_utime.tv_usec / 1e6,
        usage.ru_stime.tv_sec + usage.ru_stime.tv_usec / 1e6, usage.ru_maxrss);
    WebRtcVad_Free(vad);
    return 0;
}
