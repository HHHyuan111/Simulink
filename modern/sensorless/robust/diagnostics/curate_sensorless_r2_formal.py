"""Publish a read-only snapshot of the one frozen R2 campaign, without executing MATLAB."""
from pathlib import Path
from datetime import datetime
import importlib.util
import json
import shutil

BASE = Path(__file__).resolve().parents[2]
DEST = BASE / 'milestones/N3R2/formal_20261018'
spec = importlib.util.spec_from_file_location('frozen_r2_candidate', BASE / 'robust/formal_r2/candidate.py')
candidate_tools = importlib.util.module_from_spec(spec)
spec.loader.exec_module(candidate_tools)
read, sha = candidate_tools.read, candidate_tools.sha

LABELS = {
    'missing_five': '观测输入连续缺 5 帧',
    'diagnostic_combined_3000': '+3000 rpm', 'combined_1000': '+1000 rpm',
    'combined_2000': '+2000 rpm', 'combined_reverse_1000': '−1000 rpm',
    'combined_reverse_3000': '−3000 rpm', 'combined_dynamic': '速度与负载阶跃',
    'hot_R1p2_L0p8': '本体 R×1.2、L×0.8', 'cold_R0p8_L1p2': '本体 R×0.8、L×1.2',
    'deadtime_2us': '本体死区 2 μs', 'adc_clipping': 'ADC 持续削顶',
    'reset_one': '观测器软件复位 1 帧', 'low_speed_stop': '1000→200→0 rpm',
    'deadline_jitter': '发布抖动与 CCR 超期',
}


