param([string]$MatlabExe='D:\DevTools\MATLAB\R2026a\bin\matlab.exe')
$ErrorActionPreference='Stop'
$runs=Join-Path $PSScriptRoot 'runs'
$priorFolder=Join-Path $runs 'N3R2_observer_graph_isolation_once'
$retained=Get-Content -LiteralPath (Join-Path $priorFolder 'report.json') -Raw | ConvertFrom-Json
if($retained.phase -ne 'diagnostic_error' -or $retained.phase_at_error -ne 'restore_source_before_reduced_execution' -or (Test-Path (Join-Path $priorFolder 'signals.mat')) -or (Test-Path (Join-Path $priorFolder 'execution_progress.json'))){throw 'Original pre-execution failure evidence invalid. No process started.'}
$folder=Join-Path $runs 'N3R2_observer_graph_context_fixed_once'
if(Test-Path -LiteralPath $folder){throw 'Native complete observer graph probe already started. No repeated execution allowed.'}
foreach($prior in Get-ChildItem -LiteralPath $runs -Directory -Filter 'N3R2_*') {
 $manifest=Join-Path $prior.FullName 'campaign.json'
 if(-not(Test-Path -LiteralPath $manifest)){continue}
 $campaign=Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
 if($campaign.status -eq 'running'){throw ('Full-model campaign still active: '+$prior.Name+'. No process started.')}
}
$source=(Join-Path $PSScriptRoot 'robust/diagnostics').Replace('\','/').Replace("'","''")
$target=$folder.Replace('\','/').Replace("'","''")
$expression="addpath('$source');probe_sensorless_r2_observer_graph('$target');"
$log=$folder+'_console.log';$launcher=$folder+'_launcher.log'
& $MatlabExe -singleCompThread -batch $expression -logfile $log *> $launcher
$code=$LASTEXITCODE
@{exit_code=$code;expression=$expression;one_execution_only=$true} | ConvertTo-Json | Set-Content -LiteralPath ($folder+'_exit.json') -Encoding utf8
if($code -ne 0){throw ('Native complete observer graph probe stopped; retained exit '+$code)}
Get-Content -LiteralPath (Join-Path $folder 'report.json') -Raw | ConvertFrom-Json | Select-Object kind,all_passed,phase,native_evaluations,publications,observer_log_count,clone_block_count
