"""Package evidence of the sampling/timing local refinement, without model writes."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json

root=Path(__file__).resolve().parent.parent
modern=root/'modern'
folder=modern/'signal_chain'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
expected='a0f7cbae9e7c334c25aa9dcf6e7e88d65fd89bd1888a0fa2ec0cd04f6cce262d'
assert digest(modern/'PMSM_FOC_R2026a.slx')==expected
reference=modern/'teaching/reference_v1/manifest.json'
manifest=json.loads(reference.read_text(encoding='utf-8'))
for entry in manifest['files']:
 assert digest(reference.parent/entry['path'])==entry['sha256']
for entry in manifest['source_files']:
 assert digest(modern/entry['path'])==entry['sha256'],entry['path']
reports=[]
for filename in ('validation.json','view_regression.json','ui_validation.json'):
 p=folder/filename;r=json.loads(p.read_text(encoding='utf-8'));assert r['passed'] is True
 reports.append(dict(path=filename,sha256=digest(p)))
r=json.loads((folder/'validation.json').read_text(encoding='utf-8'))
assert len(r['cases'])==20 and len(r['compiled_tasks'])==6 and r['exact_view_original_log_checks']==156
v=json.loads((folder/'view_regression.json').read_text(encoding='utf-8'))
assert v['exact_original_logs']==156 and v['view_sha256']==digest(modern/'layout/appearance/pmsm_signal_chain_view.m')
sources=[
 'signal_chain/inspect_signal_chain.m','signal_chain/validate_signal_chain.m','signal_chain/render_signal_chain_results.m',
 'signal_chain/validate_signal_chain_view_regression.m','signal_chain/validate_signal_chain_ui.m',
 'layout/appearance/pmsm_signal_chain_view.m','layout/appearance/pmsm_sampling_labels.m',
 'layout/appearance/open_pmsm_controls.m','layout/appearance/pmsm_presented_call.m',
 'layout/appearance/rebuild_pmsm_observations.m','teaching/open_pmsm_current_sampling_scope.m','open_pmsm_model.m',
]
artifacts=['signal_chain/README.md','signal_chain/采样设置.png','signal_chain/输出延迟.png',
 'signal_chain/results/sampling.png','signal_chain/results/timing.png','signal_chain/results/source.json',
 'teaching/README_参数设置与实测.md']
record=dict(schema=1,passed=True,generated_utc=datetime.now(timezone.utc).isoformat(),
 model_sha256=expected,reference_manifest_sha256=digest(reference),
 physical_cases=20,case_duration_s=.002,exact_view_original_logs=156,
 verification_scope='Short equation, task timing, source/label and local-view regression; not board calibration or long-term stability.',
 reports=reports,sources=[dict(path=p,sha256=digest(modern/p)) for p in sources],
 artifacts=[dict(path=p,sha256=digest(modern/p)) for p in artifacts])
(folder/'delivery.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print('SIGNAL_CHAIN_DELIVERY_VERIFIED: 20 cases, 6 compiled tasks, 156 exact logs, frozen model/reference intact')
