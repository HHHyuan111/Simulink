"""Publish bounded isolation evidence while preserving unsuccessful probes."""
from pathlib import Path
from datetime import datetime
import hashlib
import json
import shutil

BASE = Path(__file__).resolve().parents[2]
DEST = BASE / 'milestones/N3R2/isolation_20261017'


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def read(path):
    return json.loads(path.read_text('utf-8-sig'))


def main():
    frozen = read(BASE / 'milestones/N3R1/frozen_candidate.json')
    assert sha(BASE.parent / 'PMSM_FOC_R2026a.slx') == frozen['model_sha256']
    for entry in frozen['files']:
        assert sha(BASE / entry['path']) == entry['sha256']
    patterns = ('N3R2_core_isolation_once', 'N3R2_reduced_core_*',
                'N3R2_native_logger_isolation_once', 'N3R2_original_only_isolation_*',
                'N3R2_port_geometry*', 'N3R2_native_queue_isolation_once',
                'N3R2_native_voltage_isolation_once')
    folders = sorted({p for pattern in patterns for p in (BASE / 'runs').glob(pattern) if p.is_dir()})
    records, published = [], []

    def publish(path, target):
        destination = DEST / target
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, destination)
        published.append({'source': path.relative_to(BASE).as_posix(),
                          'published': target, 'sha256': sha(destination)})

    for folder in folders:
        if not (folder / 'report.json').exists():
            continue
        record = read(folder / 'report.json')
        if (folder / 'probe_source.m.txt').exists():
            assert sha(folder / 'probe_source.m.txt') == record['probe_sha256']
        if (folder / 'audit_source.m.txt').exists():
            assert sha(folder / 'audit_source.m.txt') == record['audit_sha256']
        for entry in record.get('sources', []):
            assert sha(folder / 'source' / entry['path']) == entry['sha256']
        for entry in record.get('diagnostic_sources', []):
            assert sha(folder / Path(entry['path']).name) == entry['sha256']
        if (folder / 'contract.json').exists():
            assert sha(folder / 'contract.json') == record['contract_sha256']
        if record.get('raw_sha256'):
            assert sha(folder / 'signals.mat') == record['raw_sha256']
        if record.get('fixture_sha256'):
            assert sha(folder / 'fixture_source.m.txt') == record['fixture_sha256']
        if record.get('private_environment_sha256'):
            assert sha(folder / 'private_environment.json') == record['private_environment_sha256']
        models = list(folder.glob('*.slx'))
        if models:
            assert len(models) == 1
            assert sha(models[0]) == record.get('reduced_model_sha256', record.get('model_sha256'))
        exit_path = folder.with_name(folder.name + '_exit.json')
        exit_record = read(exit_path) if exit_path.exists() else {}
        for name in ('report.json', 'contract.json', 'execution_progress.json'):
            if (folder / name).exists():
                publish(folder / name, folder.name + '/' + name)
        if exit_path.exists():
            publish(exit_path, folder.name + '/exit.json')
        archive_hashes = {path.name: sha(path) for path in folder.glob('*.mat')}
        review_path = folder / 'review/core_fault_diagnosis.json'
        if review_path.exists():
            review = read(review_path)
            assert review['original_report_sha256'] == sha(folder / 'report.json')
            assert review['renderer_sha256'] == sha(BASE / 'robust/diagnostics/render_sensorless_r2_core_isolation.py')
            assert review['figure_sha256'] == sha(folder / 'review/core_fault_diagnosis.png')
            for case, entry in review['cases'].items():
                assert entry['source_mat_sha256'] == archive_hashes[case + '_core.mat']
            publish(review_path, folder.name + '/review/core_fault_diagnosis.json')
            publish(folder / 'review/core_fault_diagnosis.png', folder.name + '/review/core_fault_diagnosis.png')
        records.append({'folder': folder.name, 'kind': record['kind'], 'phase': record['phase'],
                        'phase_at_error': record.get('phase_at_error'), 'probe_all_passed': record['all_passed'],
                        'exit_code': exit_record.get('exit_code'), 'exit_finalized': bool(exit_record),
                        'case_id': record.get('case_id'), 'archive_hashes_at_curation': archive_hashes,
                        'report_sha256': sha(folder / 'report.json'),
                        'explicit_compilation_count_from_call_chain':
                            (2 if folder.name == 'N3R2_port_geometry_once' else 1)
                            if record['kind'] == 'compile_only_port_geometry' else None})
    summary = {'captured_at': datetime.now().astimezone().isoformat(), 'R2_all_passed': False,
               'R2_whole_model_case_status_changed': False, 'native_root_cause_confirmed': False,
               'source_and_model_integrity_passed': True, 'r1_frozen_files_preserved': len(frozen['files']),
               'model_sha256': frozen['model_sha256'],
               'scope': 'Isolation probes only. All pre-execution scripting/configuration errors are retained. Reduced and synthetic probes cannot close full-model fault gaps. Private environment, raw logs and dumps are excluded.',
               'records': records, 'published': published}
    host_report = DEST / 'host_observation_20261018.json'
    if host_report.exists():
        host = read(host_report)
        assert host['generator_sha256'] == sha(BASE / 'robust/diagnostics/record_sensorless_r2_host_observation.ps1')
        assert not host['host_settings_changed'] and not host['native_failure_causality_confirmed']
        summary['separate_host_observation'] = {'path': host_report.name, 'sha256': sha(host_report),
                                               'causality_confirmed': False}
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / 'summary.json').write_bytes((json.dumps(summary, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
    print(json.dumps({'records': len(records), 'files': len(published), 'integrity_passed': True, 'R2_all_passed': False}))


if __name__ == '__main__':
    main()
