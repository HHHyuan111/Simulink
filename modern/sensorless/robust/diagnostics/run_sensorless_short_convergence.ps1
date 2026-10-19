$ErrorActionPreference='Stop'
$base=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$folder=Join-Path $base 'runs\SMO_short_convergence_3000_once'
if(Test-Path -LiteralPath $folder){throw 'This short convergence test already started; no retries'}
$manifestFile=Join-Path $base 'milestones\convergence_short_20261019\source_manifest.json'
$binding=Get-Content -LiteralPath $manifestFile -Raw|ConvertFrom-Json
foreach($entry in $binding.files){if((Get-FileHash -LiteralPath $entry.path).Hash.ToLowerInvariant() -ne $entry.sha256){throw 'Short-test source/artifact mismatch'}}
$pref=Join-Path $base '.build\short_convergence_preferences'
if(Test-Path -LiteralPath $pref){throw 'Fresh preferences required'}
New-Item -ItemType Directory -Path $pref|Out-Null
$build=(Join-Path $base 'runs\N3R2_normal_serialized_short_once\build').Replace('\','/')
$backend=(Join-Path $base 'robust\convergence').Replace('\','/');$mFolder=$folder.Replace('\','/');$mPref=$pref.Replace('\','/')
$expression="assert(strcmpi(strrep(matlabroot,'\','/'),'D:/simulink/dev/modern/sensorless/.build/matlab_clean/R2026a_U5'));assert(strcmp(version,'26.1.0.3346908 (R2026a) Update 5'));assert(strcmpi(char(java.io.File(prefdir).getCanonicalPath),char(java.io.File('$mPref').getCanonicalPath)));addpath('$backend');execute_sensorless_short_convergence('$build','$mFolder');"
$statusFile=Join-Path $base '.build\short_convergence_launch.json'
$state=[ordered]@{scope='short_nominal_convergence';status='running';source_manifest_sha256=(Get-FileHash -LiteralPath $manifestFile).Hash.ToLowerInvariant();started_at=[DateTime]::UtcNow.ToString('o');pid=$null;exit_code=$null;exit_hex=$null;retries=0;full_R2_passed=$false}
function Save-Status {$state|ConvertTo-Json|Set-Content -LiteralPath $statusFile -Encoding utf8}
Save-Status
$savedPref=$env:MATLAB_PREFDIR
try {
 $env:MATLAB_PREFDIR=$pref
 $process=Start-Process -FilePath 'D:\simulink\dev\modern\sensorless\.build\matlab_clean\R2026a_U5\bin\matlab.exe' -WorkingDirectory 'D:\simulink\dev' -ArgumentList @('-singleCompThread','-batch',('"'+$expression+'"')) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $base '.build\short_convergence_private_stdout.log') -RedirectStandardError (Join-Path $base '.build\short_convergence_private_stderr.log') -PassThru
} finally {$env:MATLAB_PREFDIR=$savedPref}
$state.pid=$process.Id;Save-Status
$process.WaitForExit();$process.Refresh();$state.exit_code=$process.ExitCode
$state.exit_hex='0x'+([BitConverter]::ToUInt32([BitConverter]::GetBytes([int32]$state.exit_code),0)).ToString('x8')
$state.status='failed_execution'
if($state.exit_code -eq 0){
 $r=Get-Content -LiteralPath (Join-Path $folder 'record.json') -Raw|ConvertFrom-Json
 $m=Get-Content -LiteralPath (Join-Path $folder 'metrics.json') -Raw|ConvertFrom-Json
 if($r.status -eq 'passed' -and $r.native_endpoint_verified -and $r.reference_restored -and $r.main_bridge_preserved -and $m.all_passed){$state.status='passed_short_convergence'}else{$state.status='failed_checks'}
}
$state.finished_at=[DateTime]::UtcNow.ToString('o');Save-Status
foreach($entry in $binding.files){if((Get-FileHash -LiteralPath $entry.path).Hash.ToLowerInvariant() -ne $entry.sha256){throw 'Short-test source changed'}}
Write-Output ('SHORT_CONVERGENCE_STATUS='+$state.status)
