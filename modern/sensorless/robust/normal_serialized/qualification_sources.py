"""Bind the Normal qualification before its first model build; no simulation."""
import hashlib
import json
from pathlib import Path
import sys
from datetime import datetime, timezone

BASE = Path(__file__).resolve().parents[2]
REPO = BASE.parent.parent
MANIFEST = BASE / 'milestones/N3R2/normal_serialized_20261018/prequalification_sources.json'


def read(p):
    return json.loads(p.read_text('utf-8-sig'))


def sha(p):
    with p.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verify():
    record = read(MANIFEST)
    assert record['execution_version'] == 'normal_serialized_parent_and_observer'
    for entry in record['files']:
        assert sha(REPO / entry['path']) == entry['sha256'], entry['path']
    print(json.dumps({'verified': True, 'files': len(record['files']), 'manifest_sha256': sha(MANIFEST)}))


def freeze():
    assert not MANIFEST.exists(), 'Never overwrite a registered qualification source map.'
    old = read(BASE / 'milestones/N3R2/final_candidate.json')
    files = {entry['path']: entry['sha256'] for entry in old['files']}
    for path, digest in files.items():
        assert sha(REPO / path) == digest
    paths = list((BASE / 'contracts').glob('*.json'))
    for directory in ('portable_model', 'generated_backend', 'portable_execution', 'normal_serialized'):
        paths.extend((BASE / 'robust' / directory).glob('*.m'))
    paths.extend([Path(__file__), BASE / 'robust/normal_serialized/derivation.json',
                  BASE / 'robust/diagnostics/derive_sensorless_r2_normal_serialized.py',
                  BASE / 'robust/diagnostics/run_sensorless_r2_normal_serialized_short.ps1'])
    for p in paths:
        files[p.relative_to(REPO).as_posix()] = sha(p)
    record = {'schema': 1, 'execution_version': 'normal_serialized_parent_and_observer',
              'registered_at': datetime.now(timezone.utc).isoformat(), 'old820_preserved': True,
              'two_short_artifact_source_binding_only': True, 'R2_passed': False,
              'files': [{'path': path, 'sha256': digest} for path, digest in sorted(files.items())]}
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    with MANIFEST.open('x', encoding='utf8', newline='\n') as stream:
        json.dump(record, stream, indent=2)
        stream.write('\n')
    verify()


if __name__ == '__main__':
    assert len(sys.argv) == 2 and sys.argv[1] in ('freeze', 'verify')
    {'freeze': freeze, 'verify': verify}[sys.argv[1]]()
