param(
 [ValidateSet('r1_short_logging_check','missing_five','reset_one','deadline_jitter')]
 [string[]]$CaseIds=@('r1_short_logging_check','missing_five','reset_one','deadline_jitter'),
 [string]$Label='fault_ingress_schedule_v7',
 [string]$MatlabExe='D:\DevTools\MATLAB\R2026a\bin\matlab.exe'
)
$ErrorActionPreference='Stop'
$version='fault_ingress_schedule_v7';$remaining=@{}
foreach($id in $CaseIds) {
 $failures=0
 foreach($prior in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'runs') -Directory -Filter 'N3R2_*') {
  $file=Join-Path $prior.FullName 'campaign.json';if(-not(Test-Path -LiteralPath $file)){continue}
  $data=Get-Content -LiteralPath $file -Raw | ConvertFrom-Json;if($data.execution_version -ne $version){continue}
  if($data.status -eq 'running'){throw "Another $version campaign is still active. No process started."}
  foreach($job in @($data.jobs | Where-Object {$_.case_id -eq $id})) {
   $failures+=@($job.attempts | Where-Object {$_.native_failure}).Count
   foreach($attempt in $job.attempts) {
    $recordFile=Join-Path $attempt.folder 'record.json'
    if(Test-Path -LiteralPath $recordFile) {
     $r=Get-Content -LiteralPath $recordFile -Raw | ConvertFrom-Json
     if($r.raw_sha256 -and (Test-Path -LiteralPath (Join-Path $attempt.folder 'signals.mat'))){throw "Physics already archived for $id ($version); analyze that archive. No process started."}
    }
   }
  }
 }
 if($failures -ge 2){throw "Native attempt limit exhausted for $id ($version). No process started."}
 $remaining[$id]=2-$failures
}
$components=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'runs/N3R2_fault_cores_once/report.json') -Raw | ConvertFrom-Json
if(-not $components.all_passed){throw 'Fault component prerequisite failed.'}
foreach($property in $components.sources.PSObject.Properties) {
 $path=Join-Path $PSScriptRoot ('robust/faults/'+$property.Name+'.m')
 if((Get-FileHash -LiteralPath $path).Hash.ToLower() -ne $property.Value){throw "Fault core changed after component checks: $path"}
}
$probe=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'runs/N3R2_fault_timing_restoration_fixed_compile_once/record.json') -Raw | ConvertFrom-Json
if($probe.status -ne 'diagnostic_passed' -or -not $probe.restored -or -not $probe.graph.passed){throw 'Fault timing graph/restoration prerequisite failed.'}
foreach($file in $probe.source_files) {
 if((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $file.path)).Hash.ToLower() -ne $file.sha256){throw "Graph-checked source changed: $($file.path)"}
}
$nominal=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'runs/N3R2_fault_graph_tag_fix_probe_once/nominal_comparison.json') -Raw | ConvertFrom-Json
if(-not $nominal.all_passed -or $nominal.logs -ne 90 -or -not $nominal.original52_included){throw 'Nominal90-log equality prerequisite failed.'}
if('r1_short_logging_check' -notin $CaseIds) {
 $shortPassed=$false
 foreach($prior in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'runs') -Directory -Filter 'N3R2_*') {
  $path=Join-Path $prior.FullName 'campaign.json';if(-not(Test-Path -LiteralPath $path)){continue}
  $priorManifest=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
  if($priorManifest.execution_version -ne $version){continue}
  foreach($job in @($priorManifest.jobs | Where-Object {$_.case_id -eq 'r1_short_logging_check' -and $_.status -eq 'passed'})) {
   $validation=Get-Content -LiteralPath (Join-Path $job.completed_folder 'logging_validation.json') -Raw | ConvertFrom-Json
   $shortRecord=Get-Content -LiteralPath (Join-Path $job.completed_folder 'record.json') -Raw | ConvertFrom-Json
   $same=$true
   foreach($file in $shortRecord.source_files) {
    if((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $file.path)).Hash.ToLower() -ne $file.sha256){$same=$false}
   }
   if($same -and $validation.all_passed -and $validation.original52_included){$shortPassed=$true}
  }
 }
 if(-not $shortPassed){throw 'Final-source short precheck prerequisite failed. No long fault process started.'}
}
$campaign=Join-Path $PSScriptRoot ('runs/N3R2_'+$Label+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid());$null=New-Item -ItemType Directory -Path $campaign
$source=(Join-Path $PSScriptRoot 'robust/faults').Replace('\','/').Replace("'","''")
$manifest=[ordered]@{schema=1;node='N3R2';execution_version=$version;label=$Label;status='running';folder=$campaign;driver_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLower();jobs=@()}
function Save-Manifest {$manifest | ConvertTo-Json -Depth 25 | Set-Content -LiteralPath (Join-Path $campaign 'campaign.json') -Encoding utf8}
Save-Manifest
foreach($id in $CaseIds) {
 $job=[ordered]@{case_id=$id;status='incomplete';attempts=@();completed_folder=''}
 for($attempt=1;$attempt -le $remaining[$id];$attempt++) {
  $folder=Join-Path $campaign ($id+'_attempt_'+$attempt);$target=$folder.Replace('\','/').Replace("'","''")
  $expression="addpath('$source');validate_sensorless_r2_fault_case('$id','$target');"
  if($id -eq 'r1_short_logging_check'){$expression+="verify_sensorless_r2_logging('$target');"}
  $log=Join-Path $campaign ($id+'_attempt_'+$attempt+'_console.log');$launcher=Join-Path $campaign ($id+'_attempt_'+$attempt+'_launcher.log')
  & $MatlabExe -singleCompThread -batch $expression -logfile $log *> $launcher
  $code=$LASTEXITCODE;$native=($code -in @(-1073741819,-1073741795)) -or ((Get-Content -LiteralPath $launcher -Raw) -match '0xc0000005|0xc000001d')
  $job.attempts+=,@{exit_code=$code;native_failure=$native;folder=$folder;expression=$expression;logfile=$log;launcher_log=$launcher}
  if($code -eq 0){$r=Get-Content -LiteralPath (Join-Path $folder 'record.json') -Raw | ConvertFrom-Json;$job.status=$r.status;$job.completed_folder=$folder;break}
  if(-not $native){$manifest.jobs+=,$job;$manifest.status='failed_execution';Save-Manifest;throw "Fault execution failed; preserved private archive: $folder"}
 }
 $manifest.jobs+=,$job;Save-Manifest
 if(-not $job.completed_folder){$manifest.status='native_attempts_exhausted';Save-Manifest;throw "Native limit reached for $id; no third attempt."}
 if($id -eq 'r1_short_logging_check' -and $job.status -ne 'passed'){$manifest.status='short_precheck_failed';Save-Manifest;throw 'Short precheck failed. No long fault case started.'}
}
$manifest.status='completed_passed';if(@($manifest.jobs | Where-Object {$_.status -ne 'passed'}).Count){$manifest.status='completed_performance_failed_needs_diagnosis'}
Save-Manifest;Write-Output "N3R2_FAULT_CAMPAIGN=$campaign"
