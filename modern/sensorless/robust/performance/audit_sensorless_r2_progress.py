"""Read-only provenance audit. Integrity success is not R2 performance success."""
from pathlib import Path
import hashlib
import json
import shutil

BASE = Path(__file__).resolve().parents[2]
DEST = BASE / 'milestones' / 'N3R2'
RUNS = BASE / 'runs'
CAMPAIGNS = [
    'N3R2_R1_numerical_diagnosis_20261017_080647_bd9f1982-91f2-4ec8-88d7-01d2bf06ed66',
    'N3R2_safe_init_v2_20261017_081750_e4be6165-1fc2-46ff-91c1-ca86e179e494',
]
SHORT = RUNS / CAMPAIGNS[1] / 'r1_short_logging_check_attempt_2'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def copy_record(source, name):
    target = DEST / name
    shutil.copyfile(source, target)
    return {'path': str(source.relative_to(BASE)).replace('\\', '/'),
            'sha256': sha(source), 'published': name}


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    frozen = read(BASE / 'milestones/N3R1/frozen_candidate.json')
    for entry in frozen['files']:
        assert sha(BASE / entry['path']) == entry['sha256'], entry['path']
    model = BASE.parent / 'PMSM_FOC_R2026a.slx'
    assert sha(model) == frozen['model_sha256']
    plan = BASE / 'contracts/nonideal_r2_test_plan.json'
    assert sha(plan) == '6cedde9bcf37926542541d286d6d4167d2c596969998c5a20893a5063d60c439'
    records, archives, attempts = [], [], []
    for index, name in enumerate(CAMPAIGNS, start=1):
        campaign = RUNS / name
        manifest = read(campaign / 'campaign.json')
        records.append(copy_record(campaign / 'campaign.json', f'campaign_execution_v{index}.json'))
        for job in manifest['jobs']:
            for attempt in job['attempts']:
                path = Path(attempt['folder'])
                record = read(path / 'record.json')
                for entry in record['source_files']:
                    assert sha(path / 'source' / entry['path']) == entry['sha256'], entry['path']
                for entry in record['contracts']:
                    assert sha(path / entry['path']) == entry['sha256'], entry['path']
                attempts.append({'case_id': job['case_id'], 'folder': str(path.relative_to(BASE)).replace('\\', '/'),
                                 'execution_version': record.get('execution_version', 'initial_v1'),
                                 'last_phase': record['phase'], 'exit_code': attempt['exit_code'],
                                 'native_failure': attempt['native_failure'],
                                 'record_sha256': sha(path / 'record.json')})
                archives.append({'folder': str(path.relative_to(BASE)).replace('\\', '/'),
                                 'source_files_verified': len(record['source_files']),
                                 'contracts_verified': len(record['contracts'])})
    short = read(SHORT / 'record.json')
    assert short['status'] == 'passed' and short['reference_restored'] and short['callback_restored']
    assert sha(SHORT / 'signals.mat') == short['raw_sha256']
    for name in ('record.json', 'metrics.json', 'logging_validation.json', 'graph.json'):
        records.append(copy_record(SHORT / name, 'short_' + name))
    changed = [entry['path'] for entry in short['source_files']
               if sha(BASE / entry['path']) != entry['sha256']]
    assert changed == ['robust/performance/validate_sensorless_r2_case.m'], changed
    version_dir = DEST / 'source_versions'
    version_dir.mkdir(exist_ok=True)
    for label, folder in [('execution_v1', RUNS / CAMPAIGNS[0] / 'r1_short_logging_check_attempt_1'),
                          ('execution_v2', SHORT)]:
        source = folder / 'source/robust/performance/validate_sensorless_r2_case.m'
        shutil.copyfile(source, version_dir / (label + '_worker.m.txt'))
    for name, prefix, raw_name in [('N3R2_monitor_development_1', 'monitor_component', 'monitor.mat'),
                                  ('N3R2_compiled_monitor_probe_once', 'compiled_monitor_probe', 'probe.mat')]:
        folder = RUNS / name
        record = read(folder / 'record.json')
        assert record['status'] in ('passed', 'diagnostic_passed')
        assert sha(folder / raw_name) == record['raw_sha256']
        records.append(copy_record(folder / 'record.json', prefix + '_record.json'))
        if (folder / 'metrics.json').exists():
            records.append(copy_record(folder / 'metrics.json', prefix + '_metrics.json'))
    records.append(copy_record(RUNS / 'N3R2_configuration_probe_once/record.json', 'configuration_probe_record.json'))
    rejection = RUNS / 'N3R2_unsupported_case_rejections_once/report.json'
    assert read(rejection)['all_passed'] and not read(rejection)['pmsm_loaded']
    records.append(copy_record(rejection, 'unsupported_case_rejections.json'))
    report = {'node': 'N3R2', 'status': 'incomplete_native_compilation_failure',
              'audit_integrity_passed': True, 'r2_performance_passed': False,
              'formal_candidate_frozen': False, 'independent_full_replay_completed': False,
              'model_sha256': sha(model), 'r1_frozen_files_preserved': len(frozen['files']),
              'r2_plan_sha256': sha(plan), 'attempts': attempts, 'archived_capsules': archives,
              'curated_records': records, 'post_test_source_changes': changed,
              'post_test_change_reason': 'Fail fast for unsupported dynamic/fault kinds, checked without model load; driver additionally rejects exhausted attempts across campaign labels. No new main-model execution after these guard changes.',
              'short_worker_source_preserved': 'source_versions/execution_v2_worker.m.txt',
              'raw_archives_local_only': True, 'native_root_cause_confirmed': False,
              'no_third_same_version_long_attempt': True}
    (DEST / 'provenance_audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f"R2_ARCHIVE_INTEGRITY_PASSED capsules={len(archives)} R1_frozen={len(frozen['files'])}")
    print('R2_PERFORMANCE_PASSED=False; long diagnostic has no simulation result')


if __name__ == '__main__':
    main()
