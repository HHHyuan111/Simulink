"""Verify and publish standalone feasibility evidence; never run a simulation."""
from pathlib import Path
import hashlib
import json
import shutil

BASE = Path(__file__).resolve().parents[2]
DEST = BASE / 'milestones/N3R2/execution_feasibility_20261018'


def read(path):
    return json.loads(path.read_text('utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    result = {'analysis_only': True, 'simulation_reexecuted': False, 'R2_passed': False,
              'scope': 'Small execution fixture only; no motor or observer physical rerun.', 'runs': []}
    for name, launch_name in [('N3R2_rapid_toy_once', 'N3R2_rapid_toy_launch.json'),
                              ('N3R2_rapid_toy_compiler_once', 'N3R2_rapid_toy_compiler_launch.json'),
                              ('N3R2_rapid_process_once', 'N3R2_rapid_process_launch.json')]:
        folder = BASE / 'runs' / name
        launch_path = BASE / 'runs' / launch_name
        launch = read(launch_path)
        assert launch['status'] == 'exited', 'Do not publish an incomplete process as final evidence.'
        report = read(folder / 'report.json')
        assert sha(folder / 'probe_source.m.txt') == report['probe_sha256']
        probe = 'probe_sensorless_r2_rapid_process.m' if name == 'N3R2_rapid_process_once' else 'probe_sensorless_r2_rapid_toy.m'
        assert sha(BASE / 'robust/diagnostics' / probe) == report['probe_sha256']
        assert sha(folder / 'contract.json') == report['contract_sha256']
        assert report['native_retries'] == 0 and not report['plant_reexecuted']
        if report.get('raw_sha256'):
            assert sha(folder / 'signals.mat') == report['raw_sha256']
        if report.get('fixture_sha256'):
            model = 'sl_r2_rapid_pid.slx' if name == 'N3R2_rapid_process_once' else 'sl_r2_rapid_toy.slx'
            assert sha(folder / model) == report['fixture_sha256']
        targets = report.get('generated_model_targets', report.get('generated_executables', []))
        if isinstance(targets, dict):
            targets = [targets]
        for executable in targets:
            assert sha(Path(executable['path'])) == executable['sha256']
        for filename, field in [('normal.mat', 'normal_raw_sha256'), ('rapid.mat', 'rapid_raw_sha256'),
                                ('target_makefile.mk.txt', 'makefile_sha256')]:
            if field in report:
                assert sha(folder / filename) == report[field]
        if report['all_passed']:
            assert launch['exit_code'] == 0 and launch['default_compiler_preferences_unchanged']
            assert report['normal_starts'] == 1 and report['rapid_starts'] == 1
            assert all(report['normal_checks'].values()) and all(report['rapid_checks'].values())
            assert all(all(item.values()) for item in report['comparison'].values())
            assert targets and report['normal_pid_matches_worker'] and report['rapid_pid_is_distinct']
            assert report['normal_pid'] == report['process_id'] != report['rapid_pid']
            assert report['pid_Time_equal'] and report['pid_class_equal']
        target = DEST / name
        target.mkdir(exist_ok=True)
        for source, filename in [(folder / 'report.json', 'report.json'), (launch_path, 'launch.json')]:
            shutil.copyfile(source, target / filename)
        result['runs'].append({'folder': name, 'exit_code': launch['exit_code'],
                               'phase': report['phase'], 'all_passed': report['all_passed'],
                               'normal_starts': report['normal_starts'], 'rapid_starts': report['rapid_starts'],
                               'report_sha256': sha(folder / 'report.json'), 'launch_sha256': sha(launch_path)})
    result['all_passed'] = result['runs'][-1]['all_passed']
    result['preflight_preserved'] = result['runs'][0]['phase'] == 'diagnostic_error'
    result['uninstrumented_fixture_remains_failed'] = not result['runs'][1]['all_passed']
    result['preflight_exit_clarification'] = 'The original MATLAB child exited1; its first PowerShell launcher returned0 after recording the child exit. Child outcome is not a passing fixture.'
    (DEST / 'summary.json').write_bytes((json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
