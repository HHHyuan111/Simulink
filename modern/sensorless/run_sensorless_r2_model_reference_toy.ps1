param([string]$MatlabExe='D:\DevTools\MATLAB\R2026a\bin\matlab.exe')
$ErrorActionPreference='Stop'
$runs=Join-Path $PSScriptRoot 'runs'
$folder=Join-Path $runs 'N3R2_model_reference_toy_isolation_once'
if(Test-Path -LiteralPath $folder){throw 'Native model reference toy already started. No repeated execution allowed.'}
foreach($prior in Get-ChildItem -LiteralPath $runs -Directory -Filter 'N3R2_*') {
 $manifest=Join-Path $prior.FullName 'campaign.json'
 if(-not(Test-Path -LiteralPath $manifest)){continue}
 $campaign=Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
 if($campaign.status -eq 'running'){throw ('Full-model campaign still active: '+$prior.Name+'. No process started.')}
}
$source=(Join-Path $PSScriptRoot 'robust/diagnostics').Replace('\','/').Replace("'","''")
$target=$folder.Replace('\','/').Replace("'","''")
$expression="addpath('$source');probe_sensorless_r2_model_reference_toy('$target');"
$log=$folder+'_console.log';$launcher=$folder+'_launcher.log'
& $MatlabExe -singleCompThread -batch $expression -logfile $log *> $launcher
$code=$LASTEXITCODE
@{exit_code=$code;expression=$expression;one_execution_only=$true} | ConvertTo-Json | Set-Content -LiteralPath ($folder+'_exit.json') -Encoding utf8
if($code -ne 0){throw ('Native model reference toy stopped; retained exit '+$code)}
Get-Content -LiteralPath (Join-Path $folder 'report.json') -Raw | ConvertFrom-Json | Select-Object kind,all_passed,phase,native_rows,JEOS_rows,completion_rows
