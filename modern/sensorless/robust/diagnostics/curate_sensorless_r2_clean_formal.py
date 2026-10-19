"""Audit stable formal records and publish safe milestone evidence only."""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import runpy

BASE = Path(__file__).resolve().parents[2]
ROOT = BASE / 'runs/N3R2_clean_normal_formal_once'
DEST = BASE / 'milestones/N3R2/clean_formal_20261019'


def read(p):
    return json.loads(p.read_text('utf-8-sig'))


def sha(p):
    with p.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def publish(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes((json.dumps(value, indent=2) + '\n').encode('utf8'))


def main():
    helper = runpy.run_path(str(BASE / 'robust/normal_serialized/clean_formal.py'))
    candidate = helper['verify']()
    frozen = DEST / 'frozen_candidate.json'
    campaign = read(ROOT / 'campaign.json')
    assert campaign['candidate_sha256'] == sha(frozen)
    assert [j['case_id'] for j in campaign['jobs']] == candidate['formal_case_order']
    publish(DEST / 'campaign.json', campaign)
    results = []
    for job in campaign['jobs']:
        entry = {'case_id': job['case_id'], 'status': job['status'], 'formal_retries': 0}
        folder = ROOT / job['case_id'] / 'execution'
        if job['status'] == 'passed':
            record = read(folder / 'record.json');metrics = read(folder / 'metrics.json')
            provenance = read(folder / 'formal_provenance.json')
            assert provenance['candidate_sha256'] == sha(frozen)
            assert provenance['record_sha256'] == sha(folder / 'record.json')
            assert provenance['raw_sha256'] == record['raw_sha256'] == sha(folder / 'signals.mat')
            assert provenance['canonical_sha256'] == sha(folder / 'log_format/signals.mat')
            assert record['status'] == 'passed' and metrics['all_passed'] and metrics['false_valid_longest_s'] <= .002 + 1e-12
            destination = DEST / job['case_id']
            audit = []
            for name in ('metrics.json','report.json','graph.json','direct_graph.json','log_format_recovery.json','formal_provenance.json'):
                value = read(folder / name)
                if name in ('graph.json','direct_graph.json'): assert value['passed']
                publish(destination / name, value)
                audit.append({'path': name, 'sha256': sha(folder / name)})
            entry.update({'process_id': record['process_id'], 'builder_process_id': record['builder_process_id'],
                          'duration_s': record['effective_case']['duration_s'], 'elapsed_s': record['elapsed_s'],
                          'native_endpoint_verified': record['native_endpoint_verified'],
                          'restoration_verified': record['reference_restored'] and record['main_bridge_preserved'],
                          'log_count': record['log_count'], 'raw_sha256': record['raw_sha256'],
                          'record_sha256': sha(folder / 'record.json'), 'false_valid_longest_s': metrics['false_valid_longest_s'],
                          'metrics': metrics, 'audited_files': audit})
        elif job['status'] != 'pending' and campaign['status'] != 'running':
            for stage in ('build','execution'):
                path = ROOT / job['case_id'] / stage / 'record.json'
                if path.exists():
                    record = read(path)
                    entry[stage] = {key: record.get(key) for key in ('process_id','status','phase','simulation_starts','native_endpoint_verified','reference_restored','main_bridge_preserved')}
                    report = path.parent / 'report.json'
                    if report.exists(): publish(DEST / job['case_id'] / (stage + '_report.json'), read(report))
                    if any(s['stage'] == stage and s['exit_hex'] in ('0xc0000005','0xc0000409','0xc000001d','0x80000003') for s in job['stages']):
                        parser = runpy.run_path(str(Path(__file__).with_name('curate_sensorless_r2_crash_context.py')))
                        for dump in Path(os.environ['TEMP']).glob(f"matlab_crash_dump.{record['process_id']}-*"):
                            started = datetime.fromisoformat(job['stages'][0]['started_at']).timestamp()
                            if dump.stat().st_mtime < started: continue
                            publish(DEST / job['case_id'] / (stage + '_native_crash.json'),
                                    {'actual_pid': record['process_id'], 'private_dump_bytes': dump.stat().st_size,
                                     'private_dump_sha256': sha(dump), 'whitelisted_frames_only': parser['frames'](dump)})
        results.append(entry)
    passed = [r for r in results if r['status'] == 'passed']
    complete = campaign['status'] == 'completed_passed'
    if complete:
        assert len(passed) == 14 and not campaign['remaining_cases'] and campaign['R2_passed']
        assert all(r['native_endpoint_verified'] and r['restoration_verified'] for r in passed)
    summary = {'captured_at': datetime.now(timezone.utc).isoformat(), 'analysis_only': True,
               'simulation_reexecuted': False, 'status': campaign['status'], 'R2_passed': complete,
               'passed_cases': len(passed), 'total_cases': 14, 'remaining_cases': campaign['remaining_cases'],
               'candidate_sha256': sha(frozen), 'frozen_files_verified': len(candidate['files']),
               'formal_retries': 0, 'results': results, 'old_formal1of14_closed_preserved': True,
               'old_Normal_short_failure_preserved': True, 'native_root_cause_confirmed': False,
               'hardware_or_WCET_validated': False, 'R3_started': False, 'feedback_takeover': False,
               'curator_sha256': sha(Path(__file__))}
    publish(DEST / 'summary.json', summary)
    print(json.dumps({k: summary[k] for k in ('status','passed_cases','total_cases','R2_passed')}))


if __name__ == '__main__':
    main()
