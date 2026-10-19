param([ValidateSet('build','first','repeat','render','inspect','baseline','review')][string]$Step='build')
$ErrorActionPreference='Stop'
$base=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runtime='D:\DevTools\MATLAB\R2026a\bin\matlab.exe'
$backend=$PSScriptRoot.Replace('\','/')
$expression="fprintf('DIRECT_ENTRY\n');addpath('$backend');sensorless_direct_setup;"
switch($Step){
 'build' {$expression+='build_sensorless_direct;'}
 'first' {$expression+="run_sensorless_direct('first');"}
 'repeat' {$expression+="run_sensorless_direct('repeat');render_sensorless_direct;"}
 'render' {$expression+='render_sensorless_direct;'}
 'inspect' {$expression+='inspect_sensorless_direct_gates;render_sensorless_direct;'}
 'baseline' {$expression+='run_sensorless_direct_baseline;'}
 'review' {$expression+='render_sensorless_direct_review;'}
}
$statusFile=Join-Path $base ('.build\direct_'+$Step+'_launch.json')
$state=[ordered]@{step=$Step;status='running';started_at=[DateTime]::UtcNow.ToString('o');launcher_pid=$null;exit_code=$null}
function Save-Status {$state|ConvertTo-Json|Set-Content -LiteralPath $statusFile -Encoding utf8}
Save-Status
$process=Start-Process -FilePath $runtime -WorkingDirectory (Split-Path (Split-Path $base)) -ArgumentList @('-singleCompThread','-batch',('"'+$expression+'"')) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $base ('.build\direct_'+$Step+'_private_stdout.log')) -RedirectStandardError (Join-Path $base ('.build\direct_'+$Step+'_private_stderr.log')) -PassThru
$state.launcher_pid=$process.Id;Save-Status
$process.WaitForExit();$process.Refresh();$state.exit_code=$process.ExitCode
$state.status='failed';if($process.ExitCode -eq 0){$state.status='completed'}
$state.finished_at=[DateTime]::UtcNow.ToString('o');Save-Status
Write-Output ('DIRECT_'+$Step+'='+$state.status)
