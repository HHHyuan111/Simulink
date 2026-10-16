"""Assemble disjoint replay groups, preserving every attempt and raw location."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import uuid

HERE = Path(__file__).resolve().parent


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('original', type=Path)
    parser.add_argument('groups', nargs='+', type=Path)
    args = parser.parse_args()
    expected = {c['id'] for c in read(HERE/'contracts/test_plan_v1.json')['cases'] if c['node'] == 'N3'}
    entries, groups, seen = [], [], set()
    first = None
    for folder in args.groups:
        path = folder/'campaign.json'; group = read(path)
        assert Path(group['replay_of']).resolve() == args.original.resolve()
        assert group['status'] in ('completed', 'has_failed_or_incomplete_cases')
        if first is None:
            first = group
        assert group['driver_sha256'] == first['driver_sha256']
        assert group['startup_options'] == first['startup_options']
        groups.append({'folder': str(folder.resolve()), 'campaign_sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        for entry in group['entries']:
            assert entry['kind'] == 'observer' and entry['case_id'] not in seen
            if entry['completed_folder']:
                record = read(Path(entry['completed_folder'])/'record.json')
                assert record['case_id'] == entry['case_id'] and record['observer_present']
            else:
                assert entry['status'] == 'incomplete' and entry['attempts']
            seen.add(entry['case_id']); entries.append(entry)
    assert seen == expected and len(entries) == 16
    order = [c['id'] for c in read(HERE/'contracts/test_plan_v1.json')['cases'] if c['node'] == 'N3']
    entries.sort(key=lambda e: order.index(e['case_id']))
    folder = HERE/'runs'/f'N3_replay_assembled_{datetime.datetime.now():%Y%m%d_%H%M%S}_{uuid.uuid4()}'
    folder.mkdir()
    result = {'schema': 1, 'node': 'N3', 'label': 'full replay inventory assembled from disjoint groups; incomplete entries retained',
              'folder': str(folder), 'replay_of': str(args.original.resolve()),
              'status': 'completed' if all(e['status'] == 'passed' for e in entries) else 'has_failed_or_incomplete_cases',
              'startup_options': first['startup_options'], 'driver_sha256': first['driver_sha256'],
              'group_manifests': groups, 'entries': entries,
              'assembly_driver_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'raw_data_copied_or_modified': False, 'duplicate_cases_permitted': False}
    (folder/'campaign.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(folder)


if __name__ == '__main__':
    main()
