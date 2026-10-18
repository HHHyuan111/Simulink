"""Read only targeted component file-presence manifests; no expected content hashes exist."""
from pathlib import Path
from datetime import datetime
import hashlib
import json

BASE = Path(__file__).resolve().parents[2]
INSTALL = Path('D:/DevTools/MATLAB/R2026a')
DEST = BASE / 'milestones/N3R2/crash_context_20261018/manifest_observation.json'
TARGETS = {'m_lxe.dll', 'libmx.dll', 'simulinkblock.dll', 'libmwslexec_runtime.dll', 'msvcp140.dll',
           'libmwir.dll', 'libmwfl.dll', 'mcos_impl.dll', 'libmwsl_elem_blocks.dll', 'icuin74.dll', 'libmwfixedpointcore.dll'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


assert not DEST.exists()
matched = []
for manifest in (INSTALL / 'appdata/files').rglob('*_manifest.json'):
    entries = json.loads(manifest.read_text('utf-8-sig'))
    matches = [entry for entry in entries if Path(entry.replace('\\', '/')).name.casefold() in TARGETS]
    if not matches:
        continue
    missing, outside = [], []
    for entry in entries:
        path = (INSTALL / entry.replace('\\', '/')).resolve()
        if not path.is_relative_to(INSTALL.resolve()):
            outside.append(entry)
        elif not path.exists():
            missing.append(entry)
    matched.append({'manifest': manifest.relative_to(INSTALL).as_posix(), 'manifest_sha256': sha(manifest),
                    'target_entries': matches, 'declared_entries': len(entries),
                    'missing_paths': missing, 'outside_root_entries': outside})
report = {'captured_at': datetime.now().astimezone().isoformat(), 'read_only': True,
          'generator_sha256': sha(Path(__file__)), 'matched_components': matched,
          'missing_path_count': sum(len(row['missing_paths']) for row in matched),
          'scope': 'Selected component manifest paths present/absent only. Manifests contain path lists without expected file content hashes. This cannot prove a clean installation or rule out incompatible binaries, software defects or transient hardware/runtime issues.',
          'settings_changed': False, 'root_cause_confirmed': False}
DEST.write_bytes((json.dumps(report, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
print(json.dumps({'matched_components': len(matched), 'missing_paths': report['missing_path_count'], 'root_cause_confirmed': False}))