def main():
    candidate = candidate_tools.verify()
    candidate_sha = sha(candidate_tools.CANDIDATE)
    matches = []
    for path in (BASE / 'runs').glob('N3R2_*/campaign.json'):
        value = read(path)
        if value.get('campaign_type') == 'formal_frozen_candidate_matrix':
            matches.append((path, value))
    assert len(matches) == 1, 'Exactly one formal campaign is permitted.'
    path, manifest = matches[0]
    assert manifest['candidate_sha256'] == candidate_sha
    assert sha(path.parent / 'frozen_candidate.json') == candidate_sha
    assert manifest['formal_retries'] == 0
    assert manifest['formal_case_order'] == candidate['formal_case_order']
    jobs = {job['case_id']: job for job in manifest['jobs']}
    assert len(jobs) == len(manifest['jobs'])
    DEST.mkdir(parents=True, exist_ok=True)
    published, cases = [], []

    def publish(source, relative):
        target = DEST / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        published.append({'path': relative, 'sha256': sha(target)})

    # The manifest below is the exact in-memory snapshot used for the summary.
    (DEST / 'campaign.json').write_bytes((json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
    publish(path.parent / 'frozen_candidate.json', 'frozen_candidate.json')
    for case_id in candidate['formal_case_order']:
        job = jobs.get(case_id)
        item = {'case_id': case_id, 'label': LABELS[case_id],
                'status': job['status'] if job else 'not_started'}
        if job:
            assert len(job['attempts']) == 1, 'Formal retry or duplicate attempt detected.'
            attempt = job['attempts'][0]
            folder = Path(attempt['folder'])
            start = path.parent / (case_id + '_formal_start.json')
            assert read(start)['candidate_sha256'] == candidate_sha
            publish(start, case_id + '/formal_start.json')
            item['exit_code'] = attempt.get('exit_code')
            for name in ('record.json', 'execution_progress.json'):
                if (folder / name).exists():
                    publish(folder / name, case_id + '/' + name)
            if job['status'] == 'passed':
                record, formatting = candidate_tools.validate_record(folder, candidate)
                proof = read(folder / 'formal_provenance.json')
                assert proof['all_passed'] and proof['candidate_sha256'] == candidate_sha
                assert proof['record_sha256'] == sha(folder / 'record.json')
                assert proof['formal_start_sha256'] == sha(start)
                assert proof['raw_sha256'] == record['raw_sha256']
                assert proof['canonical_sha256'] == formatting['canonical_sha256']
                assert proof['formal_retries'] == 0 and proof['original_record_unmodified']
                for entry in record['source_files']:
                    assert sha(folder / 'source' / entry['path']) == entry['sha256']
                for entry in record['contracts']:
                    assert sha(folder / entry['path']) == entry['sha256']
                metrics = read(folder / 'metrics.json')
                for name in ('formal_provenance.json', 'metrics.json', 'graph.json', 'direct_graph.json',
                             'log_format_recovery.json'):
                    publish(folder / name, case_id + '/' + name)
                for name in ('logging_validation.json', 'format_contract.json'):
                    if (folder / 'log_format' / name).exists():
                        publish(folder / 'log_format' / name, case_id + '/log_format/' + name)
                item.update({'all_passed': True, 'raw_sha256': record['raw_sha256'],
                             'canonical_sha256': formatting['canonical_sha256'],
                             'false_valid_longest_s': metrics['false_valid_longest_s'],
                             'metrics': metrics, 'restoration_passed': True})
        cases.append(item)
    passed = sum(item['status'] == 'passed' for item in cases)
    all_passed = passed == 14 and manifest['status'] == 'completed_passed' and manifest['R2_passed']
    summary = {'node': 'N3R2', 'stage': 'formal_frozen_candidate_matrix',
               'captured_at': datetime.now().astimezone().isoformat(), 'campaign': path.parent.name,
               'campaign_status': manifest['status'], 'candidate_sha256': candidate_sha,
               'frozen_files_verified': len(candidate['files']), 'formal_retries': 0,
               'passed_cases': passed, 'total_cases': 14, 'all_passed': all_passed,
               'simulation_reexecuted_by_curator': False, 'development_results_used_as_formal_passes': False,
               'user_R2_acceptance_pending': True, 'R3_started': False, 'feedback_takeover': False,
               'hardware_validated': False, 'native_root_cause_confirmed': False,
               'cases': cases, 'published': published}
    (DEST / 'summary.json').write_bytes((json.dumps(summary, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
    lines = ['# R2 冻结候选正式验收', '', f'记录时间：{summary["captured_at"]}。正式通过 **{passed}/14**，执行状态 `{manifest["status"]}`。', '',
             f'候选 SHA256：`{candidate_sha}`；{len(candidate["files"])} 个冻结文件校验通过。每项一次正式启动、零重试，任一失败停止。开发数据不替代正式结果。', '',
             '|正式工况|状态|原生最长误放行|', '|---|---|---|']
    states = {'passed': '通过', 'running': '执行中', 'not_started': '未启动', 'failed_execution': '执行异常，未通过'}
    for item in cases:
        interval = f'{item["false_valid_longest_s"] * 1000:.6g} ms' if item['status'] == 'passed' else '—'
        lines.append(f'|{item["label"]}|{states.get(item["status"], item["status"])}|{interval}|')
    lines += ['', '全 14 项执行通过后仍需用户验收 R2 节点，再进入 R3 独立复现与原 52 路长时回归。当前不接管主控制反馈，工程假设不代表实板或 WCET 达标。', '',
              '缺帧测试针对观测输入链路，复位针对观测器软件状态；主控制继续使用原反馈。软件许可撤销不代表整机 PWM 故障保护已经接入。', '',
              '[逐项指标、数据指纹、还原结果与来源](N3R2/formal_20261018/summary.json)。原始 MATLAB 数据和私有日志保留在本机 runs 目录，不随报告公开。', '']
    (BASE / 'milestones/N3R2_formal.md').write_bytes('\n'.join(lines).encode('utf-8'))
    print(json.dumps({key: summary[key] for key in ('passed_cases', 'total_cases', 'campaign_status', 'all_passed', 'frozen_files_verified')}))


if __name__ == '__main__':
    main()
