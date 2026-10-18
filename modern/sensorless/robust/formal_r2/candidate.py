"""Freeze and verify the single formal R2 candidate; never rerun simulations."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import subprocess

BASE = Path(__file__).resolve().parents[2]
REPO = BASE.parent.parent
CANDIDATE = BASE / 'milestones/N3R2/final_candidate.json'
VERSION = 'normal_model_reference_adapter'
PLAN_SHA = '6cedde9bcf37926542541d286d6d4167d2c596969998c5a20893a5063d60c439'


def read(path):
    return json.loads(path.read_text('utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def write_new(path, value):
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def runtime_map(record):
    entries = record['source_files'] + record['contracts']
    return {(BASE / item['path']).resolve().relative_to(REPO).as_posix(): item['sha256']
            for item in entries}


def prior_pass(case_id):
    results = []
    for path in (BASE / 'runs').glob('N3R2_*/campaign.json'):
        campaign = read(path)
        if campaign.get('execution_version') != VERSION or campaign['status'] != 'completed_passed':
            continue
        if campaign.get('campaign_type') == 'formal_frozen_candidate_matrix':
            continue
        for job in campaign['jobs']:
            if job['case_id'] != case_id or not job.get('completed_folder'):
                continue
            folder = Path(job['completed_folder'])
            record = read(folder / 'record.json')
            assert record['status'] == 'passed' and record['reference_restored']
            assert record['layer_restored'] and record['callback_restored'] and record['native_endpoint_verified']
            assert read(folder / 'metrics.json')['all_passed']
            assert read(folder / 'log_format_recovery.json')['all_passed']
            assert sha(folder / 'signals.mat') == record['raw_sha256']
            for relative, digest in runtime_map(record).items():
                assert sha(REPO / relative) == digest, f'Source changed: {relative}'
            results.append((folder, record))
    assert len(results) == 1, f'Exactly one completed {case_id} development prerequisite required; found {len(results)}'
    return results[0]


def verify(candidate=None):
    candidate = candidate or read(CANDIDATE)
    assert candidate['execution_version'] == VERSION
    assert sha(BASE / 'contracts/nonideal_r2_test_plan.json') == PLAN_SHA
    for item in candidate['files']:
        assert sha(REPO / item['path']) == item['sha256'], f"Frozen file changed: {item['path']}"
    return candidate


def prepare():
    for path in (BASE / 'runs').glob('N3R2_*/campaign.json'):
        campaign = read(path)
        assert campaign['status'] != 'running', f'Campaign active: {path.parent.name}'
        assert not (campaign.get('campaign_type') == 'formal_frozen_candidate_matrix'
                    and campaign.get('execution_version') == VERSION), 'Formal stage already started for this implementation.'
    short_folder, short = prior_pass('r1_short_logging_check')
    missing_folder, missing = prior_pass('missing_five')
    assert runtime_map(short) == runtime_map(missing), 'Development prerequisites use different runtime sources.'
    comparison = read(short_folder / 'log_format/v7_complete_log_comparison.json')
    assert comparison['all_passed'] and comparison['logs'] == 96 and comparison['all_Time_Data_equal']
    assert short['config_vector'] == missing['config_vector'] and short['observer_config'] == missing['observer_config']
    manifest = read(BASE / 'baseline/source_manifest.json')
    r1 = read(BASE / 'milestones/N3R1/frozen_candidate.json')
    for item in manifest['source_files']:
        assert sha(REPO / item['path']) == item['sha256'], f"Original source changed: {item['path']}"
    for item in r1['files']:
        assert sha(BASE / item['path']) == item['sha256'], f"R1 frozen source changed: {item['path']}"
    files = {item['path']: item['sha256'] for item in manifest['source_files']}
    for item in r1['files']:
        files[(BASE / item['path']).resolve().relative_to(REPO).as_posix()] = item['sha256']
    files.update(runtime_map(short))
    extras = [Path(__file__), BASE / 'run_sensorless_r2_final_matrix.ps1',
              BASE / 'run_sensorless_r2_reference.ps1', BASE / 'contracts/nonideal_r2_final_matrix.json',
              BASE / 'baseline/source_manifest.json', BASE / 'milestones/N3R1/frozen_candidate.json',
              BASE / 'verify_n0.py']
    extras.extend((BASE / 'contracts').glob('*.json'))
    for path in extras:
        files[path.relative_to(REPO).as_posix()] = sha(path)
    plan = read(BASE / 'contracts/nonideal_r2_test_plan.json')
    protocol = read(BASE / 'contracts/nonideal_r2_final_matrix.json')
    cases = {case['id']: case for case in plan['cases'] if case['kind'] != 'logging_validation'}
    assert set(cases) == set(protocol['order']) and len(cases) == 14
    git_head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPO, text=True).strip()
    candidate = {'schema': 1, 'stage': 'formal_frozen_candidate_matrix', 'execution_version': VERSION,
                 'frozen_at': datetime.now(timezone.utc).isoformat(), 'git_head': git_head,
                 'matlab_version': short['matlab_version'], 'matlab_executable': 'D:/DevTools/MATLAB/R2026a/bin/matlab.exe',
                 'command_flags': ['-singleCompThread', '-batch'], 'mode': 'normal_parent_and_child_reference',
                 'initialize_once': True, 'native_step_s': 62.5e-9,
                 'original_model_sha256': r1['model_sha256'], 'plan_sha256': PLAN_SHA,
                 'nominal_observer_config': short['observer_config'], 'nominal_frontend_config': short['config_vector'],
                 'interface': short['reference_adapter']['interface'], 'formal_starts_per_case': 1,
                 'formal_retries': 0, 'formal_case_order': protocol['order'], 'cases': cases,
                 'runtime_files': runtime_map(short),
                 'original_source_files': len(manifest['source_files']), 'r1_frozen_files': len(r1['files']),
                 'files': [{'path': path, 'sha256': digest} for path, digest in sorted(files.items())],
                 'prerequisites': {'short': short_folder.relative_to(BASE).as_posix(),
                                   'missing_five': missing_folder.relative_to(BASE).as_posix(),
                                   'short_record_sha256': sha(short_folder / 'record.json'),
                                   'missing_record_sha256': sha(missing_folder / 'record.json')},
                 'native_root_cause_confirmed': False, 'hardware_validated': False, 'feedback_takeover': False,
                 'R2_passed_at_freeze': False, 'R3_started_at_freeze': False}
    verify(candidate)
    return candidate


def freeze():
    assert not CANDIDATE.exists(), 'Candidate already frozen; overwrite forbidden.'
    candidate = prepare()
    write_new(CANDIDATE, candidate)
    return {'frozen': True, 'candidate_sha256': sha(CANDIDATE), 'files': len(candidate['files']), 'cases': 14}


def validate_record(folder, candidate):
    folder = folder.resolve()
    assert folder.is_relative_to(BASE / 'runs')
    record = read(folder / 'record.json')
    case_id = record['case_id']
    assert record['execution_version'] == VERSION and record['status'] == 'passed'
    assert record['effective_case'] == candidate['cases'][case_id]
    assert record['matlab_version'] == candidate['matlab_version']
    assert runtime_map(record) == candidate['runtime_files']
    assert record['model_sha256'] == candidate['original_model_sha256']
    for key in ('native_endpoint_verified', 'workspace_unchanged_by_compile', 'workspace_unchanged_by_simulation',
                'layer_restored', 'callback_restored', 'reference_restored', 'metrics_passed'):
        assert record[key], f'Failed execution/restoration field: {key}'
    expected = list(candidate['nominal_frontend_config'])
    expected[30] = candidate['cases'][case_id]['adc_span_A']
    assert record['config_vector'] == expected and record['observer_config'] == candidate['nominal_observer_config']
    child = record['reference_adapter']
    assert child['interface'] == candidate['interface'] and child['no_feedback_output']
    assert child['frontend_config'] == record['config_vector'] and child['observer_config'] == record['observer_config']
    assert sha(Path(child['child_file'])) == child['child_model_sha256']
    assert record['log_count'] == (97 if case_id == 'deadline_jitter' else 96)
    assert read(folder / 'graph.json')['passed'] and read(folder / 'direct_graph.json')['passed']
    metrics = read(folder / 'metrics.json')
    assert metrics['all_passed'] and metrics['false_valid_longest_s'] <= .002 + 1e-12
    assert sha(folder / 'signals.mat') == record['raw_sha256']
    formatting = read(folder / 'log_format_recovery.json')
    assert formatting['all_passed'] and not formatting['simulation_reexecuted']
    assert sha(folder / 'log_format/signals.mat') == formatting['canonical_sha256']
    if 'plant_R_multiplier' in candidate['cases'][case_id]:
        case = candidate['cases'][case_id]
        nominal = [candidate['nominal_observer_config'][0], candidate['nominal_observer_config'][1], candidate['nominal_observer_config'][1]]
        actual = [nominal[0] * case['plant_R_multiplier'], nominal[1] * case['plant_L_multiplier'], nominal[2] * case['plant_L_multiplier']]
        assert record['nominal_R_Ld_Lq'] == nominal and record['actual_plant_R_Ld_Lq'] == actual
        assert record['observer_nominal_preserved']
    return record, formatting


def preflight():
    candidate = prepare()
    plan = read(BASE / 'contracts/nonideal_r2_test_plan.json')
    candidate['cases'].update({case['id']: case for case in plan['cases'] if case['kind'] == 'logging_validation'})
    for key in ('short', 'missing_five'):
        validate_record(BASE / candidate['prerequisites'][key], candidate)
    return {'preflight_passed': True, 'simulation_reexecuted': False, 'existing_archives_checked': 2,
            'original_source_files': candidate['original_source_files'], 'r1_frozen_files': candidate['r1_frozen_files']}


def outcome(folder):
    candidate = verify()
    folder = folder.resolve()
    record, formatting = validate_record(folder, candidate)
    case_id = record['case_id']
    start_file = folder.parent / (case_id + '_formal_start.json')
    start = read(start_file)
    assert start['candidate_sha256'] == sha(CANDIDATE) and start['case_id'] == case_id
    assert datetime.fromisoformat(start['started_at']) >= datetime.fromisoformat(candidate['frozen_at'])
    result = {'all_passed': True, 'stage': 'formal_frozen_candidate_matrix', 'case_id': case_id,
              'candidate_sha256': sha(CANDIDATE), 'record_sha256': sha(folder / 'record.json'),
              'raw_sha256': record['raw_sha256'], 'canonical_sha256': formatting['canonical_sha256'],
              'original_record_unmodified': True, 'formal_retries': 0,
              'formal_start_sha256': sha(start_file),
              'validated_at': datetime.now(timezone.utc).isoformat()}
    write_new(folder / 'formal_provenance.json', result)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['freeze', 'verify', 'preflight', 'outcome'])
    parser.add_argument('folder', nargs='?', type=Path)
    args = parser.parse_args()
    if args.action == 'freeze':
        result = freeze()
    elif args.action == 'verify':
        verified = verify()
        result = {'verified': True, 'candidate_sha256': sha(CANDIDATE), 'files': len(verified['files'])}
    elif args.action == 'preflight':
        result = preflight()
    else:
        assert args.folder is not None
        result = outcome(args.folder)
    print(json.dumps(result, ensure_ascii=False))
