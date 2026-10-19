$ErrorActionPreference='Stop'
$base=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$root=Join-Path $base 'runs\N3R2_clean_normal_formal_once'
if(Test-Path -LiteralPath $root){throw 'Formal matrix already started; no replay or retry'}
$python='C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$checker=Join-Path $base 'robust\normal_serialized\clean_formal.py'
$candidateFile=Join-Path $base 'milestones\N3R2\clean_formal_20261019\frozen_candidate.json'
& $python $checker verify
if($LASTEXITCODE -ne 0){throw 'Candidate failed before formal start'}
$candidate=Get-Content -LiteralPath $candidateFile -Raw|ConvertFrom-Json
$candidateSha=(Get-FileHash -LiteralPath $candidateFile).Hash.ToLowerInvariant()
New-Item -ItemType Directory -Path $root|Out-Null
Copy-Item -LiteralPath $candidateFile -Destination (Join-Path $root 'frozen_candidate.json')
$manifest=[ordered]@{schema=1;node='N3R2';campaign_type='formal_frozen_candidate_matrix_clean_runtime';execution_version=$candidate.execution_version;environment=$candidate.environment;candidate_sha256=$candidateSha;status='running';formal_retries=0;R2_passed=$false;R3_started=$false;jobs=@();remaining_cases=@($candidate.formal_case_order)}
foreach($id in $candidate.formal_case_order){$manifest.jobs+=,[ordered]@{case_id=$id;status='pending';stages=@();completed_folder='';formal_provenance=''}}
function Save-Manifest {$manifest|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $root 'campaign.json') -Encoding utf8}
trap {
 if($null -ne $manifest -and $manifest.status -eq 'running'){
  $manifest.status='stopped_driver_failure';$manifest.driver_error_type=$_.Exception.GetType().FullName
  if($null -ne $job -and $job.status -eq 'running'){$job.status='failed_driver'}
  Save-Manifest
 }
 throw
}
function Check-Candidate {
 & $python $checker verify
 if($LASTEXITCODE -ne 0 -or (Get-FileHash -LiteralPath $candidateFile).Hash.ToLowerInvariant() -ne $candidateSha){$manifest.status='stopped_integrity_failure';Save-Manifest;throw 'Formal candidate changed'}
}
Save-Manifest
$backend=(Join-Path $base 'robust\normal_serialized').Replace('\','/')
$matlabRoot=(Split-Path -Parent (Split-Path -Parent $candidate.matlab_executable)).Replace('\','/')
foreach($job in $manifest.jobs){
 Check-Candidate
 $id=$job.case_id;$caseFolder=Join-Path $root $id
 New-Item -ItemType Directory -Path $caseFolder|Out-Null
 $started=[DateTime]::UtcNow.ToString('o')
 [ordered]@{case_id=$id;candidate_sha256=$candidateSha;started_at=$started;formal_starts=1;formal_retries=0}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $caseFolder 'formal_start.json') -Encoding utf8
 $job.status='running';Save-Manifest
 $build=Join-Path $caseFolder 'build';$execution=Join-Path $caseFolder 'execution'
 foreach($stage in @('build','execution')){
  Check-Candidate
  $pref=Join-Path $base ('.build\clean_normal_formal_preferences\'+$id+'\'+$stage)
  if(Test-Path -LiteralPath $pref){throw 'Fresh formal preferences required'}
  New-Item -ItemType Directory -Path $pref -Force|Out-Null
  $mPref=$pref.Replace('\','/');$mBuild=$build.Replace('\','/');$mExecution=$execution.Replace('\','/')
  $expression="assert(strcmpi(strrep(matlabroot,'\','/'),'$matlabRoot'));assert(strcmp(version,'26.1.0.3346908 (R2026a) Update 5'));assert(strcmpi(char(java.io.File(prefdir).getCanonicalPath),char(java.io.File('$mPref').getCanonicalPath)));addpath('$backend');"
  if($stage -eq 'build'){$expression+="build_sensorless_r2_normal_serialized('$id','$mBuild');"}
  else {$expression+="execute_sensorless_r2_normal_serialized('$mBuild','$mExecution');normalize_sensorless_r2_normal_serialized_archive('$mExecution');"}
  $entry=[ordered]@{stage=$stage;status='running';pid=$null;exit_code=$null;exit_hex=$null;started_at=[DateTime]::UtcNow.ToString('o');finished_at=$null}
  $job.stages+=,$entry;Save-Manifest
  $savedPref=$env:MATLAB_PREFDIR
  try {
   $env:MATLAB_PREFDIR=$pref
   $process=Start-Process -FilePath $candidate.matlab_executable -WorkingDirectory 'D:\simulink\dev' -ArgumentList @('-singleCompThread','-batch',('"'+$expression+'"')) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $caseFolder ($stage+'_private_stdout.log')) -RedirectStandardError (Join-Path $caseFolder ($stage+'_private_stderr.log')) -PassThru
  } finally {$env:MATLAB_PREFDIR=$savedPref}
  $entry.pid=$process.Id;Save-Manifest
  $process.WaitForExit();$process.Refresh();$entry.exit_code=$process.ExitCode;$entry.finished_at=[DateTime]::UtcNow.ToString('o')
  $entry.exit_hex='0x'+([BitConverter]::ToUInt32([BitConverter]::GetBytes([int32]$entry.exit_code),0)).ToString('x8');$entry.status='exited';Save-Manifest
  Check-Candidate
  if($entry.exit_code -ne 0){$job.status='failed_execution';$manifest.status='stopped_execution_failure';Save-Manifest;break}
  $folder=$execution;if($stage -eq 'build'){$folder=$build}
  $r=Get-Content -LiteralPath (Join-Path $folder 'record.json') -Raw|ConvertFrom-Json
  if($r.status -ne 'passed' -or -not $r.reference_restored -or -not $r.main_bridge_preserved){$job.status='failed_checks';$manifest.status='stopped_check_failure';Save-Manifest;break}
  $entry.status='passed';Save-Manifest
 }
 if($manifest.status -ne 'running'){break}
 & $python $checker outcome $execution
 if($LASTEXITCODE -ne 0){$job.status='failed_acceptance_or_provenance';$manifest.status='stopped_acceptance_failure';Save-Manifest;break}
 $job.status='passed';$job.completed_folder=$execution;$job.formal_provenance=Join-Path $execution 'formal_provenance.json'
 $manifest.remaining_cases=@($manifest.remaining_cases|Where-Object {$_ -ne $id});Save-Manifest
 Write-Output ('CLEAN_NORMAL_FORMAL_CASE_PASSED='+$id)
}
Check-Candidate
if(@($manifest.jobs|Where-Object {$_.status -eq 'passed'}).Count -eq 14 -and $manifest.remaining_cases.Count -eq 0){$manifest.status='completed_passed';$manifest.R2_passed=$true;Save-Manifest}
Write-Output ('CLEAN_NORMAL_FORMAL_STATUS='+$manifest.status)
