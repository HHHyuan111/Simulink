"""Publish bounded R2 development evidence; keep failed and active jobs visible."""
from pathlib import Path
from datetime import datetime
import hashlib
import json
import shutil

BASE = Path(__file__).resolve().parents[2]
DEST = BASE / 'milestones/N3R2/development_20261017'
VERSIONS = {'basic_scenarios_v5', 'literal_binding_v6', 'fault_ingress_schedule_v7',
            'single_initialization_v8', 'single_init_short_cache_v8r1',
            'block_reduction_off_v9', 'geometry_bound_constructor'}


def read(path):
    return json.loads(path.read_text('utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    frozen = read(BASE / 'milestones/N3R1/frozen_candidate.json')
    for entry in frozen['files']:
        assert sha(BASE / entry['path']) == entry['sha256']
    assert sha(BASE.parent / 'PMSM_FOC_R2026a.slx') == frozen['model_sha256']
    assert sha(BASE / 'contracts/nonideal_r2_test_plan.json') == '6cedde9bcf37926542541d286d6d4167d2c596969998c5a20893a5063d60c439'
    published = []

    def publish(source, name):
        target = DEST / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        published.append({'source': source.relative_to(BASE).as_posix(), 'published': name, 'sha256': sha(target)})

    campaigns = []
    prior = read(BASE / 'milestones/N3R2/followup_20261017/summary.json')
    passed = {item['case_id'] for item in prior['case_metrics']
              if item['version'] == 'packet_phase_guard_v4' and item['status'] == 'passed'
              and item['case_id'] != 'r1_short_logging_check'}
    for folder in sorted((BASE / 'runs').glob('N3R2_*')):
        manifest_path = folder / 'campaign.json'
        if not manifest_path.exists():
            continue
        manifest = read(manifest_path)
        if manifest.get('execution_version') not in VERSIONS:
            continue
        prefix = folder.name
        publish(manifest_path, prefix + '/campaign.json')
        attempts = []
        for attempt_folder in sorted(folder.glob('*_attempt_*')):
            if not attempt_folder.is_dir() or not (attempt_folder / 'record.json').exists():
                continue
            record = read(attempt_folder / 'record.json')
            finalized = [attempt for job in manifest['jobs'] for attempt in job['attempts']
                         if Path(attempt['folder']).name == attempt_folder.name]
            for entry in record['source_files']:
                assert sha(attempt_folder / 'source' / entry['path']) == entry['sha256']
            for entry in record['contracts']:
                assert sha(attempt_folder / entry['path']) == entry['sha256']
            if record.get('raw_sha256'):
                assert sha(attempt_folder / 'signals.mat') == record['raw_sha256']
            name = prefix + '/' + attempt_folder.name
            for file in ('record.json', 'metrics.json', 'graph.json', 'logging_validation.json'):
                if (attempt_folder / file).exists():
                    publish(attempt_folder / file, name + '/' + file)
            for file in ('execution_progress.json', 'v7_complete_log_comparison.json'):
                if (attempt_folder / file).exists():
                    publish(attempt_folder / file, name + '/' + file)
            format_report = attempt_folder / 'log_format_recovery.json'
            if format_report.exists():
                normalization = read(format_report)
                assert sha(attempt_folder / 'log_format/signals.mat') == normalization['canonical_sha256']
                assert sha(attempt_folder / 'log_format/normalizer_source.m.txt') == normalization['adapter_sha256']
                assert sha(attempt_folder / 'log_format/format_contract.json') == normalization['contract_sha256']
                publish(format_report, name + '/log_format_recovery.json')
                for file in ('logging_validation.json', 'v7_complete_log_comparison.json', 'format_contract.json'):
                    if (attempt_folder / 'log_format' / file).exists():
                        publish(attempt_folder / 'log_format' / file, name + '/log_format/' + file)
            if (attempt_folder / 'bounded_log_diagnosis.json').exists():
                publish(attempt_folder / 'bounded_log_diagnosis.json', name + '/bounded_log_diagnosis.json')
            low_review = attempt_folder / 'review/low_speed_diagnosis.json'
            if low_review.exists():
                review = read(low_review)
                assert review['analysis_only'] and review['raw_source_sha256'] == record['raw_sha256']
                assert sha(attempt_folder / 'review/low_speed_diagnosis.png') == review['figure_sha256']
                assert sha(BASE / 'robust/diagnostics/render_sensorless_r2_low_speed.py') == review['renderer_sha256']
                publish(low_review, name + '/review/low_speed_diagnosis.json')
                publish(attempt_folder / 'review/low_speed_diagnosis.png', name + '/review/low_speed_diagnosis.png')
            metrics_path = attempt_folder / 'metrics.json'
            if record['status'] == 'passed' and record['case_id'] != 'r1_short_logging_check':
                assert metrics_path.exists() and read(metrics_path)['all_passed']
                passed.add(record['case_id'])
            attempts.append({'folder': attempt_folder.name, 'case_id': record['case_id'], 'status': record['status'],
                             'phase': record['phase'], 'raw_sha256': record.get('raw_sha256'),
                             'metrics_passed': record.get('metrics_passed', False),
                             'record_status_is_last_persisted_not_process_liveness': True,
                             'execution_finalized': bool(finalized),
                             'exit_code': finalized[0]['exit_code'] if finalized else None,
                             'exit_code_hex': f"0x{finalized[0]['exit_code'] & 0xffffffff:08x}" if finalized else None,
                             'allowed_native_retry_classification': finalized[0]['native_failure'] if finalized else None})
        campaigns.append({'folder': prefix, 'version': manifest['execution_version'], 'status': manifest['status'],
                          'attempts': attempts})
    probes = [
        ('N3R2_dynamic_archive_reanalysis_once', ('report.json', 'metrics.json')),
        ('N3R2_dynamic_restoration_probe_once', ('report.json',)),
        ('N3R2_literal_binding_compile_probe_once', ('report.json',)),
        ('N3R2_fault_cores_once', ('report.json',)),
        ('N3R2_fault_graph_probe_once', ('record.json',)),
        ('N3R2_fault_graph_tag_fix_probe_once', ('record.json', 'nominal_comparison.json')),
        ('N3R2_fault_timing_graph_probe_once', ('record.json', 'short_negative_control.json')),
        ('N3R2_pwm_restoration_diagnosis_once', ('report.json',)),
        ('N3R2_fault_timing_restoration_fixed_compile_once', ('record.json',)),
        ('N3R2_single_initialization_toy_parse_fixed_once', ('report.json', 'execution_progress.json')),
        ('N3R2_single_initialization_toy_endpoint_fixed_once', ('report.json', 'execution_progress.json')),
    ]
    for name, files in probes:
        probe_folder = BASE / 'runs' / name
        probe_record_path = probe_folder / 'record.json'
        if probe_record_path.exists():
            probe_record = read(probe_record_path)
            for entry in probe_record.get('source_files', []):
                assert sha(probe_folder / 'source' / entry['path']) == entry['sha256']
            if probe_record.get('raw_sha256') and (probe_folder / 'signals.mat').exists():
                assert sha(probe_folder / 'signals.mat') == probe_record['raw_sha256']
        for file in files:
            source = BASE / 'runs' / name / file
            if source.exists():
                publish(source, name + '/' + file)
    dynamic = read(BASE / 'runs/N3R2_dynamic_archive_reanalysis_once/report.json')
    restoration = read(BASE / 'runs/N3R2_dynamic_restoration_probe_once/report.json')
    case_ids = [case['id'] for case in read(BASE / 'contracts/nonideal_r2_test_plan.json')['cases']
                if case['kind'] != 'logging_validation']
    summary = {
        'node': 'N3R2', 'all_passed': False, 'formal_final_matrix_passed': False,
        'captured_at': datetime.now().astimezone().isoformat(),
        'scope': 'Development progress only. Running/failed attempts retain their original statuses; probes do not establish long-case performance.',
        'r1_frozen_files_preserved': len(frozen['files']), 'model_sha256': frozen['model_sha256'],
        'previous_five_static_evidence': '../followup_20261017/summary.json',
        'dynamic_raw_metrics_passed': dynamic['metrics_passed'],
        'dynamic_original_execution_failed_postprocessor': dynamic['original_status'] == 'failed_execution',
        'dynamic_original_restoration_executed': dynamic['original_restoration_executed'],
        'dynamic_independent_restoration_probe_passed': restoration['all_passed'],
        'development_end_to_end_passed_case_ids': sorted(passed),
        'development_not_end_to_end_passed_case_ids': [case for case in case_ids if case not in passed],
        'native_root_cause_confirmed': False, 'hardware_validated': False, 'feedback_takeover': False,
        'R3_independent_full_replay_done': False, 'campaigns': campaigns, 'published': published,
    }
    (DEST / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'integrity_passed': True, 'campaigns': len(campaigns), 'files': len(published),
                      'R2_all_passed': False, 'active': [c['folder'] for c in campaigns if c['status'] == 'running']}))


if __name__ == '__main__':
    main()
