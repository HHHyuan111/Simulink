"""Collect checked evidence for the three-topic observation milestone."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json

root=Path(__file__).resolve().parent.parent
modern=root/'modern'
teach=modern/'teaching'
expected='a0f7cbae9e7c334c25aa9dcf6e7e88d65fd89bd1888a0fa2ec0cd04f6cce262d'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(modern/'PMSM_FOC_R2026a.slx')==expected
fresh=[
 'teaching/deadtime_lesson/comparison_validation.json',
 'teaching/speed_lesson/validation.json',
 'teaching/sampling_lesson/validation.json',
 'teaching/frequency/noise_spectrum_validation.json',
 'teaching/core_teaching_navigation_validation.json',
 'layout/appearance/native_scope_validation.json',
 'layout/appearance/current_sampling_scope_validation.json',
 'layout/appearance/deadtime_scope_validation.json',
 'layout/appearance/deadtime_effects_scope_validation.json',
 'layout/appearance/deadtime_comp_scope_validation.json',
]
history=[
 'teaching/experiment_low_speed_comp_validation.json',
 'teaching/experiment_noise_filter_validation.json',
 'teaching/frequency/speed_loop/delivery_validation.json',
 'teaching/frequency/speed_probe/delivery_validation.json',
]
reports=[];exact=0
for relative in fresh:
 p=modern/relative;r=json.loads(p.read_text(encoding='utf-8'))
 assert r.get('passed') is True,relative
 if 'model_sha256' in r:assert r['model_sha256']==expected,relative
 exact+=r.get('original_log_checks',0)
 if 'original_checks' in r:
  assert all(c['time_equal'] and c['data_equal'] for c in r['original_checks'])
  exact+=len(r['original_checks'])
 for entry in r.get('source_files',[]):
  assert sha(p.parent/entry['path'])==entry['sha256'],entry['path']
 reports.append(dict(path=relative,sha256=sha(p),modified_utc=datetime.fromtimestamp(p.stat().st_mtime,timezone.utc).isoformat()))
assert exact==676
historical=[]
for relative in history:
 p=modern/relative;r=json.loads(p.read_text(encoding='utf-8'))
 assert r.get('passed',r.get('all_passed')) is True,relative
 historical.append(dict(path=relative,sha256=sha(p),scope='Previous independent full numerical replay; not rerun in this milestone.'))
sources=[
 'teaching/open_pmsm_observations.m','teaching/open_pmsm_speed_lesson.m',
 'teaching/open_pmsm_sampling_lesson.m','teaching/open_pmsm_sampling_comparison.m',
 'teaching/open_pmsm_deadtime_lesson.m','teaching/open_pmsm_deadtime_comparison.m',
 'teaching/pmsm_noise_filter_analysis.m','teaching/pmsm_noise_psd.m',
 'teaching/pmsm_current_spectrum.m','teaching/pmsm_deadtime_pair_alignment.m',
 'layout/appearance/pmsm_native_scope.m','layout/appearance/pmsm_current_sampling_scope.m',
 'layout/appearance/pmsm_deadtime_scope.m','layout/appearance/pmsm_scope_style.m',
 'teaching/validate_pmsm_sampling_lesson.m','teaching/validate_pmsm_speed_lesson.m',
 'teaching/validate_pmsm_deadtime_comparison.m','teaching/validate_pmsm_core_navigation.m',
]
artifacts=[
 'teaching/deadtime_lesson/example/comparison.png','teaching/speed_lesson/step.png',
 'teaching/speed_lesson/sine.png','teaching/sampling_lesson/comparison.png',
 'teaching/README_看懂死区.md','teaching/README_速度控制教学.md','teaching/README_电流采样教学.md',
 'teaching/核心教学观测基线_阶段报告.md','teaching/核心教学观测基线_体验清单.md',
]
report=dict(schema=1,passed=True,kind='core_teaching_observation_baseline_v1',
 generated_utc=datetime.now(timezone.utc).isoformat(),model_sha256=expected,
 reference_manifest_sha256=sha(teach/'reference_v1/manifest.json'),
 scope='Three teaching topics, read-only archive comparisons and short native-observer regressions. No PI tuning or new control algorithm.',
 current_stage_exact_original_log_checks=exact,fresh_validation_reports=reports,
 historical_full_replay_evidence=historical,
 sources=[dict(path=p,sha256=sha(modern/p)) for p in sources],
 artifacts=[dict(path=p,sha256=sha(modern/p)) for p in artifacts])
(teach/'core_teaching_stage_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'CORE_TEACHING_STAGE_VERIFIED: {len(fresh)} reports, {exact} exact original logs, model unchanged')
