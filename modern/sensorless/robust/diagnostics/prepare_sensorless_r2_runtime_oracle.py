"""Create an immutable exact reference before any native or MATLAB control starts."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import struct

BASE = Path(__file__).resolve().parents[2]
ROOT = BASE / 'runs/N3R2_runtime_oracle_once'
assert not ROOT.exists(), 'Oracle/control already prepared; no overwrite.'
ROOT.mkdir()
A, C, MOD, COUNT, STEPS = 1664525, 1013904223, 1 << 32, 65536, 32
alpha = pow(A, STEPS, MOD)
beta = C * sum(pow(A, k, MOD) for k in range(STEPS)) % MOD
values = []
for seed in range(COUNT):
    value = seed
    for _ in range(STEPS):
        value = (A * value + C) % MOD
    assert value == (alpha * seed + beta) % MOD
    values.append(value)
payload = struct.pack('<' + 'I' * COUNT, *values)
fnv = 2166136261
for byte in payload:
    fnv = ((fnv ^ byte) * 16777619) & 0xffffffff
path = ROOT / 'oracle.bin'
path.write_bytes(payload)
manifest = {
    'prepared_at': datetime.now(timezone.utc).isoformat(), 'count': COUNT, 'steps': STEPS,
    'bytes': len(payload), 'sha256': hashlib.sha256(payload).hexdigest(), 'fnv1a32_hex': f'{fnv:08x}',
    'independent_closed_form_all_seeds_equal': True, 'closed_form_alpha': alpha, 'closed_form_beta': beta,
    'samples': {str(k): values[k] for k in (0, 1, 2, 12345, COUNT - 1)},
    'max_double_intermediate_less_than_2p53': A * (MOD - 1) + C < (1 << 53),
    'generator_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'contract_sha256': hashlib.sha256((BASE / 'contracts/nonideal_r2_runtime_oracle_probe.json').read_bytes()).hexdigest(),
    'simulation_starts': 0, 'R2_passed': False,
}
(ROOT / 'oracle.json').write_bytes((json.dumps(manifest, indent=2) + '\n').encode('utf-8'))
print(json.dumps(manifest))
