"""Summarize finalized execution failures without exposing raw crash logs."""
from pathlib import Path
from datetime import datetime
import hashlib
import json
import re

BASE = Path(__file__).resolve().parents[2]
DEST = BASE / 'milestones/N3R2/development_20261017/native_execution_inventory.json'
RETRYABLE = {0xC0000005, 0xC000001D}
KNOWN_NATIVE = RETRYABLE | {0xC0000096, 0xC0000409, 0x80000003}


def read(path):
    return json.loads(path.read_text('utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def safe_frames(path):
    """Extract only module basenames and bounded C++ identifiers, never raw lines."""
    if not path.exists():
        return []
    frames = []
    for line in path.read_text('utf-8', errors='replace').splitlines():
        if not re.search(r'\[\s*\d+\].*(?:\.dll|\.mexw64|\.exe)', line):
            continue
        module = re.search(r'([A-Za-z0-9_.-]+\.(?:dll|mexw64|exe))', line)
        symbol = re.search(r'(?:\s|\))([A-Za-z_~][A-Za-z0-9_:~<>]*)(?:\+\d+)?\s*$', line)
        item = {'module': module.group(1) if module else None,
                'symbol': symbol.group(1)[:240] if symbol else None}
        if item not in frames:
            frames.append(item)
        if len(frames) == 8:
            break
    return frames


def main():
    rows = []
    for path in sorted((BASE / 'runs').glob('N3R2_*/campaign.json')):
        campaign = read(path)
        for job in campaign.get('jobs', []):
            for attempt in job.get('attempts', []):
                code = attempt.get('exit_code')
                if code in (None, 0):
                    continue
                folder = Path(attempt['folder'])
                record = read(folder / 'record.json') if (folder / 'record.json').exists() else {}
                progress = read(folder / 'execution_progress.json') if (folder / 'execution_progress.json').exists() else {}
                launcher = Path(attempt.get('launcher_log', path.parent / '__absent__'))
                unsigned = code & 0xffffffff
                rows.append({
                    'campaign': path.parent.name, 'version': campaign.get('execution_version'),
                    'case_id': job['case_id'], 'attempt': folder.name,
                    'exit_code': code, 'exit_code_hex': f'0x{unsigned:08x}',
                    'recognized_windows_native_exception': unsigned in KNOWN_NATIVE,
                    'retryable_native_code': unsigned in RETRYABLE,
                    'driver_retryable_classification': attempt.get('native_failure'),
                    'last_persisted_phase': record.get('phase'),
                    'last_recorded_next_major_time_s': progress.get('next_major_time_s'),
                    'completed_physics_archived': bool(record.get('raw_sha256')),
                    'original_record_sha256': sha(folder / 'record.json') if record else None,
                    'private_launcher_sha256': sha(launcher) if launcher.exists() else None,
                    'redacted_frames': safe_frames(launcher),
                })
    result = {
        'analysis_only': True, 'captured_at': datetime.now().astimezone().isoformat(),
        'generator_sha256': sha(Path(__file__)),
        'native_root_cause_confirmed': False, 'algorithm_verdict_from_native_exit': False,
        'scope': 'Finalized nonzero attempts only. Driver native_failure is retry eligibility, not a statement that other Windows exceptions are non-native. Progress is last durable observation, not exact crash time. Stack symbols may be nearest exported names and do not establish a cause. No raw console, addresses, tokens, licenses or crash dumps are published.',
        'rows': rows,
    }
    DEST.parent.mkdir(parents=True, exist_ok=True)
    DEST.write_bytes((json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
    print(json.dumps({'finalized_nonzero_attempts': len(rows), 'root_cause_confirmed': False}))


if __name__ == '__main__':
    main()
