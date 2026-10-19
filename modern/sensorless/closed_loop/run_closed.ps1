param([ValidateSet('build','first','repeat')][string]$Step='build',[string]$Label='')
$ErrorActionPreference='Stop'
$base=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$backend=$PSScriptRoot.Replace('\','/');$expression="addpath('$backend');"
if(-not $Label){$Label=$Step}
if($Label -notmatch '^[a-z][a-z0-9_]*$'){throw 'Use a simple run label'}
switch($Step){
 'build' {$expression+='build_sensorless_closed;'}
 'first' {$expression+="run_sensorless_closed('$Label',false);"}
 'repeat' {$expression+="run_sensorless_closed('$Label',true);"}
}
$argsList=@('-singleCompThread','-batch',('"'+$expression+'"'));if($Step -eq 'repeat'){$argsList=@('-singleCompThread','-r',('"'+$expression+'"'))}
$windowStyle='Hidden';if($Step -eq 'repeat'){$windowStyle='Normal'}
$process=Start-Process -FilePath 'D:\DevTools\MATLAB\R2026a\bin\matlab.exe' -WorkingDirectory (Split-Path (Split-Path $base)) -ArgumentList $argsList -WindowStyle $windowStyle -RedirectStandardOutput (Join-Path $base ('.build\closed_'+$Step+'_private_stdout.log')) -RedirectStandardError (Join-Path $base ('.build\closed_'+$Step+'_private_stderr.log')) -PassThru
$state=[ordered]@{step=$Step;run_label=$Label;status='running';launcher_pid=$process.Id;started_at=[DateTime]::UtcNow.ToString('o');exit_code=$null}
$status=Join-Path $base ('.build\closed_'+$Step+'_launch.json');$state|ConvertTo-Json|Set-Content -LiteralPath $status -Encoding utf8
if($Step -eq 'repeat'){Write-Output 'CLOSED_DESKTOP_STARTED';exit 0}
$process.WaitForExit();$process.Refresh();$state.exit_code=$process.ExitCode;$state.status='failed';if($process.ExitCode -eq 0){$state.status='completed'}
$state.finished_at=[DateTime]::UtcNow.ToString('o');$state|ConvertTo-Json|Set-Content -LiteralPath $status -Encoding utf8
Write-Output ('CLOSED_'+$Step+'='+$state.status)
