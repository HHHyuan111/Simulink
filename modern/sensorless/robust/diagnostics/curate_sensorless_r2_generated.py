"""Retain the generated short's actual outcome without repairing its record."""
from pathlib import Path
from datetime import datetime
import hashlib
import json
import shutil

BASE = Path(__file__).resolve().parents[2]


def read(path):
    return json.loads(path.read_text('utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    root = BASE / 'runs/N3R2_generated_backend_short_once'
    manifest = read(root / 'campaign.json')
    assert manifest['status'] != 'running'
    attempt = manifest['jobs'][0]['attempts'][0]
    folder = Path(attempt['folder'])
    record = read(folder / 'record.json')
    for entry in record['source_files']:
        assert sha(folder / 'source' / entry['path']) == entry['sha256']
    for entry in record['contracts']:
        assert sha(folder / entry['path']) == entry['sha256']
    for file, field in [('process_probe_prerequisite.json', 'process_probe_sha256'),
                         ('compiler_dependency.json', 'dependency_sha256')]:
        assert sha(folder / file) == record['backend_prerequisites'][field]
    parent = folder / 'parent/PMSM_FOC_R2026a.slx'
    assert sha(parent) == record['model_sha256'] == sha(BASE.parent / parent.name)
    dest = BASE / 'milestones/N3R2/generated_short_20261018'
    dest.mkdir(parents=True, exist_ok=True)
    for file in ('record.json', 'process_probe_prerequisite.json', 'compiler_dependency.json'):
        shutil.copyfile(folder / file, dest / file)
    shutil.copyfile(root / 'campaign.json', dest / 'campaign.json')
    result = {'captured_at': datetime.now().astimezone().isoformat(), 'analysis_only': True,
              'simulation_reexecuted': False, 'source_archive_integrity_passed': True,
              'all_passed': False, 'campaign_status': manifest['status'],
              'exit_code': attempt['exit_code'], 'exit_code_hex': f"0x{attempt['exit_code'] & 0xffffffff:08x}",
              'last_durable_phase': record['phase'], 'record_last_persisted_status': record['status'],
              'raw_physics_archived': bool(record.get('raw_sha256')), 'physical_step_phase_reached': False,
              'copied_parent_bytes_equal_original': True, 'record_unmodified': True,
              'record_sha256': sha(folder / 'record.json'), 'campaign_sha256': sha(root / 'campaign.json'),
              'formal_matrix_restarted': False, 'R2_passed': False, 'root_cause_confirmed': False,
              'algorithm_verdict_from_native_exit': False}
    (dest / 'summary.json').write_bytes((json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
