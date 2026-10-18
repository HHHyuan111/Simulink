$ErrorActionPreference='Stop'
$base=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$py='C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$campaign=Join-Path $base 'runs\N3R2_generated_backend_short_once'
if(Test-Path -LiteralPath $campaign){throw 'Generated backend short already started; no retry or relabel.'}
$probe=Get-Content -LiteralPath (Join-Path $base 'runs\N3R2_rapid_process_once\report.json') -Raw|ConvertFrom-Json
if(-not $probe.all_passed -or -not $probe.rapid_pid_is_distinct){throw 'Instrumented process-boundary prerequisite failed.'}
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Prior frozen source integrity failed.'}
foreach($file in Get-ChildItem -LiteralPath (Join-Path $base 'runs') -Directory -Filter 'N3R2_*'){
 $manifest=Join-Path $file.FullName 'campaign.json'
 if(Test-Path -LiteralPath $manifest){$value=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json;if($value.status -eq 'running'){throw 'Another campaign is active.'}}
}
New-Item -ItemType Directory -Path $campaign|Out-Null
$folder=Join-Path $campaign 'r1_short_logging_check_attempt_1'
$pref=Join-Path $base ('.build\generated_backend_preferences\'+[guid]::NewGuid())
New-Item -ItemType Directory -Path $pref -Force|Out-Null
$manifest=[ordered]@{schema=1;node='N3R2';campaign_type='development_strict_generated_short';execution_version='generated_rapid_backend';status='running';folder=$campaign;driver_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLower();formal_retries=0;started_at=[DateTime]::UtcNow.ToString('o');private_preferences=$pref;jobs=@([ordered]@{case_id='r1_short_logging_check';status='running';completed_folder='';attempts=@([ordered]@{folder=$folder;status='running';exit_code=$null;native_failure=$false})})}
function Save-Manifest {$manifest|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $campaign 'campaign.json') -Encoding utf8}
Save-Manifest
$dependency=Get-Content -LiteralPath (Join-Path $base 'milestones\N3R2\isolated_compiler_20261018.json') -Raw|ConvertFrom-Json
$psPref=$env:MATLAB_PREFDIR
try {
 $env:MATLAB_PREFDIR=$pref
 $mPref=$pref.Replace('\','/');$mRoot=$dependency.compiler_root.Replace('\','/');$mFolder=$folder.Replace('\','/')
 $backend=(Join-Path $base 'robust\generated_backend').Replace('\','/');$format=(Join-Path $base 'robust\execution_v8').Replace('\','/')
 $expression="assert(strcmpi(char(java.io.File(prefdir).getCanonicalPath),char(java.io.File('$mPref').getCanonicalPath)));setenv('MW_MINGW64_LOC','$mRoot');mex('-setup','C');mex('-setup','C++');addpath('$backend','$format');validate_sensorless_r2_generated_case('r1_short_logging_check','$mFolder');normalize_sensorless_r2_v8_archive('$mFolder');"
 $stdout=Join-Path $campaign 'private_stdout.log';$stderr=Join-Path $campaign 'private_stderr.log'
 $process=Start-Process -FilePath 'D:\DevTools\MATLAB\R2026a\bin\matlab.exe' -ArgumentList @('-singleCompThread','-batch',('"'+$expression+'"')) -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
} finally {$env:MATLAB_PREFDIR=$psPref}
$process.WaitForExit();$process.Refresh();$code=$process.ExitCode
$attempt=$manifest.jobs[0].attempts[0];$attempt.status='exited';$attempt.exit_code=$code;$attempt.launcher_log=$stdout;$attempt.logfile=$stderr
$manifest.status='failed_execution';$manifest.jobs[0].status='failed_execution'
if($code -eq 0){
 $record=Get-Content -LiteralPath (Join-Path $folder 'record.json') -Raw|ConvertFrom-Json
 $comparison=Get-Content -LiteralPath (Join-Path $folder 'log_format\v7_complete_log_comparison.json') -Raw|ConvertFrom-Json
 $formatting=Get-Content -LiteralPath (Join-Path $folder 'log_format_recovery.json') -Raw|ConvertFrom-Json
 if($record.status -eq 'passed' -and $comparison.all_passed -and $comparison.logs -eq 96 -and $comparison.all_Time_Data_equal -and $formatting.all_passed){
  $manifest.status='completed_passed';$manifest.jobs[0].status='passed';$manifest.jobs[0].completed_folder=$folder
 } else {$manifest.status='completed_precheck_failed';$manifest.jobs[0].status='precheck_failed'}
}
Save-Manifest
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Prior frozen source integrity failed after execution.'}
Write-Output ('GENERATED_SHORT_STATUS='+$manifest.status+'; EXIT='+$code)
if($manifest.status -ne 'completed_passed'){throw 'Generated strict short did not pass; no long case permitted.'}
