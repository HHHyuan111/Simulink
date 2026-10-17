param([string]$Label='once')
$ErrorActionPreference='Stop'
if($Label -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid diagnostic label.'}
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
Write-Output ('CORE_ISOLATION_FOLDER='+$folder)
