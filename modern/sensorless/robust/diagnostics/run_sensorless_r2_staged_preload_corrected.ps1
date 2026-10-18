$ErrorActionPreference='Stop'
$base=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$prior=Join-Path $base 'runs\N3R2_staged_short_once'
$root=Join-Path $base 'runs\N3R2_staged_preload_repair_once'
if(Test-Path -LiteralPath $root){throw 'Corrected executor has already started; no retry.'}
$repair=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'staged_preload_repair.json') -Raw|ConvertFrom-Json
function Hash($path){(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}
$priorManifest=Join-Path $prior 'campaign.json'
if((Hash $priorManifest) -ne $repair.retained_campaign_sha256){throw 'Retained failed campaign changed.'}
$failed=Get-Content -LiteralPath $priorManifest -Raw|ConvertFrom-Json
if($failed.status -ne 'stopped_execution_failure' -or $failed.jobs.Count -ne 2 -or $failed.jobs[0].status -ne 'passed' -or $failed.jobs[1].exit_code -ne 1){throw 'Pre-load repair prerequisites not met.'}
$build=Join-Path $prior 'build'
if((Hash (Join-Path $build 'record.json')) -ne $repair.builder_record_sha256){throw 'Builder provenance changed.'}
$oldExecution=$failed.jobs[1].folder
foreach($name in @('record.json','report.json','signals.mat','generated_target_inventory.json')){
 if(Test-Path -LiteralPath (Join-Path $oldExecution $name)){throw 'Old executor reached a durable model phase; exception does not apply.'}
}
if((Hash (Join-Path $base $repair.source_path)) -ne $repair.output_sha256){throw 'Corrected executor derivation mismatch.'}
if((Hash (Join-Path $base $repair.contract_path)) -ne $repair.contract_sha256){throw 'Repair contract changed.'}
$py='C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Frozen candidate integrity failed.'}
$pref=Join-Path $base '.build\staged_preload_corrected_preferences'
if(Test-Path -LiteralPath $pref){throw 'Fresh preferences required.'}
New-Item -ItemType Directory -Path $pref -Force|Out-Null
New-Item -ItemType Directory -Path $root|Out-Null
$execution=Join-Path $root 'r1_short_logging_check_preload_corrected'
$manifest=[ordered]@{schema=1;node='N3R2';execution_version='portable_staged_execution';campaign_type='pre_load_staging_repair';status='running';R2_passed=$false;retained_campaign=$priorManifest;retained_campaign_sha256=$repair.retained_campaign_sha256;builder_record_sha256=$repair.builder_record_sha256;repair=$repair;simulation_retries=0;jobs=@()}
function Save-Manifest {$manifest|ConvertTo-Json -Depth 16|Set-Content -LiteralPath (Join-Path $root 'campaign.json') -Encoding utf8}
$job=[ordered]@{stage='execute';case_id='r1_short_logging_check';folder=$execution;status='running';exit_code=$null;started_at=[DateTime]::UtcNow.ToString('o');attempts=@()}
$manifest.jobs+=,$job;Save-Manifest
$backend=(Join-Path $base 'robust\portable_execution').Replace('\','/');$format=(Join-Path $base 'robust\execution_v8').Replace('\','/')
$dependency=Get-Content -LiteralPath (Join-Path $base 'milestones\N3R2\isolated_compiler_20261018.json') -Raw|ConvertFrom-Json
$mRoot=$dependency.compiler_root.Replace('\','/');$mPref=$pref.Replace('\','/');$mBuild=$build.Replace('\','/');$mExecution=$execution.Replace('\','/')
$expression="assert(strcmpi(char(java.io.File(prefdir).getCanonicalPath),char(java.io.File('$mPref').getCanonicalPath)));addpath('$backend','$format');setenv('MW_MINGW64_LOC','$mRoot');mex('-setup','C');mex('-setup','C++');execute_sensorless_r2_staged('$mBuild','$mExecution');normalize_sensorless_r2_v8_archive('$mExecution');"
$savedPref=$env:MATLAB_PREFDIR
try {
 $env:MATLAB_PREFDIR=$pref
 $process=Start-Process -FilePath 'D:\DevTools\MATLAB\R2026a\bin\matlab.exe' -ArgumentList @('-singleCompThread','-batch',('"'+$expression+'"')) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root 'execute_private_stdout.log') -RedirectStandardError (Join-Path $root 'execute_private_stderr.log') -PassThru
} finally {$env:MATLAB_PREFDIR=$savedPref}
$process.WaitForExit();$process.Refresh();$job.exit_code=$process.ExitCode;$job.status='exited'
$job.attempts=@(@{folder=$execution;exit_code=$job.exit_code;native_failure=$false;launcher_log=(Join-Path $root 'execute_private_stdout.log');logfile=(Join-Path $root 'execute_private_stderr.log')});Save-Manifest
if($job.exit_code -ne 0){$manifest.status='stopped_execution_failure'}
else {
 $r=Get-Content -LiteralPath (Join-Path $execution 'record.json') -Raw|ConvertFrom-Json
 $c=Get-Content -LiteralPath (Join-Path $execution 'log_format\v7_complete_log_comparison.json') -Raw|ConvertFrom-Json
 if($r.status -eq 'passed' -and $c.all_passed -and $c.logs -eq 96 -and $c.all_Time_Data_equal){$job.status='passed';$manifest.status='completed_passed'}
 else {$manifest.status='stopped_check_failure'}
}
Save-Manifest
if((Hash $priorManifest) -ne $repair.retained_campaign_sha256){throw 'Original failure record was modified.'}
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Frozen candidate integrity failed after executor.'}
Write-Output ('PRELOAD_CORRECTED_SHORT_STATUS='+$manifest.status)
