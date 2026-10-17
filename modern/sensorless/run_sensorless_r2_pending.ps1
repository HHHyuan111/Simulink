param(
 [Parameter(Mandatory=$true)][string]$WaitForCampaign,
 [string]$Label='pending_serial'
)
# One foreground physical job at a time. No scheduler/recurring automation.
$ErrorActionPreference='Stop'
$waitPath=(Resolve-Path -LiteralPath $WaitForCampaign).Path
$runsRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'runs')).Path
if(-not $waitPath.StartsWith($runsRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Wait target must be an existing local sensorless campaign.'}
$folder=Join-Path $runsRoot ('N3R2_serial_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid());$null=New-Item -ItemType Directory -Path $folder
$state=[ordered]@{node='N3R2';status='waiting_for_existing_campaign';wait_for=$waitPath;results=@();all_passed=$false;formal_matrix_passed=$false}
function Save-State {$state | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $folder 'serial.json') -Encoding utf8}
Save-State
$guard=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'runs/N3R2_fault_timing_restoration_fixed_compile_once/record.json') -Raw | ConvertFrom-Json
function Check-Sources {
 foreach($file in $guard.source_files) {
  if((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $file.path)).Hash.ToLower() -ne $file.sha256){throw "Source changed while queued: $($file.path). Stop without launching another physical job."}
 }
}
function Archived-Physics([string]$id,[string]$version='') {
 foreach($campaign in Get-ChildItem -LiteralPath $runsRoot -Directory -Filter 'N3R2_*') {
  foreach($attempt in Get-ChildItem -LiteralPath $campaign.FullName -Directory -Filter ($id+'_attempt_*')) {
   $path=Join-Path $attempt.FullName 'record.json'
   if(-not(Test-Path -LiteralPath $path)){continue}
   $record=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
   if($version -and $record.execution_version -ne $version){continue}
   if($record.raw_sha256 -and (Test-Path -LiteralPath (Join-Path $attempt.FullName 'signals.mat'))){return $attempt.FullName}
  }
 }
 return ''
}
function Invoke-Job([string]$driver,[string]$id) {
 Check-Sources;$state.status='running';$state.current_case=$id;Save-State
 $result=[ordered]@{case_id=$id;driver=$driver;execution_finished=$false;error=''}
 try {& (Join-Path $PSScriptRoot $driver) -CaseIds @($id) -Label ($Label+'_'+$id);$result.execution_finished=$true}
 catch {$result.error=$_.Exception.Message}
 $state.results+=,$result;Save-State
}
try {
 while((Get-Content -LiteralPath $waitPath -Raw | ConvertFrom-Json).status -eq 'running'){Start-Sleep -Seconds 10}
 Check-Sources
 # The original batch may stop on one native case; collect independent cases.
 foreach($id in @('deadtime_2us','adc_clipping','low_speed_stop')) {
  $existing=Archived-Physics $id 'basic_scenarios_v5'
  if(-not $existing){Invoke-Job 'run_sensorless_r2_scenarios.ps1' $id}
 }
 # Equivalent R/L bindings are only eligible after two alias native failures.
 foreach($id in @('hot_R1p2_L0p8','cold_R0p8_L1p2')) {
  if(Archived-Physics $id){continue}
  $nativeFailures=0
  foreach($campaign in Get-ChildItem -LiteralPath $runsRoot -Directory -Filter 'N3R2_*') {
   $path=Join-Path $campaign.FullName 'campaign.json';if(-not(Test-Path -LiteralPath $path)){continue}
   $manifest=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
   if($manifest.execution_version -ne 'basic_scenarios_v5'){continue}
   foreach($job in @($manifest.jobs | Where-Object {$_.case_id -eq $id})){$nativeFailures+=@($job.attempts | Where-Object {$_.native_failure}).Count}
  }
  if($nativeFailures -ge 2){Invoke-Job 'run_sensorless_r2_literals.ps1' $id}
 }
 foreach($id in @('missing_five','reset_one','deadline_jitter')) {
  if(-not(Archived-Physics $id 'fault_ingress_schedule_v7')){Invoke-Job 'run_sensorless_r2_faults.ps1' $id}
 }
 $state.status='executions_finished_requires_metric_review';$state.current_case='';Save-State
} catch {$state.status='stopped_needs_diagnosis';$state.error=$_.Exception.Message;Save-State;throw}
Write-Output "N3R2_SERIAL_RECORD=$folder"
