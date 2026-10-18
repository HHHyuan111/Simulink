"""Prepare an exact owned child/source bundle; never load MATLAB."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import shutil

BASE = Path(__file__).resolve().parents[2]
BUILD = BASE / 'runs/N3R2_observer_codegen_short_once/build'
DEST = BASE / 'runs/N3R2_child_only_build_bundle'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    assert not DEST.exists(), 'Never overwrite a prepared bundle.'
    record = json.loads((BUILD / 'record.json').read_text('utf-8-sig'))
    assert record['status'] == 'passed' and len(record['source_files']) == 176
    assert all(count == 1 for count in Counter(Path(item['path']).name for item in record['source_files']).values())
    DEST.mkdir()
    files = []

    def copy(source, relative, expected=None):
        if expected:
            assert sha(source) == expected
        target = DEST / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        files.append({'path': relative, 'sha256': sha(target)})

    for entry in record['source_files']:
        assert (BASE / entry['path']).suffix == '.m'
        assert sha(BASE / entry['path']) == entry['sha256']
        copy(BUILD / 'source' / entry['path'], 'source/' + entry['path'], entry['sha256'])
    child = Path(record['reference_adapter']['child_file'])
    model = 'model/' + child.name
    copy(child, model, record['exported_child_sha256'])
    copy(BASE / 'contracts/nonideal_r2_child_only_build_probe.json', 'contract.json')
    copy(Path(__file__).with_name('reproduce_sensorless_r2_child_build.m'), 'reproduce_sensorless_r2_child_build.m')
    copy(BUILD / 'record.json', 'metadata/builder_record.json')
    copy(BUILD / 'graph.json', 'metadata/graph.json')
    copy(BASE / 'milestones/N3R2/isolated_compiler_20261018.json', 'compiler_dependency.json')
    manifest = {'schema': 1, 'purpose': 'standalone child target build only; zero sim; no parent file',
                'child_model': child.stem, 'model_file': model, 'model_sha256': sha(child),
                'builder_record_sha256': sha(BUILD / 'record.json'), 'runtime_source_count': 176,
                'observer_config': record['observer_config'], 'frontend_config': record['config_vector'],
                'files': files, 'raw_dump_or_license_included': False}
    (DEST / 'manifest.json').write_bytes((json.dumps(manifest, ensure_ascii=True, indent=2)+'\n').encode())
    print(json.dumps({'prepared': True, 'folder': str(DEST), 'files': len(files), 'manifest_sha256': sha(DEST / 'manifest.json')}))


if __name__ == '__main__':
    main()
