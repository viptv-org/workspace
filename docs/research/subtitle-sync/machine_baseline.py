from pathlib import Path
import argparse
import json
import os
import re
import subprocess
import time
import uuid

parser = argparse.ArgumentParser(description='Run short, isolated decoder/VAD baselines. Obtain a shared-host benchmark window first.')
parser.add_argument('--image', required=True)
parser.add_argument('--directory', type=Path, required=True)
parser.add_argument('--uid', type=int, default=os.getuid())
parser.add_argument('--constraints-only', action='store_true')
args = parser.parse_args()
if not re.fullmatch(r'sha256:[0-9a-f]{64}', args.image):
    parser.error('--image must be an already-local immutable image ID')
IMAGE = args.image
ROOT = args.directory.resolve()
if not (ROOT / 'vad-probe').is_file():
    parser.error('--directory must contain the built vad-probe and be writable by --uid')
if args.constraints_only and not (ROOT / 'owned-synthetic.m4a').is_file():
    parser.error('--constraints-only requires the fixture from a previous baseline')
docker = ['docker'] if os.geteuid() == 0 else ['sudo', '-n', 'docker']
subprocess.run(docker + ['image', 'inspect', IMAGE], check=True, capture_output=True, timeout=10)
BASE = docker + ['run', '--rm', '--pull', 'never', '--network', 'none', '--read-only',
        '--pids-limit=64',
        '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges', '--user', str(args.uid) + ':' + str(args.uid),
        '--tmpfs', '/tmp:rw,noexec,nosuid,size=32m', '--entrypoint', '/bin/sh']

def run(label, script, writable=False, timeout=35, cpu='1', memory='256m'):
    name = 'viptv-subtitle-research-' + uuid.uuid4().hex
    cmd = BASE + ['--cpus=' + cpu, '--memory=' + memory, '--memory-swap=' + memory, '--name', name, '--mount', 'type=bind,src=' + str(ROOT) + ',dst=/work' + ('' if writable else ',readonly'), IMAGE, '-c', script]
    start = time.monotonic()
    try:
        result = subprocess.run(cmd, text=True, capture_output=True, timeout=timeout)
        row = dict(label=label, exit_code=result.returncode, outer_wall_seconds=time.monotonic()-start,
                   stdout=result.stdout, stderr=result.stderr, timed_out=False)
    except subprocess.TimeoutExpired as error:
        row = dict(label=label, exit_code=None, outer_wall_seconds=time.monotonic()-start,
                   stdout=error.stdout.decode(errors='replace') if isinstance(error.stdout, bytes) else error.stdout,
                   stderr=error.stderr.decode(errors='replace') if isinstance(error.stderr, bytes) else error.stderr,
                   timed_out=True)
    finally:
        subprocess.run(docker + ['rm', '-f', name], capture_output=True, timeout=10)
    row.update(cpu_cap=cpu, memory_cap=memory)
    return row

rows = []
if args.constraints_only:
    workloads = [('paced-quarter', '-readrate 1', '0.25', '128m'), ('paced-tenth', '-readrate 1', '0.10', '64m')]
else:
    rows.append(run('fixture-generation', '/opt/ffmpeg/bin/ffmpeg -nostdin -hide_banner -loglevel error -threads 1 -filter_threads 1 -f lavfi -i "aevalsrc=0.08*sin(2*PI*440*t)*lt(mod(t\\,4)\\,2):s=48000:d=20" -t 20 -ac 2 -c:a aac -b:a 96k -threads 1 -y /work/owned-synthetic.m4a', writable=True))
    if rows[-1]['exit_code'] != 0:
        raise RuntimeError(json.dumps(rows[-1]))
    rows.append(run('idle-3s', 'cat /sys/fs/cgroup/cpu.stat; sleep 3; cat /sys/fs/cgroup/cpu.stat; cat /sys/fs/cgroup/memory.peak'))
    workloads = [(label, rate, '1', '256m') for label, rate in [('batch-1',''), ('batch-2',''), ('batch-3',''), ('paced-20s','-readrate 1')]]
for label, rate, cpu, memory in workloads:
    script = '''
echo CPU_BEFORE
cat /sys/fs/cgroup/cpu.stat
echo MEMORY_EVENTS_BEFORE
cat /sys/fs/cgroup/memory.events
mkfifo /tmp/pcm
/opt/ffmpeg/bin/ffmpeg -nostdin -hide_banner -loglevel info -benchmark -threads 1 -filter_threads 1 RATE -i /work/owned-synthetic.m4a -map 0:a:0 -vn -sn -dn -t 20 -ac 1 -ar 16000 -c:a pcm_s16le -threads 1 -f s16le pipe:1 >/tmp/pcm 2>/tmp/decoder.log &
decoder=$!
/work/vad-probe </tmp/pcm
vad_status=$?
wait "$decoder"
decoder_status=$?
cat /tmp/decoder.log
echo CPU_AFTER
cat /sys/fs/cgroup/cpu.stat
echo MEMORY_EVENTS_AFTER
cat /sys/fs/cgroup/memory.events
echo MEMORY_PEAK
cat /sys/fs/cgroup/memory.peak
echo "STATUS vad=$vad_status decoder=$decoder_status"
test "$vad_status" -eq 0 && test "$decoder_status" -eq 0
'''.replace('RATE', rate)
    rows.append(run(label, script, cpu=cpu, memory=memory))
output = dict(image=IMAGE, fixture='owned generated 20s gated 440Hz tone/silence, AAC stereo 48kHz 96kbit/s',
              vad='WebRTC source e283ca41df3a84b0e87fb1f5cb9b21580a286b09, native mode 2, 16kHz mono s16 20ms',
              scope='decoder/downmix/resample/pipe/native VAD only; no estimator, bindings, player, HTTP/torrent/HLS, or accuracy test',
              network='Docker network none; only owned bind-mounted fixture; no upstream readers', rows=rows)
(ROOT/('constraint-baseline-raw.json' if args.constraints_only else 'machine-baseline-raw.json')).write_text(json.dumps(output,indent=2)+'\n')
print(json.dumps(output))
