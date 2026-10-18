"""One native and one MATLAB exact runtime control, never a model case retry."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import os
import subprocess
import sys

BASE = Path(__file__).resolve().parents[2]
REPO = BASE.parent.parent
ROOT = BASE / 'runs/N3R2_runtime_oracle_once'
LAUNCH = ROOT / 'launch.json'


def read(path):
    return json.loads(path.read_text('utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verify_old():
    subprocess.run([sys.executable, str(BASE / 'robust/formal_r2/candidate.py'), 'verify'], check=True, cwd=REPO)


def main():
    assert ROOT.exists() and not LAUNCH.exists()
    oracle = read(ROOT / 'oracle.json')
    assert sha(ROOT / 'oracle.bin') == oracle['sha256']
    verify_old()
    manifest = {'kind': 'model_independent_exact_runtime_control', 'status': 'running',
                'started_at': datetime.now(timezone.utc).isoformat(), 'simulation_starts': 0,
                'native_retries': 0, 'R2_passed': False, 'jobs': []}

    def save():
        LAUNCH.write_bytes((json.dumps(manifest, indent=2) + '\n').encode('utf-8'))

    def run_job(name, command, env=None):
        entry = {'name': name, 'status': 'running', 'command': command,
                 'started_at': datetime.now(timezone.utc).isoformat(), 'exit_code': None}
        manifest['jobs'].append(entry)
        save()
        with (ROOT / (name + '_private_stdout.log')).open('wb') as out, (ROOT / (name + '_private_stderr.log')).open('wb') as err:
            process = subprocess.Popen(command, cwd=REPO, stdout=out, stderr=err, env=env,
                                       creationflags=subprocess.CREATE_NO_WINDOW)
            entry['launcher_pid'] = process.pid
            save()
            code = process.wait(timeout=240)
        entry['exit_code'] = code
        entry['status'] = 'exited'
        save()
        assert code == 0, f'{name} failed with exit {code}; no retry.'

    save()
    try:
        dependency = read(BASE / 'milestones/N3R2/isolated_compiler_20261018.json')
        gcc = Path(dependency['compiler_root']) / 'bin/gcc.exe'
        assert sha(gcc) == dependency['gcc_sha256']
        source = Path(__file__).with_name('sensorless_r2_runtime_control.c')
        copied_source = ROOT / source.name
        copied_source.write_bytes(source.read_bytes())
        manifest['native_source_sha256'] = sha(source)
        executable = ROOT / 'runtime_control.exe'
        run_job('compile', [str(gcc), '-std=c11', '-O2', '-Wall', '-Wextra', str(copied_source), '-o', str(executable)])
        manifest['native_executable_sha256'] = sha(executable)
        run_job('native', [str(executable), str(ROOT), oracle['fnv1a32_hex']])
        result = read(ROOT / 'native_result.json')
        assert result['all_passed'] and result['cycles'] >= 4 and result['elapsed_ms'] >= 60000
        assert sha(ROOT / 'native_vector.bin') == oracle['sha256']
        manifest['native_full_sha256_equal'] = True
        pref = BASE / '.build/runtime_oracle_preferences'
        assert not pref.exists()
        pref.mkdir()
        environment = os.environ.copy()
        environment['MATLAB_PREFDIR'] = str(pref)
        script_path = Path(__file__).parent.as_posix()
        command = f"assert(strcmpi(char(java.io.File(prefdir).getCanonicalPath),char(java.io.File('{pref.as_posix()}').getCanonicalPath)));addpath('{script_path}');probe_sensorless_r2_runtime_oracle('{ROOT.as_posix()}');"
        run_job('matlab', ['D:/DevTools/MATLAB/R2026a/bin/matlab.exe', '-singleCompThread', '-batch', command], environment)
        result = read(ROOT / 'matlab_result.json')
        assert result['all_passed'] and result['cycles'] >= 4 and result['elapsed_s'] >= 60
        assert sha(ROOT / 'matlab_vector.bin') == oracle['sha256']
        manifest['matlab_full_sha256_equal'] = True
        manifest['status'] = 'completed_passed'
        save()
    except Exception as error:
        manifest['status'] = 'stopped_failure'
        manifest['failure'] = str(error)
        save()
        raise
    finally:
        verify_old()
    print(json.dumps({'status': manifest['status'], 'simulation_starts': 0, 'R2_passed': False}))


if __name__ == '__main__':
    main()
