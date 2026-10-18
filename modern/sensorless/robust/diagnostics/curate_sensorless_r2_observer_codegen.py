"""Publish the narrowed boundary's actual qualification, never replay it."""
from datetime import datetime
import hashlib
import json
from pathlib import Path
import shutil

BASE = Path(__file__).resolve().parents[2]
DEST = BASE / 'milestones/N3R2/observer_codegen_20261018'


def read(p):
    return json.loads(p.read_text('utf-8-sig'))


def sha(p):
    with p.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    published = []

    def publish(p, name):
        target = DEST / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(p, target)
        published.append({'path': name, 'sha256': sha(target)})

    fixture = BASE / 'runs/N3R2_accelerated_reference_logging_once'
    proof = read(fixture / 'report.json')
    launch = read(BASE / 'runs/N3R2_accelerated_reference_logging_launch.json')
    assert launch['status'] == 'completed_passed' and proof['all_passed']
    assert sha(fixture / 'signals.mat') == proof['raw_sha256']
    assert sha(fixture / 'probe_source.m.txt') == proof['probe_sha256'] == launch['probe_sha256']
    assert sha(fixture / 'contract.json') == proof['contract_sha256']
    publish(fixture / 'report.json', 'component/report.json')
    publish(BASE / 'runs/N3R2_accelerated_reference_logging_launch.json', 'component/launch.json')
    root = BASE / 'runs/N3R2_observer_codegen_short_once'
    campaign = read(root / 'campaign.json')
    assert campaign['status'] != 'running', 'Never publish an unfinished test as a result.'
    publish(root / 'campaign.json', 'main/campaign.json')
    provenance = []
    for job in campaign['jobs']:
        folder = Path(job['folder'])
        r = read(folder / 'record.json')
        for entry in r['source_files']:
            assert sha(BASE / entry['path']) == entry['sha256'] == sha(folder / 'source' / entry['path'])
        for entry in r['contracts']:
            assert sha(BASE / entry['path']) == entry['sha256'] == sha(folder / entry['path'])
        item = {k: r[k] for k in ('case_id','execution_version','status','phase','process_id','simulation_starts',
            'native_endpoint_verified','layer_restored','reference_restored','callback_restored','main_bridge_preserved',
            'raw_sha256','elapsed_s','log_count') if k in r}
        item.update({'record_sha256': sha(folder / 'record.json'), 'source_files': r['source_files'], 'contracts': r['contracts']})
        provenance.append(item)
        if job['stage'] == 'build' and job['status'] == 'passed':
            assert r['main_bridge_preserved'] and r['reference_restored']
            assert sha(folder / 'handoff.mat') == r['handoff_sha256']
            assert sha(Path(r['owned_parent_file'])) == r['exported_parent_sha256']
            assert sha(Path(r['reference_adapter']['child_file'])) == r['exported_child_sha256']
        if (folder / 'report.json').exists():
            execution = read(folder / 'report.json')
            publish(folder / 'report.json', 'main/execution_report.json')
            for name in ('metrics.json','graph.json','generated_target_inventory.json','log_format_recovery.json',
                         'log_format/logging_validation.json','log_format/v7_complete_log_comparison.json'):
                if (folder / name).exists():
                    publish(folder / name, 'main/' + name)
    summary = {'captured_at': datetime.now().astimezone().isoformat(), 'analysis_only': True,
               'simulation_reexecuted_by_curator': False, 'parent_normal_child_accelerated_component_passed': True,
               'main_status': campaign['status'], 'strict96_short_passed': campaign['status'] == 'completed_passed',
               'R2_passed': False, 'native_root_cause_confirmed': False, 'formal_previous_still_closed_at': '1/14',
               'last_durable_phase': execution.get('phase_at_error', execution['phase']) if 'execution' in locals() else provenance[-1]['phase']}
    code = campaign['jobs'][-1]['exit_code']
    summary.update({'exit_code': code, 'exit_hex': f'0x{code & 0xffffffff:08x}',
                    'native_failure_observed': (code & 0xffffffff) == 0xc0000005,
                    'exit_code_authoritative_over_legacy_attempt_native_failure_annotation': True})
    if summary['strict96_short_passed']:
        folder = Path(campaign['jobs'][1]['folder'])
        r = read(folder / 'record.json')
        comparison = read(folder / 'log_format/v7_complete_log_comparison.json')
        common = read(folder / 'log_format/logging_validation.json')
        assert comparison['all_passed'] and comparison['all_Time_Data_equal'] and comparison['logs'] == 96
        assert common['all_passed'] and common['compared_logs'] == 81 and common['original52_included']
        assert r['native_endpoint_verified'] and r['main_bridge_preserved'] and r['reference_restored']
        assert sha(folder / 'signals.mat') == r['raw_sha256']
        summary['numeric_elements'] = comparison['numeric_elements']
        summary['native_endpoint_rows'] = 320001
    (DEST / 'source_provenance.json').write_bytes((json.dumps(provenance, ensure_ascii=True, indent=2)+'\n').encode())
    published.append({'path': 'source_provenance.json', 'sha256': sha(DEST / 'source_provenance.json')})
    summary['published'] = published
    (DEST / 'summary.json').write_bytes((json.dumps(summary, ensure_ascii=True, indent=2)+'\n').encode())
    print(json.dumps({k: summary[k] for k in ('main_status','strict96_short_passed','R2_passed')}))


if __name__ == '__main__':
    main()
