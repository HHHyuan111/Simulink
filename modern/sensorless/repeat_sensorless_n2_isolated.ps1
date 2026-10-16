param(
    [Parameter(Mandatory=$true)][string]$OriginalFolder,
    [string]$MatlabExe='D:\DevTools\MATLAB\R2026a\bin\matlab.exe'
)
$ErrorActionPreference='Stop'
$sensorlessPath=$PSScriptRoot.Replace('\','/')
$originalPath=(Resolve-Path -LiteralPath $OriginalFolder).Path.Replace('\','/')
$replayFolder=Join-Path $PSScriptRoot ('runs/N2_isolated_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $replayFolder
$replayPath=$replayFolder.Replace('\','/')
# Escape single quotes for MATLAB character literals, not for a shell command.
$sensorlessPath=$sensorlessPath.Replace("'","''")
$originalPath=$originalPath.Replace("'","''")
$replayPath=$replayPath.Replace("'","''")
for($caseIndex=1;$caseIndex -le 5;$caseIndex++) {
    $expression="addpath('$sensorlessPath'); sensorless_n2_isolated('case','$originalPath','$replayPath',$caseIndex);"
    & $MatlabExe -batch $expression -logfile (Join-Path $replayFolder "case_$caseIndex.log")
    if($LASTEXITCODE -ne 0) { throw "N2 case $caseIndex failed; preserve $replayFolder" }
}
$expression="addpath('$sensorlessPath'); sensorless_n2_isolated('finish','$originalPath','$replayPath',0);"
& $MatlabExe -batch $expression -logfile (Join-Path $replayFolder 'analysis.log')
if($LASTEXITCODE -ne 0) { throw "N2 replay analysis failed; preserve $replayFolder" }
Write-Output "N2_REPLAY_FOLDER=$replayFolder"
