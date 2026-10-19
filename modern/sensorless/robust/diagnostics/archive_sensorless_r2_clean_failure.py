"""Create a source/artifact evidence mirror. No process inspection or simulation."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

BASE = Path(__file__).resolve().parents[2]
REPO = BASE.parent.parent
ROOT = BASE / 'runs/N3R2_clean_failure_evidence'
ZIP = BASE / 'runs/N3R2_clean_failure_evidence.zip'
DEST = BASE / 'milestones/N3R2/clean_formal_20261019'


def read(p):
    return json.loads(p.read_text('utf-8-sig'))


def sha(p):
    with p.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    assert not ROOT.exists() and not ZIP.exists(), 'Never replace an archived evidence bundle.'
    candidate_path = DEST / 'frozen_candidate.json'
    candidate = read(candidate_path)
    campaign = read(DEST / 'campaign.json')
    assert campaign['status'] == 'stopped_execution_failure'
    assert campaign['jobs'][0]['case_id'] == 'missing_five'
    assert all(j['status'] == 'pending' for j in campaign['jobs'][1:])
    build = BASE / 'runs/N3R2_clean_normal_formal_once/missing_five/build'
    record = read(build / 'record.json')
    assert record['status'] == 'passed'
    files = []

    def copy(source, relative, digest=None):
        assert source.resolve().is_relative_to(REPO.resolve())
        actual = sha(source)
        if digest: assert actual == digest, str(source)
        target = ROOT / relative
        assert target.resolve().is_relative_to(ROOT.resolve())
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        assert sha(target) == actual
        files.append({'path': target.relative_to(ROOT).as_posix(), 'sha256': actual})

    for entry in candidate['files']:
        source = REPO / entry['path']
        assert source.suffix.lower() in {'.m','.slx','.md','.json','.py','.ps1'}
        copy(source, 'source/' + entry['path'], entry['sha256'])
    copy(candidate_path, 'evidence/frozen_candidate.json')
    for name in ('campaign.json','summary.json'):
        copy(DEST / name, 'evidence/' + name)
    for name in ('execution_report.json','execution_native_crash.json'):
        copy(DEST / 'missing_five' / name, 'evidence/' + name)
    copy(BASE / 'milestones/N3R2/clean_qualification_20261019/summary.json', 'evidence/two_short_summary.json')
    copy(Path(record['owned_parent_file']), 'artifacts/parent/PMSM_FOC_R2026a.slx', record['exported_parent_sha256'])
    child = Path(record['reference_adapter']['child_file'])
    copy(child, 'artifacts/model/' + child.name, record['exported_child_sha256'])
    copy(build / 'handoff.mat', 'artifacts/handoff.mat', record['handoff_sha256'])
    copy(build / 'record.json', 'artifacts/builder_record.json')
    verifier = '''from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parent
manifest=json.loads((root/'manifest.json').read_text('utf8'))
for entry in manifest['files']:
    path=(root/entry['path']).resolve()
    assert path.is_relative_to(root),entry['path']
    with path.open('rb') as stream:
        actual=hashlib.file_digest(stream,'sha256').hexdigest()
    assert actual==entry['sha256'],entry['path']
print(json.dumps({'verified':True,'files':len(manifest['files']),'simulation_started':False}))
'''
    (ROOT / 'verify.py').write_bytes(verifier.encode())
    files.append({'path': 'verify.py', 'sha256': sha(ROOT / 'verify.py')})
    readme = '''# R2 clean-install failure: evidence mirror

This local bundle mirrors the complete frozen 871-file source set and exact saved
parent/child/handoff of the failed missing_five formal case. It contains only
project source, model parameters and sanitized evidence. It does not contain raw
console logs, crash texts, process memory captures, license files, tools or Git data.

Verified environment: MATLAB 26.1.0.3346908 R2026a Update 5, MATLAB/Simulink/Stateflow.
Two independent strict 20ms qualifications and their 96-log cross comparison passed.
Formal case1 stopped with native0xc0000005, no complete physical archive. Formal0/14,
remaining13 not started, no retry. Physical progress and fault injection time unknown.

Run only `python verify.py` to verify copied file bytes; it does not run MATLAB.
The saved handoff intentionally retains original absolute workspace/artifact paths.
This is an exact evidence mirror, not a tested portable execution package. A new
machine/path requires an explicitly registered path adaptation and separate
diagnostic protocol. Do not automatically rerun the closed formal candidate.
No reproduction pass, root-cause or hardware conclusion follows from this archive.
No files have been sent to a vendor or another account by this script.
'''
    (ROOT / 'README.md').write_bytes(readme.encode())
    files.append({'path': 'README.md', 'sha256': sha(ROOT / 'README.md')})
    manifest = {'schema': 1, 'created_at': datetime.now(timezone.utc).isoformat(),
                'candidate_sha256': sha(candidate_path), 'source_files': len(candidate['files']),
                'simulation_started': False, 'portable_execution_validated': False, 'files': files}
    (ROOT / 'manifest.json').write_bytes((json.dumps(manifest, indent=2) + '\n').encode())
    with zipfile.ZipFile(ZIP, 'x', compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(ROOT.rglob('*')):
            if path.is_file(): archive.write(path, path.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(ZIP) as archive:
        assert archive.testzip() is None
        for entry in files:
            assert hashlib.sha256(archive.read(entry['path'])).hexdigest() == entry['sha256']
    result = {'analysis_only': True, 'simulation_reexecuted': False, 'files': len(files),
              'zip_entries': len(files) + 1, 'zip_bytes': ZIP.stat().st_size,
              'zip_sha256': sha(ZIP), 'manifest_sha256': sha(ROOT / 'manifest.json'),
              'relative_zip': ZIP.relative_to(BASE).as_posix(), 'source_files_verified': len(candidate['files']),
              'portable_execution_validated': False, 'external_upload_performed': False,
              'raw_logs_or_process_captures_included': False, 'R2_passed': False}
    (DEST / 'local_evidence_bundle.json').write_bytes((json.dumps(result, indent=2) + '\n').encode())
    print(json.dumps(result))


if __name__ == '__main__':
    main()
