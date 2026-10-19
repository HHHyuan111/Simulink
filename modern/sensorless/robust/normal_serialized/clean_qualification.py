"""Freeze/verify prospective clean-runtime qualification, never simulate."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sys

BASE = Path(__file__).resolve().parents[2]
REPO = BASE.parent.parent
DEST = BASE / 'milestones/N3R2/clean_qualification_20261019/qualification_sources.json'
CONTROL = BASE / 'runs/N3R2_clean_install_activated_control_once'


def read(p):
    return json.loads(p.read_text('utf-8-sig'))


def sha(p):
    with p.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verify():
    manifest = read(DEST)
    for field in ('files', 'prerequisite_files', 'environment_files', 'artifacts'):
        for entry in manifest[field]:
            p = Path(entry['path']) if field == 'environment_files' else REPO / entry['path']
            assert sha(p) == entry['sha256'], entry['path']
    print(json.dumps({'verified': True, 'files': len(manifest['files']), 'manifest_sha256': sha(DEST)}))


def freeze():
    assert not DEST.exists(), 'Never overwrite a qualification freeze.'
    assert not (BASE / 'runs/N3R2_clean_normal_qualification_once').exists()
    assert read(CONTROL / 'campaign.json')['status'] == 'diagnostic_passed_not_R2_qualified'
    assert read(CONTROL / 'runtime_preflight/report.json')['all_passed']
    record = read(CONTROL / 'short_once/record.json')
    assert record['status'] == 'passed' and record['native_endpoint_verified'] and record['reference_restored']
    assert read(CONTROL / 'short_once/log_format/v7_complete_log_comparison.json')['all_passed']
    assert read(CONTROL / 'short_once/log_format/logging_validation.json')['original52_included']
    original = BASE / 'milestones/N3R2/normal_serialized_20261018/prequalification_sources.json'
    assert sha(original) == '2ea53bab650cc4ffc8cfb20a82d23ea22a50172af78f2ea8d904a1a36da8999b'
    files = {e['path']: e['sha256'] for e in read(original)['files']}
    for relative, digest in files.items():
        assert sha(REPO / relative) == digest
    extras = list((BASE / 'contracts').glob('*.json'))
    extras.extend([Path(__file__), BASE / 'robust/diagnostics/run_sensorless_r2_clean_normal_qualification.ps1'])
    for p in extras:
        files[p.relative_to(REPO).as_posix()] = sha(p)
    prerequisites = [CONTROL / 'campaign.json', CONTROL / 'runtime_preflight/report.json',
        CONTROL / 'short_once/report.json', CONTROL / 'short_once/record.json',
        CONTROL / 'short_once/log_format/v7_complete_log_comparison.json',
        CONTROL / 'short_once/log_format/logging_validation.json']
    binaries = read(CONTROL / 'binary_comparison.json')
    root = BASE / '.build/matlab_clean/R2026a_U5'
    environment = [root / 'VersionInfo.xml', root / 'bin/matlab.exe']
    for binary in binaries:
        p = root / 'bin/win64' / binary['name']
        assert binary['fresh_signature'] == 'Valid' and sha(p) == binary['fresh_sha256']
        environment.append(p)
    protocol = read(BASE / 'contracts/nonideal_r2_clean_install_control.json')
    a = protocol['artifacts']
    artifacts = [Path(a['parent_file']), Path(a['child_file']), Path(a['build_folder']) / 'handoff.mat']
    def entries(paths):
        return [{'path': p.relative_to(REPO).as_posix(), 'sha256': sha(p)} for p in paths]
    manifest = {'schema': 1, 'registered_at': datetime.now(timezone.utc).isoformat(),
                'purpose': 'Two prospective qualification shorts; earlier diagnostic excluded',
                'R2_passed': False, 'files': [{'path': k, 'sha256': v} for k, v in sorted(files.items())],
                'prerequisite_files': entries(prerequisites), 'artifacts': entries(artifacts),
                'environment_files': [{'path': str(p.resolve()), 'sha256': sha(p)} for p in environment]}
    DEST.parent.mkdir(parents=True, exist_ok=True)
    with DEST.open('x', encoding='utf8', newline='\n') as stream:
        json.dump(manifest, stream, indent=2)
        stream.write('\n')
    verify()


if __name__ == '__main__':
    assert len(sys.argv) == 2 and sys.argv[1] in ('freeze', 'verify')
    {'freeze': freeze, 'verify': verify}[sys.argv[1]]()
