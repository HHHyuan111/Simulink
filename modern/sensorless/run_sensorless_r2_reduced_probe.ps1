param([ValidateSet('baseline','missing_five','reset_one')][string]$CaseId='baseline',[string]$Label='')
$ErrorActionPreference='Stop'
if($Label -and $Label -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid diagnostic label.'}
foreach($prior in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'runs') -Directory -Filter ('N3R2_reduced_core_'+$CaseId+'*')) {
 $file=Join-Path $prior.FullName 'report.json';$exitFile=$prior.FullName+'_exit.json'
 if((Test-Path -LiteralPath $file) -and (Get-Content -LiteralPath $file -Raw | ConvertFrom-Json).phase -eq 'completed'){throw 'Completed reduced diagnostic retained; changing labels does not permit a rerun.'}
 if(Test-Path -LiteralPath $exitFile){$code=(Get-Content -LiteralPath $exitFile -Raw | ConvertFrom-Json).exit_code;if($code -notin @(0,1)){throw 'Existing native diagnostic failure retained; no new-label retry.'}}
}
$suffix='';if($Label){$suffix='_'+$Label}
$folder=Join-Path $PSScriptRoot ('runs/N3R2_reduced_core_'+$CaseId+$suffix)
if(Test-Path -LiteralPath $folder){throw 'Existing reduced probe retained; no automatic retry.'}
$source=(Join-Path $PSScriptRoot 'robust/diagnostics').Replace('\','/').Replace("'","''");$target=$folder.Replace('\','/').Replace("'","''")
$expression="addpath('$source');probe_sensorless_r2_reduced_graph('$CaseId','$target');"
& 'D:\DevTools\MATLAB\R2026a\bin\matlab.exe' -singleCompThread -batch $expression -logfile ($folder+'_console.log') *> ($folder+'_launcher.log')
$code=$LASTEXITCODE
@{exit_code=$code;automatic_retry=$false;plant_reexecuted=$false;expression=$expression} | ConvertTo-Json | Set-Content -LiteralPath ($folder+'_exit.json') -Encoding utf8
if($code -ne 0){throw "Reduced diagnostic stopped with exit $code; no retry."}
if(-not (Get-Content -LiteralPath (Join-Path $folder 'report.json') -Raw | ConvertFrom-Json).all_passed){throw 'Completed reduced comparison differs; retained without retry.'}
Write-Output ('REDUCED_CORE_FOLDER='+$folder)
