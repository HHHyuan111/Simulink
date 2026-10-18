"""Extract the official portable dependency into a new private project folder."""
from pathlib import Path
from datetime import datetime
import hashlib
import json
import stat
import subprocess
import zipfile

BASE = Path(__file__).resolve().parents[2]
archive = BASE / '.build/tools/mingw81.zip'
target = BASE / '.build/tools/mingw81'
report_file = BASE / 'milestones/N3R2/isolated_compiler_20261018.json'
assert archive.stat().st_size == 140343786
assert not target.exists() and not report_file.exists()
with zipfile.ZipFile(archive) as bundle:
    for info in bundle.infolist():
        assert (target / info.filename).resolve().is_relative_to(target.resolve()), info.filename
        assert not stat.S_ISLNK(info.external_attr >> 16), info.filename
    target.mkdir(parents=True)
    bundle.extractall(target)
gccs = list(target.glob('**/bin/gcc.exe'))
assert len(gccs) == 1
gcc = gccs[0]
gxx = gcc.with_name('g++.exe')


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


report = {
    'captured_at': datetime.now().astimezone().isoformat(), 'kind': 'isolated_portable_compiler',
    'source_url': 'https://ssd.mathworks.com/supportfiles/downloads/SupportPackageThirdParty/R2023b/mingw_w64/win64/mingw81.zip',
    'archive_bytes': archive.stat().st_size, 'archive_sha256': sha(archive),
    'extraction_root': target.as_posix(), 'compiler_root': gcc.parent.parent.as_posix(),
    'gcc_sha256': sha(gcc), 'gxx_sha256': sha(gxx),
    'gcc_version': subprocess.check_output([str(gcc), '--version'], text=True).splitlines()[0],
    'gxx_version': subprocess.check_output([str(gxx), '--version'], text=True).splitlines()[0],
    'generator_sha256': sha(Path(__file__)), 'archive_paths_confined': True,
    'installer_run': False, 'system_environment_changed': False, 'user_environment_changed': False,
    'existing_matlab_preferences_changed': False, 'R2_passed': False,
}
report_file.write_bytes((json.dumps(report, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
print(json.dumps(report, ensure_ascii=False))
