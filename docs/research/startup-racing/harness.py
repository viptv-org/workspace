#!/usr/bin/env python3
"""Startup measurement harness: backend discovery, ranking, admission, torrent prebuffer, mpv first frame.

Environment:
  VIPTV_BASE       throwaway backend origin, e.g. http://127.0.0.1:41956
  VIPTV_ORIGIN     the backend's VIPTV_AUTH_ORIGIN value
  VIPTV_USER / VIPTV_PASSWORD   throwaway account created with `viptv-server create-admin`
  TORRENT_WORKER   the app's pinned torrent-runtime worker binary
  CACHE_ROOT       scratch directory on a real disk (the worker cache needs disk geometry)
  DEVICE_HEIGHT    ranking height cap (default 1080)
  FRAME_TIMEOUT    seconds to the first decoded frame (default 20)
  PREBUFFER_TIMEOUT seconds to a torrent media URL (default 30)
"""
import json, os, shutil, socket, subprocess, sys, tempfile, threading, time, urllib.error, urllib.request

BASE = os.environ.get('VIPTV_BASE', 'http://127.0.0.1:41956')
ORIGIN = os.environ.get('VIPTV_ORIGIN', 'https://127.0.0.1:41956')
WORKER = os.environ['TORRENT_WORKER']
CACHE_ROOT = os.environ.get('CACHE_ROOT', '/tmp/viptv-startup-racing')
DEVICE_HEIGHT = int(os.environ.get('DEVICE_HEIGHT', '1080'))
USER, PASSWORD = os.environ['VIPTV_USER'], os.environ['VIPTV_PASSWORD']
FRAME_TIMEOUT = float(os.environ.get('FRAME_TIMEOUT', '20'))
PREBUFFER_TIMEOUT = float(os.environ.get('PREBUFFER_TIMEOUT', '30'))
os.makedirs(CACHE_ROOT, exist_ok=True)


def call(path, body=None, token=None, method=None, timeout=30):
    request = urllib.request.Request(BASE + path, method=method or ('POST' if body is not None else 'GET'))
    request.add_header('Origin', ORIGIN)
    if token:
        request.add_header('Authorization', 'Bearer ' + token)
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        request.add_header('Content-Type', 'application/json')
    try:
        with urllib.request.urlopen(request, data=data, timeout=timeout) as response:
            raw = response.read()
            return response.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            return error.code, json.loads(raw)
        except Exception:
            return error.code, raw.decode(errors='replace')


class Backend:
    def __init__(self):
        status, body = call('/api/auth/device/login',
                            {'username': USER, 'password': PASSWORD, 'device_name': 'startup-race-harness'})
        assert status == 200, (status, body)
        self.token = body['access_token']
        status, body = call('/api/auth/profile', {'profile_id': '1'}, self.token)
        assert status == 200, (status, body)
        status, body = call('/api/torrent-runtime-protocol', token=self.token)
        assert status == 200, (status, body)

    def discover(self, title):
        body = {'type': title['type'], 'id': title['id']}
        if title.get('series_id'):
            body['series_id'] = title['series_id']
        for key in ('name', 'year', 'imdb_id', 'season', 'episode'):
            if title.get(key) is not None:
                body[key] = title[key]
        started = time.perf_counter()
        status, job = call('/api/streams', body, self.token)
        if status != 200:
            return [], None, [], f'discovery {status}: {job}'
        after = 0
        rows = []
        arrivals = []
        while True:
            status, page = call(f"/api/streams/{job['id']}?after={after}&wait_ms=3000", token=self.token)
            if status != 200:
                return rows, time.perf_counter() - started, arrivals, f'poll {status}: {page}'
            events = page.get('events', [])
            for event in events:
                streams = event.get('streams') or []
                arrivals.append((event.get('source'), len(streams), time.perf_counter() - started, event.get('error_code')))
                rows.extend(streams)
            after += len(events)
            if page.get('done'):
                break
        return rows, time.perf_counter() - started, arrivals, None

    def rank(self, ids):
        status, body = call('/api/profiles/1/source-ranking', {'ids': ids, 'device_max_height': DEVICE_HEIGHT}, self.token)
        if status != 200:
            raise RuntimeError(f'ranking {status}: {body}')
        return body['streams']

    def open_playback(self, stream_id):
        client = {'platform': 'desktop', 'can_play_direct': True, 'supports_required_audio_index': True,
                  'max_width': 1920, 'max_height': DEVICE_HEIGHT, 'video_codecs': ['h264', 'hevc'],
                  'audio_codecs': ['aac'],
                  'native_torrent': {'version': 2, 'network_policy': 'public_discovery_verified_v2'}}
        started = time.perf_counter()
        status, body = call('/api/playback', {'request_id': f'req-{time.time_ns()}', 'stream_id': stream_id,
                                              'client': client, 'force_gateway': False, 'position': 0, 'resume': True},
                            self.token)
        if status not in (200, 202):
            return {'error': body, 'status': status, 'seconds': time.perf_counter() - started}
        deadline = time.perf_counter() + 25
        while body.get('status') != 'ready' and time.perf_counter() < deadline:
            time.sleep(0.05)
            status, body = call(f"/api/playback/{body['id']}", token=self.token)
            if status != 200:
                return {'error': body, 'status': status, 'seconds': time.perf_counter() - started}
        if body.get('status') != 'ready':
            return {'error': 'admission timeout', 'status': 202, 'seconds': time.perf_counter() - started}
        return {'status': 200, 'id': body['id'], 'delivery': body['delivery'], 'seconds': time.perf_counter() - started}

    def close_playback(self, playback_id):
        if playback_id:
            call(f'/api/playback/{playback_id}', method='DELETE', token=self.token)


