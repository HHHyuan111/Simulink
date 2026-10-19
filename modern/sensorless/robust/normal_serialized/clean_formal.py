"""Freeze and validate the new clean-runtime formal matrix; never simulate."""
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import runpy
import sys

BASE = Path(__file__).resolve().parents[2]
REPO = BASE.parent.parent
QUAL = BASE / 'runs/N3R2_clean_normal_qualification_once'
ROOT = BASE / 'runs/N3R2_clean_normal_formal_once'
FROZEN = BASE / 'milestones/N3R2/clean_formal_20261019/frozen_candidate.json'
VERSION = 'normal_serialized_parent_and_observer'
PLAN_SHA = '6cedde9bcf37926542541d286d6d4167d2c596969998c5a20893a5063d60c439'


def read(p):
    return json.loads(p.read_text('utf-8-sig'))


def sha(p):
    with p.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def write_new(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open('x', encoding='utf8', newline='\n') as stream:
        json.dump(value, stream, indent=2)
        stream.write('\n')


def legacy_validator():
    path = BASE / 'robust/formal_r2/candidate.py'
    spec = importlib.util.spec_from_file_location('frozen_r2_record_validation', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    # Compatibility binding only: preserve the frozen function and its checks.
    module.VERSION = VERSION
    return module


def verify():
    c = read(FROZEN)
    assert sha(BASE / 'contracts/nonideal_r2_test_plan.json') == PLAN_SHA
    for entry in c['files']:
        assert sha(REPO / entry['path']) == entry['sha256'], entry['path']
    for entry in c['environment_files']:
        assert sha(Path(entry['path'])) == entry['sha256'], entry['path']
    for entry in c['prerequisite_files']:
        assert sha(REPO / entry['path']) == entry['sha256'], entry['path']
    return c


def freeze():
    assert not FROZEN.exists() and not ROOT.exists()
    guard = runpy.run_path(str(BASE / 'robust/normal_serialized/clean_qualification.py'))
    guard['verify']()
    assert read(QUAL / 'campaign.json')['status'] == 'completed_passed'
    cross = read(QUAL / 'cross_process_comparison.json')
    assert cross['all_passed'] and cross['logs'] == 96 and cross['all_Time_Data_class_dimensions_equal']
    a = read(QUAL / 'short_1/record.json');b = read(QUAL / 'short_2/record.json')
    validator = legacy_validator()
    assert a['process_id'] != b['process_id'] and validator.runtime_map(a) == validator.runtime_map(b)
    assert a['status'] == b['status'] == 'passed'
    assert a['observer_config'] == b['observer_config'] and a['config_vector'] == b['config_vector']
    assert all(read(QUAL / stage / 'log_format/v7_complete_log_comparison.json')['all_passed']
               and read(QUAL / stage / 'log_format/logging_validation.json')['all_passed'] for stage in ('short_1','short_2'))
    qualified = read(BASE / 'milestones/N3R2/clean_qualification_20261019/qualification_sources.json')
    files = {e['path']: e['sha256'] for e in qualified['files']}
    extras = list((BASE / 'contracts').glob('*.json')) + [Path(__file__),
        BASE / 'robust/diagnostics/run_sensorless_r2_clean_normal_formal.ps1',
        BASE / 'milestones/N3R2/clean_qualification_20261019/qualification_sources.json']
    for p in extras:
        files[p.relative_to(REPO).as_posix()] = sha(p)
    protocol = read(BASE / 'contracts/nonideal_r2_clean_normal_formal_matrix.json')
    cases = {c['id']: c for c in read(BASE / 'contracts/nonideal_r2_test_plan.json')['cases'] if c['kind'] != 'logging_validation'}
    assert len(cases) == 14 and set(cases) == set(protocol['order'])
    prerequisites = [QUAL / 'campaign.json', QUAL / 'cross_process_comparison.json']
    for stage in ('short_1','short_2'):
        prerequisites.extend(QUAL / stage / rel for rel in ('record.json','report.json','log_format/v7_complete_log_comparison.json','log_format/logging_validation.json'))
        folder = QUAL / stage;record = read(folder / 'record.json')
        formatting = read(folder / 'log_format_recovery.json')
        assert sha(folder / 'signals.mat') == record['raw_sha256']
        assert formatting['all_passed'] and not formatting['simulation_reexecuted']
        assert sha(folder / 'log_format/signals.mat') == formatting['canonical_sha256']
        prerequisites.extend(folder / rel for rel in ('signals.mat','log_format/signals.mat','log_format_recovery.json'))
    c = {'schema': 1, 'frozen_at': datetime.now(timezone.utc).isoformat(),
         'stage': 'formal_frozen_candidate_matrix_clean_runtime', 'execution_version': VERSION,
         'environment': 'new_official_activated_installation', 'matlab_version': a['matlab_version'],
         'matlab_executable': 'D:/simulink/dev/modern/sensorless/.build/matlab_clean/R2026a_U5/bin/matlab.exe',
         'formal_case_order': protocol['order'], 'cases': cases, 'formal_retries': 0,
         'original_model_sha256': a['model_sha256'], 'plan_sha256': PLAN_SHA,
         'nominal_observer_config': a['observer_config'], 'nominal_frontend_config': a['config_vector'],
         'interface': a['reference_adapter']['interface'], 'runtime_files': validator.runtime_map(a),
         'files': [{'path': k, 'sha256': v} for k,v in sorted(files.items())],
         'environment_files': qualified['environment_files'],
         'prerequisite_files': [{'path': p.relative_to(REPO).as_posix(), 'sha256': sha(p)} for p in prerequisites],
         'R2_passed_at_freeze': False, 'native_root_cause_confirmed': False,
         'hardware_validated': False, 'feedback_takeover': False, 'R3_started': False}
    write_new(FROZEN, c)
    verify()
    return {'frozen': True, 'files': len(c['files']), 'cases': 14, 'candidate_sha256': sha(FROZEN)}


def outcome(folder):
    c = verify();folder = folder.resolve()
    assert folder.is_relative_to(ROOT)
    record, formatting = legacy_validator().validate_record(folder, c)
    builder = read(folder.parent / 'build/record.json')
    assert builder['status'] == 'passed' and builder['simulation_starts'] == 0
    assert builder['reference_restored'] and builder['main_bridge_preserved']
    assert record['builder_process_id'] == builder['process_id'] != record['process_id']
    assert record['workspace_unchanged_by_simulation'] and record['saved_exports_unchanged']
    assert record['execution']['single_sim_call'] and record['execution']['mode'] == record['execution']['child_mode'] == 'normal'
    assert record['execution_boundary'] == {'parent':'Normal','child':'Normal','allowed_instances':'Single','actual_instances':1}
    report = read(folder / 'report.json')
    assert report['all_passed'] and report['bridge_compiled_sample_time'] == [0,0]
    assert report['simulation_starts'] == 1 and report['explicit_generated_target_builds'] == 0 and not report['compiler_setup_performed']
    start = folder.parent / 'formal_start.json';s = read(start)
    assert s['candidate_sha256'] == sha(FROZEN) and s['case_id'] == record['case_id']
    assert datetime.fromisoformat(s['started_at']) >= datetime.fromisoformat(c['frozen_at'])
    result = {'all_passed': True, 'case_id': record['case_id'], 'candidate_sha256': sha(FROZEN),
              'record_sha256': sha(folder / 'record.json'), 'builder_record_sha256': sha(folder.parent / 'build/record.json'),
              'raw_sha256': record['raw_sha256'], 'canonical_sha256': formatting['canonical_sha256'],
              'formal_start_sha256': sha(start), 'formal_retries': 0, 'original_record_unmodified': True,
              'validated_at': datetime.now(timezone.utc).isoformat()}
    write_new(folder / 'formal_provenance.json', result)
    return result


if __name__ == '__main__':
    assert len(sys.argv) >= 2 and sys.argv[1] in ('freeze','verify','outcome')
    if sys.argv[1] == 'freeze': result = freeze()
    elif sys.argv[1] == 'verify':
        c = verify();result = {'verified': True, 'files': len(c['files']), 'candidate_sha256': sha(FROZEN)}
    else: result = outcome(Path(sys.argv[2]))
    print(json.dumps(result))
