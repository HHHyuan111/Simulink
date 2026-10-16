"""Publish verified N3 metadata and tables; never change raw case archives."""
from pathlib import Path
import argparse
import csv
import difflib
import hashlib
import json
import math
import shutil

HERE = Path(__file__).resolve().parent
OUT = HERE / 'milestones' / 'N3'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_csv(name, rows):
    with (OUT/name).open('w', newline='', encoding='utf-8-sig') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader(); writer.writerows(rows)


def false_valid_intervals(case, metrics):
    criteria = read(HERE/'contracts/acceptance_v1.json')['dynamic']
    period = 50e-6
    intervals, active, count = [], None, 0
    with (OUT/f'{case}_plot_data.csv').open(encoding='utf-8-sig', newline='') as stream:
        for row in csv.DictReader(stream):
            t = float(row['time_s'])
            angle = abs(float(row['angle_error_rad']))*180/math.pi
            relative = abs(float(row['speed_rpm'])-float(row['truth_speed_rpm']))/max(abs(float(row['truth_speed_rpm'])), 1)
            bad = bool(float(row['valid'])) and (angle > criteria['angle_abs_max_electrical_deg'] or relative > criteria['speed_error_relative_max'])
            if bad:
                count += 1
                if active is None:
                    active = {'case_id': case, 'begin_s': t, 'end_exclusive_s': t+period,
                              'samples': 0, 'duration_s': 0, 'peak_angle_abs_deg': 0,
                              'peak_speed_error_relative': 0}
                active['samples'] += 1; active['end_exclusive_s'] = t+period
                active['duration_s'] = active['samples']*period
                active['peak_angle_abs_deg'] = max(active['peak_angle_abs_deg'], angle)
                active['peak_speed_error_relative'] = max(active['peak_speed_error_relative'], relative)
            elif active is not None:
                intervals.append(active); active = None
    if active is not None:
        intervals.append(active)
    assert count == metrics['false_valid_samples']
    assert abs(max((r['duration_s'] for r in intervals), default=0)-metrics['false_valid_longest_s']) < 1e-12
    return intervals


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('original', type=Path)
    parser.add_argument('replay', type=Path)
    parser.add_argument('capsule', type=Path)
    args = parser.parse_args()
    replay = read(args.replay/'replay_validation.json')
    assert len(replay['cases']) == 16
    assert replay['completed_replays_identical'] and replay['old52_all_identical']
    assert 0 <= replay['completed_replay_cases'] <= 16
    correction = read(OUT/'diagnostic_correction.json')
    assert correction['all_required_flags_identical'] and correction['corrected_replay_metrics_identical']
    for source, target in ((args.replay/'replay_validation.json', 'replay_validation.json'),
                           (args.replay/'campaign.json', 'replay_campaign.json'),
                           (args.capsule/'capsule_manifest.json', 'source_capsule_manifest.json')):
        shutil.copy2(source, OUT/target)
    windows, events, false_intervals, preserved = [], [], [], []
    expected_model = read(HERE/'milestones/N3_final_parameters.json')['model_sha256']
    for entry in read(args.original/'campaign.json')['entries']:
        record = read(Path(entry['completed_folder'])/'record.json')
        assert record['model_sha256'] == expected_model and record['all_passed']
        preserved.append({'case_id': entry['case_id'], 'kind': entry['kind'],
                          'model_sha256': record['model_sha256'], 'motor_pi': record['motor_pi'],
                          'layer_restored': record['layer_restored'],
                          'reference_restored': record['reference_restored']})
        if entry['kind'] != 'observer':
            continue
        metrics = read(OUT/f'{entry["case_id"]}_metrics.json')
        assert metrics['passed']
        false_intervals.extend(false_valid_intervals(entry['case_id'], metrics))
        for name, target in (('windows', windows), ('events', events)):
            rows = metrics[name]
            rows = [rows] if isinstance(rows, dict) else rows
            for row in rows:
                target.append({'case_id': entry['case_id'], **row})
    write_csv('window_metrics.csv', windows)
    write_csv('event_metrics.csv', events)
    write_csv('false_valid_intervals.csv', false_intervals)
    assert len(preserved) == 25 and all(r['motor_pi'] == preserved[0]['motor_pi']
        and r['layer_restored'] and r['reference_restored'] for r in preserved)
    (OUT/'model_preservation.json').write_text(json.dumps({
        'schema': 1, 'cases': preserved, 'all_passed': True}, indent=2), encoding='utf-8')
    old = (OUT/'analysis_executed.txt').read_text(encoding='utf-8-sig').splitlines(True)
    new = (HERE/'analyse_sensorless_n3_case.m').read_text(encoding='utf-8-sig').splitlines(True)
    (OUT/'diagnostic_correction.diff').write_text(''.join(difflib.unified_diff(
        old, new, fromfile='executed/analyse_sensorless_n3_case.m',
        tofile='corrected/analyse_sensorless_n3_case.m')), encoding='utf-8')
    failures = []
    for path in sorted((HERE/'runs').glob('N3_*/**/record.json')):
        record = read(path)
        if record.get('status') in ('passed', 'failed_metrics'):
            continue
        launch = path.parent/'launcher_failure.json'
        launcher = read(launch) if launch.exists() else None
        failures.append({'folder': str(path.parent.relative_to(HERE)).replace('\\', '/'),
                         'status': record.get('status'), 'last_phase': record.get('phase'),
                         'error': record.get('error'), 'record_sha256': sha(path),
                         'launcher': launcher,
                         'classification': 'agent_interrupted_for_execution_diagnosis'
                         if 'N3_formal_20261016_163302' in str(path) and record.get('case_id') == 'steady_3000'
                         else 'preserved_failed_attempt',
                         'source_snapshot_retained': (path.parent/'source').is_dir(),
                         'raw_data_retained': (path.parent/'signals.mat').exists()})
    report = {'schema': 1, 'node': 'N3', 'failures': failures,
              'native_root_cause': 'unconfirmed', 'thresholds_changed': False, 'records_deleted': False,
              'postprocessing': [
                  {'action': 'plot before CSV export finished', 'status': 'failed_missing_provenance',
                   'resolution': 'wait for exporter completion; rerun renderer after corrected reports'},
                  {'action': 'diagnostic fault/zero-speed relative metrics', 'status': 'corrected_from_same_raw_data',
                   'evidence': 'diagnostic_correction.json',
                   'format_fix': 'Canonical JSON comparison is temporary only; preserve NaN as null instead of converting N/A to an empty array on export.'},
                  {'action': 'data-only chunk verifier preparation', 'status': 'fixed_before_final_audit',
                   'issues': ['R2026a fopen all unsupported in cleanup; use direct owned-handle fclose',
                              'synthetic 3D timeseries shape incompatible with default time axis; use valid different column count'],
                   'evidence': 'comparison_oracle.json'},
                  {'action': 'data-only validation launcher v3', 'status': 'native_0xc000001d',
                   'model_loaded': False, 'root_cause': 'unconfirmed',
                   'retained_log': '.build/n3_archive_audit_chunked_v3.log'},
                  {'action': 'initial data-only audit', 'status': 'agent_interrupted_for_io_optimization',
                   'completed_before_interrupt': ['steady_1000', 'steady_2000'],
                   'retained_log': '.build/n3_archive_audit.log'}]}
    report['postprocessing_log_hashes'] = [
        {'path': str(p.relative_to(HERE)).replace('\\', '/'), 'sha256': sha(p)}
        for p in sorted((HERE/'.build').glob('n3_*.log')) if p.is_file()]
    (OUT/'development_failures.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    summary = read(OUT/'summary.json')
    summary['formal_case_checks_all_passed'] = summary.pop('all_passed', summary.get('formal_case_checks_all_passed'))
    summary['required_replay_cases'] = 16
    summary['completed_replay_cases'] = replay['completed_replay_cases']
    summary['node_all_passed'] = replay['all_passed']
    summary['status'] = replay['status']
    (OUT/'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'N3 reports finalized: {len(windows)} windows, {len(events)} events, {len(failures)} preserved failed attempts')


if __name__ == '__main__':
    main()
