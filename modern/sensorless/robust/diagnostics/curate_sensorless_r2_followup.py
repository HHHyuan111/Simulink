"""Publish source-bound R2 progress; never equate a subset with full acceptance."""
from pathlib import Path
import hashlib,json,shutil

BASE=Path(__file__).resolve().parents[2]
DEST=BASE/'milestones/N3R2/followup_20261017'
CAMPAIGNS=[
 'N3R2_stopped_init_v3_20261017_105619_277b3c70-cdf0-4542-b35d-d320753c4b82',
 'N3R2_packet_phase_guard_v4_20261017_112427_9e735b46-7a5c-4647-9ded-1039e323d9ef',
 'N3R2_guard_static_matrix_20261017_113855_f2397e8f-45aa-4262-b709-eeb01805f5c9']
def read(p):return json.loads(p.read_text('utf-8-sig'))
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def copy(src,name):
 shutil.copyfile(src,DEST/name)
 return {'source':str(src.relative_to(BASE)).replace('\\','/'),'published':name,'sha256':sha(src)}
def main():
 DEST.mkdir(parents=True,exist_ok=True);published=[];attempts=[];metrics=[]
 frozen=read(BASE/'milestones/N3R1/frozen_candidate.json')
 for e in frozen['files']:assert sha(BASE/e['path'])==e['sha256']
 assert sha(BASE.parent/'PMSM_FOC_R2026a.slx')==frozen['model_sha256']
 for ci,name in enumerate(CAMPAIGNS):
  folder=BASE/'runs'/name;campaign=read(folder/'campaign.json');assert campaign['status']!='running'
  published.append(copy(folder/'campaign.json',f'campaign_{ci+3}.json'))
  for job in campaign['jobs']:
   for index,attempt in enumerate(job['attempts'],1):
    path=Path(attempt['folder']);record=read(path/'record.json')
    for e in record['source_files']:assert sha(path/'source'/e['path'])==e['sha256']
    for e in record['contracts']:assert sha(path/e['path'])==e['sha256']
    attempts.append({'case_id':job['case_id'],'version':campaign['execution_version'],'attempt':index,
                     'native_failure':attempt['native_failure'],'exit_code':attempt['exit_code'],
                     'last_phase':record['phase'],'source_record_sha256':sha(path/'record.json')})
   if not job['completed_folder']:continue
   path=Path(job['completed_folder']);record=read(path/'record.json');m=read(path/'metrics.json')
   assert sha(path/'signals.mat')==record['raw_sha256']
   prefix=('v3' if ci==0 else 'v4')+'_'+job['case_id']
   for file in ['record.json','metrics.json','logging_validation.json','graph.json','log_coverage.json','estimator_state_comparison.json']:
    if (path/file).exists():published.append(copy(path/file,prefix+'_'+file))
   if job['case_id']=='diagnostic_combined_3000':
    for file in ['diagnosis.png','independent_metrics.json','provenance.json']:
     if (path/'review'/file).exists():published.append(copy(path/'review'/file,prefix+'_'+file))
   metrics.append({'case_id':job['case_id'],'version':campaign['execution_version'],
                   'status':job['status'],'metrics':m,'raw_sha256':record['raw_sha256']})
 for folder,prefix,file in [('N3R2_stopped_init_compile_probe_once','stopped_init','record.json'),
  ('N3R2_phase_guard_components_once','phase_guard_components','record.json'),
  ('N3R2_phase_guard_components_once','phase_guard_components','metrics.json'),
  ('N3R2_plant_separation_configuration_once','plant_separation','report.json')]:
  published.append(copy(BASE/'runs'/folder/file,prefix+'_'+file))
 published.append(copy(BASE/'.build/R2_windows_exception_metadata.json','windows_exception_metadata.json'))
 plan=read(BASE/'contracts/nonideal_r2_test_plan.json')
 accepted={m['case_id'] for m in metrics if m['version']=='packet_phase_guard_v4' and m['status']=='passed'}
 remaining=[c['id'] for c in plan['cases'] if c['kind']!='logging_validation' and c['id'] not in accepted]
 report={'node':'N3R2','all_passed':False,'status':'five_static_cases_passed_other_physical_cases_pending',
         'accepted_static_cases':len(accepted-{'r1_short_logging_check'}),'remaining_case_ids':remaining,
         'r1_frozen_files_preserved':len(frozen['files']),'model_sha256':frozen['model_sha256'],
         'attempts':attempts,'case_metrics':metrics,'published':published,
         'native_root_cause_confirmed':False,'full_independent_replay_done':False,
         'original52_full_long_baseline_regression_done':False,'feedback_takeover':False,
         'original_bounded_logs':['obs_dead_gates','obs_dead_requested'],
         'bounded_original_logs_max_points':4000,
         'coverage_checker_history':'Initial checker assumed unbounded logs and failed; original SLX caps confirmed and configured-retention audit passed without model/log changes.'}
 (DEST/'summary.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print('R2_FOLLOWUP_INTEGRITY_PASSED; static_cases=5; R2_ALL_PASSED=False; remaining='+str(len(remaining)))
if __name__=='__main__':main()
