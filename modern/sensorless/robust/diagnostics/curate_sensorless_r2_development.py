"""Publish bounded R2 development evidence; keep failed and active jobs visible."""
from pathlib import Path
from datetime import datetime
import hashlib
import json
import shutil

BASE = Path(__file__).resolve().parents[2]
DEST = BASE / 'milestones/N3R2/development_20261017'
VERSIONS = {'basic_scenarios_v5', 'literal_binding_v6', 'fault_ingress_schedule_v7'}


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
            attempts.append({'folder': attempt_folder.name, 'case_id': record['case_id'], 'status': record['status'],
                             'phase': record['phase'], 'raw_sha256': record.get('raw_sha256'),
                             'metrics_passed': record.get('metrics_passed', False)})
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
    ]
    for name, files in probes:
        for file in files:
            source = BASE / 'runs' / name / file
            if source.exists():
                publish(source, name + '/' + file)
    summary = {
        'node': 'N3R2', 'all_passed': False, 'formal_final_matrix_passed': False,
        'captured_at': datetime.now().astimezone().isoformat(),
        'scope': 'Development progress only. Running/failed attempts retain their original statuses; probes do not establish long-case performance.',
        'r1_frozen_files_preserved': len(frozen['files']), 'model_sha256': frozen['model_sha256'],
        'previous_five_static_evidence': '../followup_20261017/summary.json',
        'dynamic_raw_metrics_passed': True, 'dynamic_original_execution_failed_postprocessor': True,
        'dynamic_original_restoration_executed': False,
        'dynamic_independent_restoration_probe_passed': True,
        'native_root_cause_confirmed': False, 'hardware_validated': False, 'feedback_takeover': False,
        'R3_independent_full_replay_done': False, 'campaigns': campaigns, 'published': published,
    }
    (DEST / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'integrity_passed': True, 'campaigns': len(campaigns), 'files': len(published),
                      'R2_all_passed': False, 'active': [c['folder'] for c in campaigns if c['status'] == 'running']}))


if __name__ == '__main__':
    main()
