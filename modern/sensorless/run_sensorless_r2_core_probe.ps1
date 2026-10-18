param([string]$Label='once')
$ErrorActionPreference='Stop'
if($Label -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid diagnostic label.'}
foreach($prior in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'runs') -Directory -Filter 'N3R2_core_isolation_*') {
 $file=Join-Path $prior.FullName 'report.json'
 if((Test-Path -LiteralPath $file) -and (Get-Content -LiteralPath $file -Raw | ConvertFrom-Json).phase -eq 'completed'){throw 'Completed core isolation retained; changing labels does not permit a rerun.'}
}
$folder=Join-Path $PSScriptRoot ('runs/N3R2_core_isolation_'+$Label)
if(Test-Path -LiteralPath $folder){throw 'Diagnostic folder already exists; no automatic retry.'}
$source=(Join-Path $PSScriptRoot 'robust/diagnostics').Replace('\','/').Replace("'","''")
$target=$folder.Replace('\','/').Replace("'","''")
$console=$folder+'_console.log';$launcher=$folder+'_launcher.log'
$expression="addpath('$source');probe_sensorless_r2_core_replay('$target');"
& 'D:\DevTools\MATLAB\R2026a\bin\matlab.exe' -singleCompThread -batch $expression -logfile $console *> $launcher
$code=$LASTEXITCODE
@{exit_code=$code;automatic_retry=$false;plant_reexecuted=$false;expression=$expression} | ConvertTo-Json | Set-Content -LiteralPath ($folder+'_exit.json') -Encoding utf8
if($code -ne 0){throw "Core isolation probe stopped with exit $code; no retry."}
if(-not (Get-Content -LiteralPath (Join-Path $folder 'report.json') -Raw | ConvertFrom-Json).all_passed){throw 'Completed core comparison differs; retained without retry.'}
Write-Output ('CORE_ISOLATION_FOLDER='+$folder)
