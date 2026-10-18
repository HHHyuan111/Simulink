"""Prospectively authorized first MATLAB control; retain parent failure untouched."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import os
import subprocess
import sys

BASE = Path(__file__).resolve().parents[2]
ROOT = BASE / 'runs/N3R2_runtime_oracle_once'
path = ROOT / 'matlab_first_launch.json'
assert not path.exists() and not (ROOT / 'matlab_result.json').exists()
read = lambda p: json.loads(p.read_text('utf-8-sig'))


def sha(p):
    with p.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


oracle = read(ROOT / 'oracle.json')
original = read(ROOT / 'launch.json')
assert original['status'] == 'stopped_failure' and [j['name'] for j in original['jobs']] == ['compile', 'native']
assert sha(ROOT / 'oracle.bin') == sha(ROOT / 'native_vector.bin') == oracle['sha256']
original_sha = sha(ROOT / 'launch.json')
print(json.dumps({'native_full_bytes_verified': True, 'native_duration_still_incomplete': True, 'sha256': oracle['sha256']}), flush=True)
candidate = BASE / 'robust/formal_r2/candidate.py'
subprocess.run([sys.executable, str(candidate), 'verify'], check=True)
pref = BASE / '.build/runtime_matlab_first_preferences'
assert not pref.exists()
pref.mkdir()
environment = os.environ.copy()
environment['MATLAB_PREFDIR'] = str(pref)
scripts = Path(__file__).parent.as_posix()
expression = f"assert(strcmpi(char(java.io.File(prefdir).getCanonicalPath),char(java.io.File('{pref.as_posix()}').getCanonicalPath)));addpath('{scripts}');probe_sensorless_r2_runtime_oracle('{ROOT.as_posix()}');"
job = {'kind': 'independent_first_matlab_runtime_control', 'status': 'running',
       'started_at': datetime.now(timezone.utc).isoformat(), 'exit_code': None,
       'parent_launch_sha256': original_sha, 'native_vector_sha256': sha(ROOT / 'native_vector.bin'),
       'oracle_sha256': oracle['sha256'], 'simulation_starts': 0, 'native_retries': 0,
       'parent_protocol_incomplete': True, 'R2_passed': False}


def save():
    path.write_bytes((json.dumps(job, indent=2) + '\n').encode('utf-8'))


save()
try:
    with (ROOT / 'matlab_first_private_stdout.log').open('wb') as out, (ROOT / 'matlab_first_private_stderr.log').open('wb') as err:
        process = subprocess.Popen(['D:/DevTools/MATLAB/R2026a/bin/matlab.exe', '-singleCompThread', '-batch', expression],
                                   cwd=BASE.parent.parent, stdout=out, stderr=err, env=environment,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
        job['launcher_pid'] = process.pid
        save()
        code = process.wait(timeout=240)
    job['exit_code'] = code
    job['status'] = 'exited'
    save()
    assert code == 0, f'MATLAB control exited {code}; no retry.'
    report = read(ROOT / 'matlab_result.json')
    assert report['all_passed'] and report['cycles'] >= 4 and report['elapsed_s'] >= 60
    assert sha(ROOT / 'matlab_vector.bin') == oracle['sha256']
    job['status'] = 'completed_passed'
    job['full_vector_sha256_equal'] = True
    save()
except Exception as error:
    job['status'] = 'stopped_failure'
    job['failure'] = str(error)
    save()
    raise
finally:
    assert sha(ROOT / 'launch.json') == original_sha
    subprocess.run([sys.executable, str(candidate), 'verify'], check=True)
print(json.dumps({'matlab_control_status': job['status'], 'parent_protocol_incomplete': True, 'R2_passed': False}))
