param(
 [ValidateSet('r1_short_logging_check','missing_five','reset_one')]
 [string[]]$CaseIds=@('r1_short_logging_check'),
 [string]$Label='block_reduction_diagnostic_v9',
 [string]$MatlabExe='D:\DevTools\MATLAB\R2026a\bin\matlab.exe'
)
$ErrorActionPreference='Stop';$version='block_reduction_off_v9';$remaining=@{}
$runs=Join-Path $PSScriptRoot 'runs'
$toy=Get-Content -LiteralPath (Join-Path $runs 'N3R2_single_initialization_toy_endpoint_fixed_once/report.json') -Raw | ConvertFrom-Json
if(-not $toy.all_passed -or $toy.source_sha256 -ne (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'robust/execution_v8/sensorless_r2_run_initialized.m')).Hash.ToLower()){throw 'Single-initialization toy prerequisite failed or helper changed.'}
foreach($id in $CaseIds) {
 $starts=0;$priorStarts=0
 foreach($prior in Get-ChildItem -LiteralPath $runs -Directory -Filter 'N3R2_*') {
  foreach($attempt in Get-ChildItem -LiteralPath $prior.FullName -Directory -Filter ($id+'_attempt_*')) {
   $file=Join-Path $attempt.FullName 'record.json';if(-not(Test-Path -LiteralPath $file)){continue}
   $r=Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
   if($id -ne 'r1_short_logging_check' -and $r.raw_sha256 -and (Test-Path -LiteralPath (Join-Path $attempt.FullName 'signals.mat'))){throw "Completed physics already archived for $id. No v9 physical rerun."}
  }
  $file=Join-Path $prior.FullName 'campaign.json';if(-not(Test-Path -LiteralPath $file)){continue}
  $c=Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
  if($c.execution_version -eq $version -and $c.status -eq 'running'){throw 'A v9 campaign is active. No process started.'}
  foreach($job in @($c.jobs | Where-Object {$_.case_id -eq $id})) {
   if($c.execution_version -ne $version){$priorStarts+=@($job.attempts).Count;continue}
   $starts+=@($job.attempts).Count
   foreach($a in $job.attempts) {
    if($a.exit_code -eq 0 -or -not $a.native_failure){throw "Existing v9 outcome for $id cannot be retried. No process started."}
   }
  }
 }
 if($starts -ge 2){throw "Two-start limit exhausted for $id ($version)."}
 if($id -ne 'r1_short_logging_check' -and $priorStarts -lt 2){throw "No exhausted prior path established for $id. No process started."}
 $remaining[$id]=2-$starts
}
if('r1_short_logging_check' -notin $CaseIds) {
 $ready=$false
 foreach($prior in Get-ChildItem -LiteralPath $runs -Directory -Filter 'N3R2_*') {
  $file=Join-Path $prior.FullName 'campaign.json';if(-not(Test-Path -LiteralPath $file)){continue}
  $c=Get-Content -LiteralPath $file -Raw | ConvertFrom-Json;if($c.execution_version -ne $version){continue}
  foreach($job in @($c.jobs | Where-Object {$_.case_id -eq 'r1_short_logging_check'})) {
   foreach($a in $job.attempts) {
    $recoveryPath=Join-Path $a.folder 'log_format_recovery.json';if(-not(Test-Path -LiteralPath $recoveryPath)){continue}
    $recovery=Get-Content -LiteralPath $recoveryPath -Raw | ConvertFrom-Json
    $v=Get-Content -LiteralPath (Join-Path $a.folder 'log_format/v7_complete_log_comparison.json') -Raw | ConvertFrom-Json
    $r=Get-Content -LiteralPath (Join-Path $a.folder 'record.json') -Raw | ConvertFrom-Json;$same=$true
    foreach($f in $r.source_files){if((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $f.path)).Hash.ToLower() -ne $f.sha256){$same=$false}}
    $adapterSha=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'robust/execution_v8/normalize_sensorless_r2_v8_archive.m')).Hash.ToLower()
    if($c.status -eq 'completed_passed' -and $r.block_reduction.restored -and $r.block_reduction.effective -eq 'off' -and $same -and $v.all_passed -and $v.logs -eq 96 -and $recovery.all_passed -and $recovery.adapter_sha256 -eq $adapterSha){$ready=$true;$precheckFolder=$a.folder}
   }
  }
 }
 if(-not $ready){throw 'Final-source96-log precheck prerequisite failed.'}
}
$campaign=Join-Path $runs ('N3R2_'+$Label+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid());$null=New-Item -ItemType Directory -Path $campaign
$source=(Join-Path $PSScriptRoot 'robust/execution_v9').Replace('\','/').Replace("'","''")
$manifest=[ordered]@{schema=1;node='N3R2';execution_version=$version;label=$Label;status='running';folder=$campaign;driver_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLower();jobs=@()}
$formatContract=Join-Path $PSScriptRoot 'contracts/nonideal_r2_v8_uniform_log_format.json';$manifest.log_format_contract_sha256=(Get-FileHash -LiteralPath $formatContract).Hash.ToLower()
Copy-Item -LiteralPath $formatContract -Destination (Join-Path $campaign 'log_format_contract.json')
if($precheckFolder){$manifest.analysis_recovered_precheck=$precheckFolder}
function Save-Manifest {$manifest | ConvertTo-Json -Depth 25 | Set-Content -LiteralPath (Join-Path $campaign 'campaign.json') -Encoding utf8}
Save-Manifest
foreach($id in $CaseIds) {
 $job=[ordered]@{case_id=$id;status='incomplete';attempts=@();completed_folder=''}
 for($attempt=1;$attempt -le $remaining[$id];$attempt++) {
  $folder=Join-Path $campaign ($id+'_attempt_'+$attempt);$target=$folder.Replace('\','/').Replace("'","''")
  $support=(Join-Path $PSScriptRoot 'robust/execution_v8').Replace('\','/').Replace("'","''")
  $expression="addpath('$source','$support');validate_sensorless_r2_v9_case('$id','$target');normalize_sensorless_r2_v8_archive('$target');"
  $log=Join-Path $campaign ($id+'_attempt_'+$attempt+'_console.log');$launcher=Join-Path $campaign ($id+'_attempt_'+$attempt+'_launcher.log')
  & $MatlabExe -singleCompThread -batch $expression -logfile $log *> $launcher
  $code=$LASTEXITCODE;$native=($code -in @(-1073741819,-1073741795)) -or ((Get-Content -LiteralPath $launcher -Raw) -match '0xc0000005|0xc000001d')
  $job.attempts+=,@{exit_code=$code;native_failure=$native;folder=$folder;expression=$expression;logfile=$log;launcher_log=$launcher}
  if($code -eq 0){$r=Get-Content -LiteralPath (Join-Path $folder 'record.json') -Raw | ConvertFrom-Json;$format=Get-Content -LiteralPath (Join-Path $folder 'log_format_recovery.json') -Raw | ConvertFrom-Json;if($format.contract_sha256 -ne $manifest.log_format_contract_sha256){throw 'Log format contract changed during execution.'};$job.status=$r.status;$job.completed_folder=$folder;break}
  if(-not $native){$manifest.jobs+=,$job;$manifest.status='failed_execution';Save-Manifest;throw "V9 nonretryable execution failure: $folder"}
 }
 $manifest.jobs+=,$job;Save-Manifest
 if(-not $job.completed_folder){$manifest.status='native_attempts_exhausted';Save-Manifest;throw "V9 two-start limit reached: $id"}
 if($id -eq 'r1_short_logging_check' -and $job.status -ne 'passed'){$manifest.status='short_precheck_failed';Save-Manifest;throw 'Short precheck failed.'}
}
$manifest.status='completed_passed';if(@($manifest.jobs | Where-Object {$_.status -ne 'passed'}).Count){$manifest.status='completed_performance_failed_needs_diagnosis'}
Save-Manifest;Write-Output "N3R2_V9_CAMPAIGN=$campaign"
