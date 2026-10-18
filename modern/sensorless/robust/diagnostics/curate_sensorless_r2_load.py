"""Verify completed stopped diagnostics and retain their non-qualification scope."""
from pathlib import Path
import hashlib
import json
import shutil

BASE = Path(__file__).resolve().parents[2]
DEST = BASE / 'milestones/N3R2/stopped_isolation_20261018'


def read(path):
    return json.loads(path.read_text('utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = read(BASE / 'runs/N3R2_load_only_once/manifest.json')
    assert manifest['status'] == 'completed_passed' and len(manifest['jobs']) == 2
    rows = []
    for job in manifest['jobs']:
        assert job['status'] == 'passed' and job['exit_code'] == 0
        rows.append((Path(job['folder']), job['id'], 'probe_sensorless_r2_load_only.m'))
    launch = read(BASE / 'runs/N3R2_stopped_bootstrap_launch.json')
    assert launch['status'] == 'exited' and launch['exit_code'] == 0 and launch['default_compiler_preferences_unchanged']
    rows.append((Path(launch['folder']), 'stopped_bootstrap', 'probe_sensorless_r2_stopped_bootstrap.m'))
    summaries = []
    for folder, name, probe in rows:
        report = read(folder / 'report.json')
        assert report['all_passed'] and report['simulation_starts'] == 0
        assert not report['compile_requested'] and not report['model_saved'] and not report['observer_constructed']
        assert report['source_unchanged'] and report['closed']
        assert sha(folder / 'probe_source.m.txt') == report['probe_sha256'] == sha(BASE / 'robust/diagnostics' / probe)
        assert sha(folder / 'contract.json') == report['contract_sha256']
        if report.get('snapshot_sha256'):
            assert sha(folder / 'stopped_snapshot.mat') == report['snapshot_sha256']
        dest = DEST / name
        dest.mkdir(exist_ok=True)
        shutil.copyfile(folder / 'report.json', dest / 'report.json')
        summaries.append({'id': name, 'all_passed': True, 'report_sha256': sha(folder / 'report.json'),
                          'simulation_starts': 0, 'native_retries': 0})
    shutil.copyfile(BASE / 'runs/N3R2_load_only_once/manifest.json', DEST / 'load_manifest.json')
    shutil.copyfile(BASE / 'runs/N3R2_stopped_bootstrap_launch.json', DEST / 'bootstrap_launch.json')
    summary = {'analysis_only': True, 'simulation_reexecuted': False, 'all_diagnostic_checks_passed': True,
               'scope': 'Read-only loads and stopped preamble only. No physical simulation, observer integration or qualification.',
               'native_failure_reproduced': False, 'native_root_cause_confirmed': False,
               'failed_short_or_formal_case_reopened': False, 'R2_passed': False, 'runs': summaries}
    (DEST / 'summary.json').write_bytes((json.dumps(summary, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == '__main__':
    main()
