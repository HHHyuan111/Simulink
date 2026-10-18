"""Verify child-only failure evidence and zip only its approved source bundle."""
from datetime import datetime
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

BASE = Path(__file__).resolve().parents[2]
DEST = BASE / 'milestones/N3R2/child_only_build_20261018'


def read(p):
    return json.loads(p.read_text('utf-8-sig'))


def sha(p):
    with p.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    root = BASE / 'runs/N3R2_child_only_build_once'
    package = BASE / 'runs/N3R2_child_only_build_bundle'
    launch = read(BASE / 'runs/N3R2_child_only_build_launch.json')
    report = read(root / 'report.json')
    manifest = read(package / 'manifest.json')
    assert launch['status'] == 'stopped_execution_failure' and launch['exit_code'] == -1073741819
    assert report['simulation_starts'] == 0 and not report['parent_ever_loaded']
    assert report['workspace_count'] == 86 and report['configuration_values_exact']
    assert report['phase'] == 'build_child_target_once'
    assert launch['manifest_sha256'] == report['manifest_sha256'] == sha(package / 'manifest.json')
    for entry in manifest['files']:
        assert sha(package / entry['path']) == entry['sha256']
    assert manifest['runtime_source_count'] == 176
    model = package / manifest['model_file']
    assert sha(model) == manifest['model_sha256']
    archive = BASE / 'runs/N3R2_child_only_build_repro.zip'
    assert not archive.exists(), 'Never silently replace a published reproduction bundle.'
    with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED) as z:
        for entry in manifest['files']:
            z.write(package / entry['path'], entry['path'])
        z.write(package / 'manifest.json', 'manifest.json')
    DEST.mkdir(parents=True, exist_ok=True)
    for source, name in ((BASE / 'runs/N3R2_child_only_build_launch.json','launch.json'),
                         (root / 'report.json','report.json'), (package / 'manifest.json','package_manifest.json')):
        shutil.copyfile(source, DEST / name)
    summary = {'captured_at': datetime.now().astimezone().isoformat(), 'analysis_only': True,
               'simulation_reexecuted_by_curator': False, 'child_only_build_status': launch['status'],
               'actual_pid': report['process_id'], 'exit_hex': '0xc0000005', 'physical_simulation_starts': 0,
               'parent_loaded': False, 'raw_source_model_same_as_failed_parent_loaded_case': True,
               'target_builds_requested': 1, 'standalone_native_failure_reproduced': True,
               'native_root_cause_confirmed': False, 'hardware_failure_confirmed': False,
               'private_dump_available': False, 'R2_passed': False,
               'configuration_metadata_note': 'configuration_exact compares JSON vector orientation; Model File bytes SHA-identical, configuration_values_exact true. No dimension/value mutation was applied.',
               'package_manifest_sha256': sha(package / 'manifest.json'),
               'reproduction_zip': str(archive), 'zip_sha256': sha(archive), 'zip_bytes': archive.stat().st_size,
               'zip_entries': len(manifest['files'])+1,
               'no_parent_model_or_raw_dump_private_log_or_license_in_zip': True,
               'main_qualification_restarted': False, 'formal_previous_still_closed_at': '1/14'}
    (DEST / 'summary.json').write_bytes((json.dumps(summary, ensure_ascii=True, indent=2)+'\n').encode())
    print(json.dumps({k: summary[k] for k in ('standalone_native_failure_reproduced','zip_entries','zip_bytes','R2_passed')}))


if __name__ == '__main__':
    main()
