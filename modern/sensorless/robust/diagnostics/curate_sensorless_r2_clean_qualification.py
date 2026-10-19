"""Publish prospective short qualification evidence without simulation."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import runpy

BASE = Path(__file__).resolve().parents[2]
RUN = BASE / 'runs/N3R2_clean_normal_qualification_once'
DEST = BASE / 'milestones/N3R2/clean_qualification_20261019'


def read(p):
    return json.loads(p.read_text('utf-8-sig'))


def sha(p):
    with p.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def publish(name, value):
    (DEST / name).write_bytes((json.dumps(value, indent=2) + '\n').encode('utf8'))


def main():
    guard = runpy.run_path(str(BASE / 'robust/normal_serialized/clean_qualification.py'))
    guard['verify']()
    campaign = read(RUN / 'campaign.json')
    publish('campaign.json', campaign)
    completed = []
    for stage in ('short_1', 'short_2'):
        folder = RUN / stage
        if not (folder / 'report.json').exists():
            continue
        report = read(folder / 'report.json')
        publish(stage + '_report.json', report)
        record = read(folder / 'record.json')
        entry = {'stage': stage, 'process_id': record['process_id'], 'status': record['status'],
                 'phase': record['phase'], 'record_sha256': sha(folder / 'record.json'),
                 'raw_archive_present': (folder / 'signals.mat').exists(),
                 'native_endpoint_verified': record['native_endpoint_verified'],
                 'actual_restoration_verified': record['reference_restored'] and record['main_bridge_preserved'],
                 'strict96_passed': False, 'original81_and52_passed': False}
        for source, name in (('log_format/v7_complete_log_comparison.json', 'strict96'),
                             ('log_format/logging_validation.json', 'original81'), ('metrics.json', 'metrics')):
            p = folder / source
            if p.exists():
                result = read(p)
                publish(stage + '_' + name + '.json', result)
                if name == 'strict96':
                    entry['strict96_passed'] = result['all_passed'] and result['logs'] == 96
                elif name == 'original81':
                    entry['original81_and52_passed'] = result['all_passed'] and result['original52_included']
        if entry['raw_archive_present']:
            entry['raw_sha256'] = sha(folder / 'signals.mat')
            assert entry['raw_sha256'] == record['raw_sha256']
        completed.append(entry)
    comparison = RUN / 'cross_process_comparison.json'
    cross = read(comparison) if comparison.exists() else None
    if cross:
        publish('cross_process_comparison.json', cross)
    passed = campaign['status'] == 'completed_passed'
    if passed:
        assert len(completed) == 2 and completed[0]['process_id'] != completed[1]['process_id']
        assert all(e['status'] == 'passed' and e['native_endpoint_verified'] and e['actual_restoration_verified']
                   and e['strict96_passed'] and e['original81_and52_passed'] for e in completed)
        assert cross['all_passed'] and cross['logs'] == 96 and cross['all_Time_Data_class_dimensions_equal']
    summary = {'captured_at': datetime.now(timezone.utc).isoformat(), 'analysis_only': True,
               'simulation_reexecuted': False, 'qualification_passed': passed, 'status': campaign['status'],
               'diagnostic_control_counted_as_short': False, 'retries': 0, 'shorts': completed,
               'cross_comparison_passed': bool(cross and cross['all_passed']),
               'source_manifest_sha256': sha(DEST / 'qualification_sources.json'),
               'R2_passed': False, 'new_formal_matrix_started': False, 'native_root_cause_confirmed': False,
               'curator_sha256': sha(Path(__file__))}
    publish('summary.json', summary)
    print(json.dumps({key: summary[key] for key in ('qualification_passed', 'status', 'cross_comparison_passed', 'R2_passed')}))


if __name__ == '__main__':
    main()
