"""Preserve executed MATLAB sources for data-only verification after report fixes."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import shutil
import uuid

HERE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('campaign', type=Path)
    args = parser.parse_args()
    campaign = json.loads((args.campaign/'campaign.json').read_text(encoding='utf-8-sig'))
    entry = next(e for e in campaign['entries'] if e['kind'] == 'observer' and e['completed_folder'])
    case = Path(entry['completed_folder'])
    record = json.loads((case/'record.json').read_text(encoding='utf-8-sig'))
    folder = HERE/'runs'/f'N3_source_capsule_{uuid.uuid4()}'
    source = folder/'source'; source.mkdir(parents=True)
    for row in record['source_files']:
        relative = PurePosixPath(row['path'])
        assert not relative.is_absolute() and '..' not in relative.parts
        before = case/'source'/relative
        assert sha(before) == row['sha256']
        target = source/relative; target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(before, target)
    for row in record['contracts']:
        before = HERE/row['path']; assert sha(before) == row['sha256']
        target = source/row['path']; target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(before, target)
    (source/'baseline').mkdir()
    shutil.copy2(HERE/'baseline/log_schema.json', source/'baseline/log_schema.json')
    teaching = folder/'teaching'; teaching.mkdir()
    for name in ('teach_hash.m', 'teach_writejson.m', 'teach_values.m'):
        shutil.copy2(HERE.parent/'teaching'/name, teaching/name)
    result = {'schema': 1, 'node': 'N3', 'kind': 'executed source capsule for archived data verification',
              'source_case_folder': str(case), 'source_case_record_sha256': sha(case/'record.json'),
              'source_folder': str(source), 'model_simulation_entry_not_used': True,
              'verification_entry': 'verify_sensorless_n3_replay',
              'files': [{'path': str(p.relative_to(folder)).replace('\\', '/'), 'sha256': sha(p)}
                        for p in sorted(folder.rglob('*')) if p.is_file()]}
    (folder/'capsule_manifest.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(source)


if __name__ == '__main__':
    main()
