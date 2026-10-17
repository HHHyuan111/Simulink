param([string]$Label='v8r1_remaining')
$ErrorActionPreference='Stop';$runs=Join-Path $PSScriptRoot 'runs'
$precheck=Join-Path $runs 'N3R2_v8r1_short_20261017_162814_c6e0244a-576c-4beb-9594-d644dfc04eec/r1_short_logging_check_attempt_1'
$record=Get-Content -LiteralPath (Join-Path $precheck 'record.json') -Raw | ConvertFrom-Json
$recovery=Get-Content -LiteralPath (Join-Path $precheck 'log_format_recovery.json') -Raw | ConvertFrom-Json
if(-not $recovery.all_passed -or -not $recovery.strict96_and_R1_81_comparisons_passed){throw 'Analysis-recovered precheck did not pass.'}
$folder=Join-Path $runs ('N3R2_v8r1_queue_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid());$null=New-Item -ItemType Directory -Path $folder
$state=[ordered]@{node='N3R2';execution_version='single_init_short_cache_v8r1';status='running';current_case='';results=@();all_passed=$false;formal_matrix_passed=$false}
function Save-State {$state | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $folder 'queue.json') -Encoding utf8}
Save-State
try {
 foreach($id in @('low_speed_stop','missing_five','reset_one')) {
  foreach($f in $record.source_files){if((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $f.path)).Hash.ToLower() -ne $f.sha256){throw "Precheck source changed: $($f.path)"}}
  if((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'robust/execution_v8/normalize_sensorless_r2_v8_archive.m')).Hash.ToLower() -ne $recovery.adapter_sha256){throw 'Log adapter changed after verification.'}
  $state.current_case=$id;Save-State;$result=[ordered]@{case_id=$id;execution_finished=$false;error=''}
  try {& (Join-Path $PSScriptRoot 'run_sensorless_r2_v8.ps1') -CaseIds @($id) -Label ($Label+'_'+$id);$result.execution_finished=$true}
  catch {$result.error=$_.Exception.Message}
  $state.results+=,$result;Save-State
 }
 $state.current_case='';$state.status='executions_finished_requires_metric_review';Save-State
} catch {$state.status='stopped_needs_diagnosis';$state.error=$_.Exception.Message;Save-State;throw}
Write-Output "N3R2_V8_QUEUE=$folder"
