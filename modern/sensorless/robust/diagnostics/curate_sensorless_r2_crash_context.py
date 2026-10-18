"""Publish whitelisted crash symbols only; private dumps can contain session secrets."""
from pathlib import Path
from datetime import datetime
from collections import Counter
import hashlib
import json
import os
import re

BASE = Path(__file__).resolve().parents[2]
DEST = BASE / 'milestones/N3R2/crash_context_20261018'


def read(path):
    return json.loads(path.read_text('utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def frames(path):
    result = []
    for line in path.read_text('utf-8', errors='replace').splitlines():
        if not re.match(r'\s*\[\s*\d+\]', line):
            continue
        module = re.search(r'([A-Za-z0-9_.-]+\.(?:dll|mexw64|exe))', line, re.I)
        symbol = re.search(r'(?:\s|\))([A-Za-z_~][A-Za-z0-9_:~<>]*)(?:\+\d+)?\s*$', line)
        if module:
            result.append({'module': module.group(1), 'symbol': symbol.group(1)[:180] if symbol else None})
        if len(result) == 8:
            break
    return result


def main():
    inventory = read(BASE / 'milestones/N3R2/development_20261017/native_execution_inventory.json')
    rows = []
    for item in inventory['rows']:
        record_file = BASE / 'runs' / item['campaign'] / item['attempt'] / 'record.json'
        if not record_file.exists():
            continue
        record = read(record_file)
        pid = record.get('process_id')
        if not pid:
            continue
        dump = Path(os.environ['TEMP']) / f'matlab_crash_dump.{pid}-1'
        row = {'campaign': item['campaign'], 'case_id': item['case_id'], 'pid': pid,
               'exit_code_hex': item['exit_code_hex'], 'last_durable_phase': item['last_persisted_phase'],
               'record_sha256': sha(record_file), 'dump_present': dump.exists()}
        if dump.exists():
            delta = dump.stat().st_mtime - record_file.stat().st_mtime
            row['dump_minus_last_record_s'] = delta
            row['pid_and_timestamp_proximity_match'] = -60 <= delta <= 7200
            if row['pid_and_timestamp_proximity_match']:
                row.update({'private_dump_sha256': sha(dump), 'private_dump_bytes': dump.stat().st_size,
                            'redacted_top_frames': frames(dump)})
        rows.append(row)
    modules = Counter(row['redacted_top_frames'][0]['module'] for row in rows if row.get('redacted_top_frames'))
    result = {'analysis_only': True, 'captured_at': datetime.now().astimezone().isoformat(),
              'generator_sha256': sha(Path(__file__)), 'input_inventory_sha256': sha(BASE / 'milestones/N3R2/development_20261017/native_execution_inventory.json'),
              'rows': rows, 'first_frame_modules': dict(modules),
              'private_dump_matches_with_frames': sum(bool(row.get('redacted_top_frames')) for row in rows),
              'scope': 'PID and timestamp proximity association of existing failures. No code/model run or original record modification. Whitelisted module basenames/C++ identifiers only; no raw dump text, addresses, license/session data, registers or console published. Exported symbols may be nearest names and cannot establish the exact failing source function.',
              'native_root_cause_confirmed': False, 'hardware_failure_confirmed': False,
              'R2_passed': False, 'formal_or_failed_short_restarted': False}
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / 'summary.json').write_bytes((json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
    print(json.dumps({'records': len(rows), 'dumps_with_frames': result['private_dump_matches_with_frames'],
                      'first_frame_modules': dict(modules), 'root_cause_confirmed': False}))


if __name__ == '__main__':
    main()
