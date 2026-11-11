# Isolated decoder/VAD baseline

This Linux research harness measures audio decode, downmix, resample, pipe and native WebRTC VAD costs. It does not implement subtitle alignment or tap an existing player. [Measured results](machine-baseline.json) use the exact image/probe/fixture hashes recorded there. [Feasibility report](../subtitle-sync.md) explains the limits.

Run only in an approved shared-host benchmark window. Use an owned scratch directory visible to the Docker host. Do not mount production media or run inside a managed gateway container. The image must already be local; the script never pulls one. The probe download is pinned to py-webrtcvad source revision `e283ca41df3a84b0e87fb1f5cb9b21580a286b09`. Its native WebRTC code is BSD licensed and the downloaded LICENSE contains the terms. No third-party source or binary is vendored here.

```bash
flock /tmp/viptv-tv-validation.lock python3 build_probe.py --directory /path/to/owned-scratch
flock /tmp/viptv-tv-validation.lock python3 machine_baseline.py --directory /path/to/owned-scratch --image sha256:LOCAL_IMAGE_ID
```

Use a separate scratch directory per run. If Docker is run through sudo, `--uid` must identify the user with write access to that directory. The probe is statically linked with one compiler invocation at a time; it requires a Linux C/C++ toolchain and static runtime libraries. The runtime image needs `/bin/sh`, `/opt/ffmpeg/bin/ffmpeg`, a FIFO-capable tmpfs and cgroup-v2 CPU/memory files.

The benchmark creates an owned 20 s synthetic AAC fixture, samples three seconds of shell idle, then runs three batch decodes and one input-paced decode. Each container has a 35 s client timeout, cleanup in `finally`, one CPU, 256 MiB memory with swap disabled, 64 PIDs, 32 MiB tmpfs, no capabilities/network and a read-only root. Only fixture generation mounts the owned directory writable. A PCM FIFO and decoder log live in that container's tmpfs. Raw results are written to the owned scratch directory.

Batch CPU per media second is a throughput figure. The paced run is a short observation, not a sustained mobile or playback qualification. FFmpeg and VAD report separate peak RSS; the sum is not simultaneous aggregate PSS. Cgroup memory can exclude shared pages charged elsewhere. Fixture transfer uses a local mount and PCM pipe, with zero external network access. Docker start/stop wall time is not playback startup.

The recorded run used the same workload before reusable argument validation and timeout cleanup were added. CLI/syntax checks cover the published orchestration; no additional shared-host load run was performed after those changes.
