"""Publish exact runtime/lifecycle/persistence evidence without private raw logs."""
from pathlib import Path
from datetime import datetime
import hashlib
import json
import shutil

BASE = Path(__file__).resolve().parents[2]
DEST = BASE / 'milestones/N3R2/local_diagnostics_20261018'


def read(path):
    return json.loads(path.read_text('utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    published = []

    def publish(path, name):
        destination = DEST / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, destination)
        published.append({'path': name, 'sha256': sha(destination)})

    runtime = BASE / 'runs/N3R2_runtime_oracle_once'
    oracle = read(runtime / 'oracle.json')
    parent = read(runtime / 'launch.json')
    native = read(runtime / 'native_result.json')
    matlab = read(runtime / 'matlab_result.json')
    first = read(runtime / 'matlab_first_launch.json')
    assert parent['status'] == 'stopped_failure' and not native['all_passed']
    assert native['cycles'] == 100000 and native['elapsed_ms'] == 59844
    assert first['status'] == 'completed_passed' and matlab['all_passed']
    for name in ('oracle.bin', 'native_vector.bin', 'matlab_vector.bin'):
        assert sha(runtime / name) == oracle['sha256']
    assert sha(runtime / 'runtime_control.exe') == parent['native_executable_sha256']
    assert sha(runtime / 'sensorless_r2_runtime_control.c') == parent['native_source_sha256']
    assert sha(runtime / 'matlab_probe_source.m.txt') == matlab['source_sha256']
    assert sha(BASE / 'robust/diagnostics/prepare_sensorless_r2_runtime_oracle.py') == oracle['generator_sha256']
    for name in ('oracle.json', 'launch.json', 'native_result.json', 'native_processor_histogram.json',
                 'matlab_result.json', 'matlab_first_launch.json'):
        publish(runtime / name, 'runtime/' + name)
    lifecycle = BASE / 'runs/N3R2_stopped_lifecycle_once'
    life = read(lifecycle / 'report.json')
    assert life['all_passed'] and life['completed_cycles'] == 20 and life['simulation_starts'] == 0
    assert sha(lifecycle / 'probe_source.m.txt') == life['probe_sha256']
    assert sha(lifecycle / 'contract.json') == life['contract_sha256']
    assert sha(lifecycle / 'first_cycle_snapshot.mat') == life['first_cycle_snapshot_sha256']
    edges = [json.loads(line) for line in (lifecycle / 'edges.jsonl').read_text('utf-8').splitlines()]
    for cycle in range(1, 21):
        assert sum(edge['cycle'] == cycle and edge['phase'] == 'cycle_completed' for edge in edges) == 1
    for name in ('report.json', 'edges.jsonl'):
        publish(lifecycle / name, 'stopped_lifecycle/' + name)
    publish(BASE / 'runs/N3R2_stopped_lifecycle_launch.json', 'stopped_lifecycle/launch.json')
    persistence = BASE / 'runs/N3R2_workspace_persistence_once'
    storage = read(persistence / 'report.json')
    assert storage['all_passed'] and storage['simulation_starts'] == 0
    assert storage['negative_control']['expected_loss_observed']
    assert storage['positive_control']['complete_roundtrip']
    for key in ('negative_control', 'positive_control'):
        entry = storage[key]
        assert sha(Path(entry['file'])) == entry['file_sha256']
    assert sha(persistence / 'expected.mat') == storage['expected_sha256']
    assert sha(persistence / 'probe_source.m.txt') == storage['probe_sha256']
    assert sha(persistence / 'contract.json') == storage['contract_sha256']
    publish(persistence / 'report.json', 'workspace_persistence/report.json')
    publish(BASE / 'runs/N3R2_workspace_persistence_launch.json', 'workspace_persistence/launch.json')
    summary = {'captured_at': datetime.now().astimezone().isoformat(), 'analysis_only': True,
               'simulation_reexecuted': False, 'native_runtime': {'cycles': native['cycles'],
               'elapsed_s': native['elapsed_ms'] / 1000, 'all_bytes_equal': True,
               'duration_criterion_met': False, 'original_all_passed': native['all_passed']},
               'matlab_runtime': {'cycles': matlab['cycles'], 'elapsed_s': matlab['elapsed_s'], 'all_bytes_equal': True,
                                  'first_process_passed': True}, 'original_two_stage_protocol_incomplete': True,
               'stopped_lifecycle_completed_cycles': 20, 'stopped_lifecycle_native_failure_reproduced': False,
               'workspace_persistence_gap_confirmed': True, 'model_file_storage_control_passed': True,
               'native_root_cause_confirmed': False, 'hardware_health_established': False,
               'R2_passed': False, 'formal_or_failed_short_restarted': False, 'published': published}
    (DEST / 'summary.json').write_bytes((json.dumps(summary, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
    print(json.dumps({key: summary[key] for key in ('original_two_stage_protocol_incomplete',
          'workspace_persistence_gap_confirmed', 'stopped_lifecycle_completed_cycles', 'R2_passed')}))


if __name__ == '__main__':
    main()
