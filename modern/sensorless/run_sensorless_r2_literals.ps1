param(
 [ValidateSet('r1_short_logging_check','hot_R1p2_L0p8','cold_R0p8_L1p2')]
 [string[]]$CaseIds=@('r1_short_logging_check','hot_R1p2_L0p8','cold_R0p8_L1p2'),
 [string]$Label='literal_binding_v6',
 [string]$MatlabExe='D:\DevTools\MATLAB\R2026a\bin\matlab.exe'
)
$ErrorActionPreference='Stop'
$version='literal_binding_v6';$remaining=@{}
foreach($id in $CaseIds) {
 if($id -ne 'r1_short_logging_check') {
  foreach($prior in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'runs') -Directory -Filter 'N3R2_*') {
   foreach($priorCase in Get-ChildItem -LiteralPath $prior.FullName -Directory -Filter ($id+'_attempt_*')) {
    $recordPath=Join-Path $priorCase.FullName 'record.json'
    if((Test-Path -LiteralPath $recordPath) -and (Test-Path -LiteralPath (Join-Path $priorCase.FullName 'signals.mat'))) {
     $priorRecord=Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
     if($priorRecord.raw_sha256){throw "Equivalent R/L physics already archived for $id. A literal binding must not rerun a completed numerical outcome. Use archive analysis or the later final-candidate replay. No process started."}
    }
   }
  }
 }
 $failures=0
 foreach($prior in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'runs') -Directory -Filter 'N3R2_*') {
  $file=Join-Path $prior.FullName 'campaign.json';if(-not(Test-Path -LiteralPath $file)){continue}
  $data=Get-Content -LiteralPath $file -Raw | ConvertFrom-Json;if($data.execution_version -ne $version){continue}
  foreach($job in @($data.jobs | Where-Object {$_.case_id -eq $id})) {
   $failures+=@($job.attempts | Where-Object {$_.native_failure}).Count
   foreach($priorAttempt in $job.attempts) {
    $priorRecordFile=Join-Path $priorAttempt.folder 'record.json'
    if(Test-Path -LiteralPath $priorRecordFile) {
     $priorRun=Get-Content -LiteralPath $priorRecordFile -Raw | ConvertFrom-Json
     if($priorRun.raw_sha256 -and (Test-Path -LiteralPath (Join-Path $priorAttempt.folder 'signals.mat'))) {
      throw "R2 simulation already archived for $id ($version). Do not rerun completed physics; use analysis-only recovery or the later authorized R3 replay. No process started."
     }
    }
   }
  }
 }
 if($failures -ge 2){throw "R2 $version native limit exhausted for $id; no process started."}
 $remaining[$id]=2-$failures
}
$probe=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'runs/N3R2_stopped_init_compile_probe_once/record.json') -Raw | ConvertFrom-Json
if($probe.status -ne 'diagnostic_passed' -or -not $probe.workspace_unchanged_by_compile){throw 'Stopped-initialization isolation prerequisite did not pass.'}
$components=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'runs/N3R2_phase_guard_components_once/metrics.json') -Raw | ConvertFrom-Json
if(-not $components.all_passed){throw 'Packet phase guard component prerequisite failed.'}
$plantCheck=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'runs/N3R2_plant_separation_configuration_once/report.json') -Raw | ConvertFrom-Json
if(-not $plantCheck.all_passed -or $plantCheck.source_sha256 -ne (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'robust/scenarios/sensorless_r2_plant_parameters.m')).Hash.ToLower()){throw 'Plant-only separation prerequisite failed or changed.'}
$literalProbe=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'runs/N3R2_literal_binding_compile_probe_once/report.json') -Raw | ConvertFrom-Json
if($literalProbe.status -ne 'diagnostic_passed' -or -not $literalProbe.nominal_observer_preserved){throw 'Literal-binding compile probe prerequisite failed.'}
$campaign=Join-Path $PSScriptRoot ('runs/N3R2_'+$Label+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid());$null=New-Item -ItemType Directory -Path $campaign
$source=(Join-Path $PSScriptRoot 'robust/literal_plant').Replace('\','/').Replace("'","''")
$manifest=[ordered]@{schema=1;node='N3R2';execution_version=$version;label=$Label;status='running';numerical_version='R1 estimates plus packet phase guard';folder=$campaign;driver_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLower();jobs=@()}
function Save-Manifest {$manifest | ConvertTo-Json -Depth 25 | Set-Content -LiteralPath (Join-Path $campaign 'campaign.json') -Encoding utf8}
Save-Manifest
foreach($id in $CaseIds) {
 $job=[ordered]@{case_id=$id;status='incomplete';attempts=@();completed_folder=''}
 for($attempt=1;$attempt -le $remaining[$id];$attempt++) {
  $folder=Join-Path $campaign ($id+'_attempt_'+$attempt);$target=$folder.Replace('\','/').Replace("'","''")
  $expression="addpath('$source');validate_sensorless_r2_literal_case('$id','$target');"
  if($id -eq 'r1_short_logging_check'){$expression+="verify_sensorless_r2_logging('$target');"}
  $log=Join-Path $campaign ($id+'_attempt_'+$attempt+'_console.log');$launcher=Join-Path $campaign ($id+'_attempt_'+$attempt+'_launcher.log')
  & $MatlabExe -singleCompThread -batch $expression -logfile $log 2>&1 | Tee-Object -FilePath $launcher | Out-Host
  $code=$LASTEXITCODE;$native=($code -in @(-1073741819,-1073741795)) -or ((Get-Content -LiteralPath $launcher -Raw) -match '0xc0000005|0xc000001d')
  $job.attempts+=,@{exit_code=$code;native_failure=$native;folder=$folder;expression=$expression;logfile=$log;launcher_log=$launcher}
  if($code -eq 0){$record=Get-Content -LiteralPath (Join-Path $folder 'record.json') -Raw | ConvertFrom-Json;$job.status=$record.status;$job.completed_folder=$folder;break}
  if(-not $native){$manifest.jobs+=,$job;$manifest.status='failed_execution';Save-Manifest;throw "R2 scenario script failure retained: $launcher"}
 }
 $manifest.jobs+=,$job;Save-Manifest
 if(-not $job.completed_folder){$manifest.status='native_attempts_exhausted';Save-Manifest;throw "R2 scenario native limit reached: $id"}
}
$manifest.status='completed_passed';if(@($manifest.jobs | Where-Object {$_.status -ne 'passed'}).Count){$manifest.status='completed_performance_failed_needs_diagnosis'}
Save-Manifest;Write-Output "N3R2_SCENARIO_CAMPAIGN=$campaign"
