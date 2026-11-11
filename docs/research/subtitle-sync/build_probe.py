from pathlib import Path
import argparse
import io
import subprocess
import tarfile
import urllib.request

parser = argparse.ArgumentParser(description='Build a Linux-only native WebRTC VAD research probe in an owned scratch directory.')
parser.add_argument('--directory', type=Path, required=True)
args = parser.parse_args()
root = args.directory.resolve()
root.mkdir(parents=True, exist_ok=True)
revision = 'e283ca41df3a84b0e87fb1f5cb9b21580a286b09'
archive = urllib.request.urlopen('https://codeload.github.com/wiseman/py-webrtcvad/tar.gz/' + revision, timeout=20).read()
with tarfile.open(fileobj=io.BytesIO(archive), mode='r:gz') as tar:
    for entry in tar.getmembers():
        parts = Path(entry.name).parts
        if len(parts) < 2 or '..' in parts or not entry.isfile():
            continue
        if parts[1] == 'LICENSE' or parts[1:3] == ('cbits', 'webrtc'):
            target = root.joinpath(*parts[1:])
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(tar.extractfile(entry).read())
(root / 'vad_probe.c').write_bytes((Path(__file__).parent / 'vad_probe.c').read_bytes())
sources = sorted((root / 'cbits/webrtc/common_audio').rglob('*.c')) + [root / 'vad_probe.c']
objects = []
for index, source in enumerate(sources):
    target = root / ('probe-%d.o' % index)
    subprocess.run(['cc', '-O2', '-DNDEBUG', '-DWEBRTC_POSIX', '-I' + str(root / 'cbits'), '-c', str(source), '-o', str(target)], check=True)
    objects.append(str(target))
target = root / 'checks.o'
subprocess.run(['g++', '-O2', '-DNDEBUG', '-DWEBRTC_POSIX', '-I' + str(root / 'cbits'), '-c', str(root / 'cbits/webrtc/rtc_base/checks.cc'), '-o', str(target)], check=True)
subprocess.run(['g++', '-static', '-o', str(root / 'vad-probe'), *objects, str(target), '-lm', '-pthread'], check=True)
