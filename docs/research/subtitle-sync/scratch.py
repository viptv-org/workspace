from pathlib import Path
import hashlib
import json
import os
import stat

REVISION = 'e283ca41df3a84b0e87fb1f5cb9b21580a286b09'
MARKER = '.viptv-subtitle-probe.json'


def owned_directory(path, owner_uid):
    if any(character in str(path) for character in ',\n\r'):
        raise ValueError('--directory must not contain commas or newlines')
    if path.is_symlink():
        raise ValueError('--directory must not be a symlink')
    root = path.resolve(strict=True)
    if any(character in str(root) for character in ',\n\r'):
        raise ValueError('--directory must not resolve to a comma or newline path')
    info = root.stat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != owner_uid or info.st_mode & 0o022:
        raise ValueError('--directory must be owned by the selected uid and not writable by other users')
    return root


def claim_empty_directory(path, owner_uid):
    root = owned_directory(path, owner_uid)
    if any(root.iterdir()):
        raise ValueError('probe build requires an empty owned scratch directory')
    marker = dict(kind='viptv-subtitle-probe', schema=1, owner_uid=owner_uid,
                  source_revision=REVISION, build_complete=False)
    descriptor = os.open(root / MARKER, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as output:
        json.dump(marker, output)
    return root, marker


def validate_probe_directory(path, owner_uid):
    root = owned_directory(path, owner_uid)
    marker_path = root / MARKER
    if marker_path.is_symlink() or not marker_path.is_file():
        raise ValueError('--directory requires a probe-build ownership marker')
    marker_info = marker_path.stat()
    if marker_info.st_uid != owner_uid or marker_info.st_mode & 0o022 or marker_info.st_size > 4096:
        raise ValueError('--directory has an unowned or writable ownership marker')
    marker = json.loads(marker_path.read_text())
    if not isinstance(marker, dict) or marker.get('build_complete') is not True or any(marker.get(key) != value for key, value in {
        'kind': 'viptv-subtitle-probe', 'schema': 1, 'owner_uid': owner_uid,
        'source_revision': REVISION,
    }.items()):
        raise ValueError('--directory has an invalid or incomplete ownership marker')
    probe = root / 'vad-probe'
    if probe.is_symlink() or not probe.is_file() or probe.stat().st_uid != owner_uid:
        raise ValueError('--directory must contain its owned, regular vad-probe')
    if hashlib.sha256(probe.read_bytes()).hexdigest() != marker.get('probe_sha256'):
        raise ValueError('vad-probe does not match its ownership marker')
    return root
