"""Verify and publish the stopped Normal qualification; never replay it."""
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil

BASE = Path(__file__).resolve().parents[2]
ROOT = BASE / 'runs/N3R2_normal_serialized_short_once'
DEST = BASE / 'milestones/N3R2/normal_serialized_20261018'


def read(p):
    return json.loads(p.read_text('utf-8-sig'))


def sha(p):
    with p.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    campaign = read(ROOT / 'campaign.json')
    assert campaign['status'] == 'stopped_execution_failure'
    assert [job['stage'] for job in campaign['jobs']] == ['build','short_1','short_2','compare']
    assert campaign['jobs'][0]['status'] == 'passed'
    assert campaign['jobs'][1]['exit_code'] == -1073741819 and campaign['jobs'][1]['native_failure']
    assert all(job['status'] == 'pending' and job['exit_code'] is None for job in campaign['jobs'][2:])
    source_manifest = DEST / 'prequalification_sources.json'
    assert sha(source_manifest) == campaign['source_manifest_sha256']
    frozen = {entry['path']: entry['sha256'] for entry in read(source_manifest)['files']}
    repo = BASE.parent.parent
    for relative, digest in frozen.items():
        assert sha(repo / relative) == digest
    build = ROOT / 'build';execution = ROOT / 'short_1'
    b = read(build / 'record.json');r = read(execution / 'record.json');report = read(execution / 'report.json')
    assert b['status'] == 'passed' and b['main_bridge_preserved'] and b['reference_restored']
    assert b['process_id'] != r['process_id'] == report['process_id']
    assert r['builder_process_id'] == b['process_id']
    assert r['workspace_unchanged_by_compile'] and report['bridge_compiled_sample_time'] == [0,0]
    assert report['explicit_generated_target_builds'] == 0 and not report['compiler_setup_performed']
    assert report['phase'] == 'execute_normal_parent_normal_child_once'
    assert not (execution / 'signals.mat').exists() and not (execution / 'restoration.mat').exists()
    assert not (ROOT / 'short_2').exists() and not (ROOT / 'cross_process_comparison.json').exists()
    assert sha(build / 'handoff.mat') == b['handoff_sha256']
    assert sha(Path(b['owned_parent_file'])) == b['exported_parent_sha256']
    assert sha(Path(b['reference_adapter']['child_file'])) == b['exported_child_sha256']
    for folder, record in ((build,b),(execution,r)):
        for entry in record['source_files']:
            assert sha(BASE / entry['path']) == entry['sha256'] == sha(folder / 'source' / entry['path'])
        for entry in record['contracts']:
            assert sha(BASE / entry['path']) == entry['sha256'] == sha(folder / entry['path'])
    dump = Path(os.environ['TEMP']) / f"matlab_crash_dump.{r['process_id']}-1"
    parser = runpy.run_path(str(Path(__file__).with_name('curate_sensorless_r2_crash_context.py')))
    crash = {'actual_pid': r['process_id'], 'exit_hex': '0xc0000005', 'dump_present': dump.exists()}
    if dump.exists():
        crash.update({'private_dump_sha256': sha(dump), 'private_dump_bytes': dump.stat().st_size,
                      'dump_minus_record_s': dump.stat().st_mtime-(execution/'record.json').stat().st_mtime,
                      'whitelisted_frames_only': parser['frames'](dump)})
    published = []
    for source, name in ((ROOT/'campaign.json','campaign.json'),(execution/'report.json','first_short_report.json'),
                         (execution/'graph.json','first_short_graph.json'),(build/'graph.json','build_graph.json')):
        target=DEST/name;shutil.copyfile(source,target);published.append({'path':name,'sha256':sha(target)})
    provenance = {'builder_record_sha256':sha(build/'record.json'),'first_short_record_sha256':sha(execution/'record.json'),
                  'handoff_sha256':b['handoff_sha256'],'saved_parent_sha256':b['exported_parent_sha256'],
                  'saved_child_sha256':b['exported_child_sha256'],'nominal_observer_config':b['observer_config'],
                  'nominal_frontend_config':b['config_vector'],'effective_case':b['effective_case'],
                  'source_manifest_sha256':sha(source_manifest),'saved_files_unchanged_after_native_exit':True}
    (DEST/'provenance.json').write_bytes((json.dumps(provenance,ensure_ascii=True,indent=2)+'\n').encode())
    (DEST/'native_crash.json').write_bytes((json.dumps(crash,ensure_ascii=True,indent=2)+'\n').encode())
    summary = {'captured_at':datetime.now().astimezone().isoformat(),'analysis_only':True,'simulation_reexecuted':False,
               'execution_version':campaign['execution_version'],'status':campaign['status'],'builder_passed':True,
               'preload86_exact_and_graph_backup_passed':True,'normal_compile_term_passed':True,
               'bridge_continuous_rate':[0,0],'explicit_generated_target_builds':0,'compiler_setup_performed':False,
               'sim_calls_requested':1,'physical_time_progress_known':False,'complete_raw_archive_exists':False,
               'executor_restoration_executed':False,'strict96_completed_shorts':0,'planned_shorts':2,
               'second_short_started':False,'cross_process_comparison_started':False,'new_formal_matrix_started':False,
               'old_formal_status_preserved':'1/14 stopped_execution_failure','native_root_cause_confirmed':False,
               'hardware_failure_confirmed':False,'R2_passed':False,'source_files_verified':len(frozen),'published':published}
    (DEST/'summary.json').write_bytes((json.dumps(summary,ensure_ascii=True,indent=2)+'\n').encode())
    print(json.dumps({key:summary[key] for key in ('status','builder_passed','strict96_completed_shorts','second_short_started','R2_passed')}))


if __name__ == '__main__':
    main()