class Worker:
    def __init__(self):
        self.cache = tempfile.mkdtemp(prefix='trial-', dir=CACHE_ROOT)
        self.process = subprocess.Popen([WORKER], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.DEVNULL, bufsize=0, text=True)
        self.lock = threading.Lock()
        self.ready = json.loads(self.process.stdout.readline())
        opened = self.call(op='open', config={'cache_dir': self.cache, 'cache_bytes': 1024 << 20})
        assert opened.get('ok'), opened

    def call(self, **command):
        command['version'] = 2
        with self.lock:
            try:
                self.process.stdin.write(json.dumps(command) + '\n')
                self.process.stdin.flush()
                line = self.process.stdout.readline()
            except Exception:
                return {}
        try:
            return json.loads(line or '{}')
        except Exception:
            return {}

    def prepare(self, source):
        return self.call(op='prepare', source=source, authority_ms=60000)

    def kill(self):
        try:
            self.process.kill()
            self.process.wait(timeout=3)
        except Exception:
            pass
        shutil.rmtree(self.cache, ignore_errors=True)


class Mpv:
    """Idle mpv with the desktop client's cache options; loadfile starts the measurement."""
    ARGS = ['--no-config', '--idle', '--no-terminal', '--vo=null', '--ao=null',
            '--hwdec=auto-safe', '--cache=yes', '--cache-pause-initial=no',
            '--demuxer-max-bytes=67108864', '--demuxer-max-back-bytes=16777216',
            '--demuxer-readahead-secs=10', '--network-timeout=30']

    def __init__(self):
        self.directory = tempfile.mkdtemp(prefix='mpv-', dir=CACHE_ROOT)
        self.socket_path = os.path.join(self.directory, 'ipc')
        self.process = subprocess.Popen(['mpv', *self.ARGS, f'--input-ipc-server={self.socket_path}'],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(500):
            if os.path.exists(self.socket_path):
                break
            time.sleep(0.01)
        self.socket = socket.socket(socket.AF_UNIX)
        self.socket.connect(self.socket_path)
        self.socket.settimeout(0.25)
        self.buffer = b''
        self.started = None

    def send(self, message):
        self.socket.sendall((json.dumps(message) + '\n').encode())

    def load(self, url, headers=None):
        self.started = time.perf_counter()
        if headers:
            fields = ','.join(f'{name}: {value}' for name, value in headers.items())
            self.send({'command': ['set_property', 'http-header-fields', fields]})
        self.send({'command': ['loadfile', url]})

    def wait_frame(self, timeout=FRAME_TIMEOUT, stop_event=None):
        marks = {}
        deadline = time.perf_counter() + timeout
        while time.perf_counter() < deadline:
            if stop_event is not None and stop_event.is_set():
                return None, marks, 'cancelled'
            try:
                chunk = self.socket.recv(65536)
            except socket.timeout:
                continue
            if not chunk:
                return None, marks, 'closed'
            self.buffer += chunk
            while b'\n' in self.buffer:
                line, self.buffer = self.buffer.split(b'\n', 1)
                try:
                    event = json.loads(line)
                except Exception:
                    continue
                name = event.get('event')
                if name in ('file-loaded', 'playback-restart', 'video-reconfig'):
                    marks.setdefault(name, time.perf_counter() - self.started)
                if name == 'end-file':
                    return None, marks, event.get('reason', 'end-file')
                if name == 'playback-restart':
                    return time.perf_counter() - self.started, marks, 'frame'
        return None, marks, 'timeout'

    def kill(self):
        try:
            self.send({'command': ['quit']})
        except Exception:
            pass
        try:
            self.process.wait(timeout=2)
        except Exception:
            self.process.kill()
        shutil.rmtree(self.directory, ignore_errors=True)


def default_interface():
    route = subprocess.run(['ip', 'route', 'get', '1.1.1.1'], capture_output=True, text=True).stdout.split()
    return route[route.index('dev') + 1] if 'dev' in route else 'eth0'


IFACE = default_interface()


def rx_bytes():
    with open('/proc/net/dev') as table:
        for line in table:
            if ':' not in line:
                continue
            name, rest = line.split(':', 1)
            if name.strip() == IFACE:
                return int(rest.split()[0])
    return 0


def socket_count(pids):
    """Peak simultaneous sockets on the client side, mostly short-lived peer connection attempts."""
    output = subprocess.run(['ss', '-H', '-tunp'], capture_output=True, text=True).stdout
    count = 0
    for line in output.splitlines():
        if any(f'pid={pid},' in line for pid in pids):
            count += 1
    return count


class Sampler:
    def __init__(self, pids):
        self.pids = pids
        self.peak = 0
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def run(self):
        while not self.stop.is_set():
            self.peak = max(self.peak, socket_count(self.pids))
            time.sleep(0.1)

    def finish(self):
        self.stop.set()
        self.thread.join(timeout=2)
        return self.peak


def torrent_source(delivery):
    grant = delivery['grant']
    source = {'magnet': grant['input']['uri']}
    if grant.get('file_index') is not None:
        source['file_index'] = grant['file_index']
    if grant.get('trackers'):
        source['trackers'] = grant['trackers']
    return source


def wait_media(worker, handle, timeout=None, cancel=None):
    started = time.perf_counter()
    timeout = timeout or PREBUFFER_TIMEOUT
    while time.perf_counter() - started < timeout:
        if cancel is not None and cancel.is_set():
            return None, time.perf_counter() - started, 'cancelled'
        reply = worker.call(op='observe', handle=handle)
        if reply.get('media_url'):
            return reply['media_url'], time.perf_counter() - started, None
        progress = reply.get('progress') or {}
        if progress.get('error'):
            return None, time.perf_counter() - started, progress['error']
        time.sleep(0.05)
    return None, time.perf_counter() - started, 'prebuffer timeout'


def play(url, headers, flow, stop_event=None):
    flow['url'] = url
    flow['media_ready'] = time.perf_counter()
    flow['prebuffer_bytes'] = rx_bytes() - flow['bytes_at_start']
    flow['mpv'].load(url, headers=headers)
    frame, marks, reason = flow['mpv'].wait_frame(timeout=FRAME_TIMEOUT, stop_event=stop_event)
    flow['marks'] = marks
    flow['frame'] = frame
    flow['reason'] = reason
    flow['ttff'] = (time.perf_counter() - flow['t0']) if frame is not None else None
    flow['bytes'] = rx_bytes() - flow['bytes_at_start']
    flow['media_bytes'] = flow['bytes'] - flow['prebuffer_bytes']
    flow['sockets'] = flow['sampler'].finish()
    return flow


def run_flow(backend, row, t0=None, stop_event=None, bytes_base=None, cancel=None):
    """Open one ranked row the way the client does: admission, grant, torrent prebuffer, player."""
    flow = {'row': row, 't0': t0 or time.perf_counter()}
    flow['bytes_at_start'] = bytes_base if bytes_base is not None else rx_bytes()
    flow['mpv'] = Mpv()
    admission = backend.open_playback(row['id'])
    flow['admission'] = admission
    if admission.get('status') != 200:
        flow['error'] = str(admission.get('error'))
        flow['sampler'] = Sampler([flow['mpv'].process.pid])
        return flow
    delivery = admission['delivery']
    flow['kind'] = delivery['kind']
    if delivery['kind'] == 'direct':
        flow['sampler'] = Sampler([flow['mpv'].process.pid])
        return play(delivery['url'], delivery.get('headers') or {}, flow, stop_event)
    if delivery['kind'] != 'native_torrent':
        flow['error'] = f"unsupported delivery {delivery['kind']}"
        flow['sampler'] = Sampler([flow['mpv'].process.pid])
        return flow
    worker = Worker()
    flow['worker'] = worker
    flow['sampler'] = Sampler([flow['mpv'].process.pid, worker.process.pid])
    prepared = worker.prepare(torrent_source(delivery))
    if not prepared.get('handle'):
        flow['error'] = str(prepared)
        return flow
    flow['handle'] = prepared['handle']
    url, seconds, error = wait_media(worker, prepared['handle'], cancel=cancel)
    flow['prebuffer'] = seconds
    if not url:
        flow['error'] = error
        flow['sockets'] = flow['sampler'].finish()
        flow['bytes'] = rx_bytes() - flow['bytes_at_start']
        return flow
    return play(url, {}, flow, stop_event)


def run_http_flow(row, url, t0=None, stop_event=None, bytes_base=None):
    """A direct/HTTP row played from the add-on URL; a gateway-less throwaway backend cannot hand one out."""
    flow = {'row': row, 't0': t0 or time.perf_counter(), 'kind': 'direct', 'admission': {'seconds': 0.0}}
    flow['bytes_at_start'] = bytes_base if bytes_base is not None else rx_bytes()
    flow['mpv'] = Mpv()
    flow['sampler'] = Sampler([flow['mpv'].process.pid])
    return play(url, {}, flow, stop_event)


def close_flow(backend, flow):
    if flow.get('mpv'):
        flow['mpv'].kill()
    if flow.get('worker'):
        flow['worker'].kill()
    if flow.get('admission', {}).get('id'):
        backend.close_playback(flow['admission']['id'])