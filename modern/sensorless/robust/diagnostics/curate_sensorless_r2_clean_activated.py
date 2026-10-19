"""Publish safe installation/control evidence; never install or replay a model."""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import runpy
import re
import xml.etree.ElementTree as ET

BASE = Path(__file__).resolve().parents[2]
REPO = BASE.parent.parent
SETUP = BASE / '.build/matlab_clean'
RUN = BASE / 'runs/N3R2_clean_install_activated_control_once'
DEST = BASE / 'milestones/N3R2/clean_activated_20261019'


def read(path):
    return json.loads(path.read_text('utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def publish(name, value):
    (DEST / name).write_bytes((json.dumps(value, ensure_ascii=True, indent=2) + '\n').encode())


def main():
    sources = read(DEST / 'pre_execution_sources.json')
    for entry in sources['files']:
        assert sha(BASE / entry['path']) == entry['sha256'], entry['path']
    frozen = BASE / 'milestones/N3R2/normal_serialized_20261018/prequalification_sources.json'
    assert sha(frozen) == sources['original862_manifest_sha256']
    binding = read(frozen)
    for entry in binding['files']:
        assert sha(REPO / entry['path']) == entry['sha256'], entry['path']
    protocol = read(BASE / 'contracts/nonideal_r2_clean_install_control.json')
    artifacts = protocol['artifacts']
    for path, digest in ((Path(artifacts['parent_file']), artifacts['parent_sha256']),
                         (Path(artifacts['child_file']), artifacts['child_sha256']),
                         (Path(artifacts['build_folder']) / 'handoff.mat', artifacts['handoff_sha256'])):
        assert sha(path) == digest
    installation = read(SETUP / 'installation_status.json')
    publish('installation_status.json', installation)
    version = ET.parse(SETUP / 'R2026a_U5/VersionInfo.xml').getroot()
    version_metadata = {key: version.findtext(key) for key in ('version','release','description')}
    publish('version_metadata.json', version_metadata)
    launches = [read(path) for path in sorted(SETUP.glob('elevation_request*.json'))]
    publish('installer_launches.json', launches)
    summary = {'captured_at': datetime.now(timezone.utc).isoformat(), 'analysis_only': True,
               'simulation_reexecuted': False, 'R2_passed': False, 'old_formal_status': '1/14 stopped',
               'installation_status': installation['status'], 'source_files_verified': len(binding['files']),
               'diagnostic_files_verified': len(sources['files']), 'saved_models_handoff_unchanged': True,
               'runtime_preflight_passed': False, 'simulation_job_launched': False,
               'runtime_preflight_script_started': False, 'licensing_blocked': False,
               'sim_calls_requested': 0, 'complete_raw_archive_exists': False,
               'native_endpoint_verified': False, 'executor_restoration_verified': False,
               'strict96_passed': False, 'new_formal_matrix_started': False,
               'native_root_cause_confirmed': False, 'hardware_causality_confirmed': False,
               'curator_sha256': sha(Path(__file__))}
    if (RUN / 'campaign.json').exists():
        campaign = read(RUN / 'campaign.json')
        publish('campaign.json', campaign)
        summary.update(diagnostic_status=campaign['status'],
                       simulation_job_launched=campaign['simulation_job_launched'])
        observations = []
        for path in sorted(RUN.glob('runtime_preflight_private_*.log')):
            raw = path.read_bytes()
            text = '\n'.join(raw.decode(codec, errors='replace') for codec in ('utf-8','gb18030'))
            missing = bool(re.search(r'Unable to find a license', text, re.I))
            observations.append({'name': path.name, 'private_bytes': len(raw), 'private_sha256': sha(path),
                                 'unable_to_find_license_message_present': missing})
            summary['licensing_blocked'] |= missing
        publish('startup_observation.json', {'raw_logs_published': False, 'logs': observations})
        if (RUN / 'binary_comparison.json').exists():
            binaries = read(RUN / 'binary_comparison.json')
            publish('binary_comparison.json', binaries)
            summary['core_binaries_compared'] = len(binaries)
            summary['equal_core_binaries'] = sum(row['bytes_equal'] for row in binaries)
        if (RUN / 'runtime_preflight/report.json').exists():
            preflight = read(RUN / 'runtime_preflight/report.json')
            publish('runtime_preflight.json', preflight)
            summary['runtime_preflight_script_started'] = True
            summary['runtime_preflight_passed'] = preflight['all_passed']
        folder = RUN / 'short_once'
        if (folder / 'report.json').exists():
            report = read(folder / 'report.json')
            publish('short_report.json', report)
            summary['sim_calls_requested'] = report['simulation_starts']
            summary['last_durable_phase'] = report['phase']
            summary['complete_raw_archive_exists'] = (folder / 'signals.mat').exists()
            if (folder / 'record.json').exists():
                record = read(folder / 'record.json')
                summary['native_endpoint_verified'] = record['native_endpoint_verified']
                summary['executor_restoration_verified'] = record['reference_restored'] and record['main_bridge_preserved']
                summary['raw_sha256'] = sha(folder / 'signals.mat') if (folder / 'signals.mat').exists() else None
            comparison = folder / 'log_format/v7_complete_log_comparison.json'
            if comparison.exists():
                result = read(comparison)
                publish('strict96_comparison.json', result)
                summary['strict96_passed'] = result['all_passed'] and result['logs'] == 96
            logging = folder / 'log_format/logging_validation.json'
            if logging.exists():
                result = read(logging)
                publish('original81_comparison.json', result)
                summary['original81_and52_passed'] = result['all_passed'] and result['original52_included']
            if (folder / 'metrics.json').exists():
                publish('short_metrics.json', read(folder / 'metrics.json'))
            dump = Path(os.environ['TEMP']) / f"matlab_crash_dump.{report['process_id']}-1"
            if dump.exists():
                parser = runpy.run_path(str(Path(__file__).with_name('curate_sensorless_r2_crash_context.py')))
                publish('native_crash.json', {'actual_pid': report['process_id'],
                        'private_dump_bytes': dump.stat().st_size, 'private_dump_sha256': sha(dump),
                        'whitelisted_frames_only': parser['frames'](dump)})
    publish('summary.json', summary)
    print(json.dumps({key: summary[key] for key in ('installation_status', 'runtime_preflight_passed',
          'simulation_job_launched', 'strict96_passed', 'R2_passed')}))


if __name__ == '__main__':
    main()
