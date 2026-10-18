$ErrorActionPreference='Stop'
$base=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$root=Join-Path $base 'runs\N3R2_portable_model_once'
if(Test-Path -LiteralPath $root){throw 'Portable model handoff already started; no retry.'}
$py='C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$fixture=Get-Content -LiteralPath (Join-Path $base 'runs\N3R2_workspace_persistence_once\report.json') -Raw|ConvertFrom-Json
if(-not $fixture.all_passed){throw 'Persistence prerequisite not passed.'}
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Frozen source integrity failed.'}
New-Item -ItemType Directory -Path $root|Out-Null
$manifest=[ordered]@{kind='portable_owned_handoff';status='running';simulation_starts=0;R2_passed=$false;jobs=@()}
function Save-Manifest {$manifest|ConvertTo-Json -Depth 14|Set-Content -LiteralPath (Join-Path $root 'manifest.json') -Encoding utf8}
Save-Manifest
$build=Join-Path $root 'build';$verify=Join-Path $root 'reopen';$backend=(Join-Path $base 'robust\portable_model').Replace('\','/')
foreach($stage in @('build','reopen')){
 $pref=Join-Path $base ('.build\portable_handoff_preferences\'+$stage)
 if(Test-Path -LiteralPath $pref){throw 'Fresh isolated preferences required.'}
 New-Item -ItemType Directory -Path $pref -Force|Out-Null
 $mBuild=$build.Replace('\','/');$mVerify=$verify.Replace('\','/');$mPref=$pref.Replace('\','/')
 $call="build_sensorless_r2_portable('$mBuild');"
 if($stage -eq 'reopen'){$call="verify_sensorless_r2_portable('$mBuild','$mVerify');"}
 $expression="assert(strcmpi(char(java.io.File(prefdir).getCanonicalPath),char(java.io.File('$mPref').getCanonicalPath)));addpath('$backend');$call"
 $job=[ordered]@{stage=$stage;status='running';exit_code=$null;started_at=[DateTime]::UtcNow.ToString('o');private_preferences=$pref}
 $manifest.jobs+=,$job;Save-Manifest;$savedPref=$env:MATLAB_PREFDIR
 try {
  $env:MATLAB_PREFDIR=$pref
  $process=Start-Process -FilePath 'D:\DevTools\MATLAB\R2026a\bin\matlab.exe' -ArgumentList @('-singleCompThread','-batch',('"'+$expression+'"')) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root ($stage+'_private_stdout.log')) -RedirectStandardError (Join-Path $root ($stage+'_private_stderr.log')) -PassThru
 } finally {$env:MATLAB_PREFDIR=$savedPref}
 $process.WaitForExit();$process.Refresh();$job.exit_code=$process.ExitCode;$job.status='exited';Save-Manifest
 if($job.exit_code -ne 0){$manifest.status='stopped_execution_failure';Save-Manifest;break}
 if($stage -eq 'build'){$value=Get-Content -LiteralPath (Join-Path $build 'record.json') -Raw|ConvertFrom-Json;$passed=$value.status -eq 'passed'}
 else {$value=Get-Content -LiteralPath (Join-Path $verify 'report.json') -Raw|ConvertFrom-Json;$passed=$value.all_passed}
 if(-not $passed){$manifest.status='stopped_check_failure';Save-Manifest;break}
 $job.status='passed';Save-Manifest
}
if(@($manifest.jobs|Where-Object {$_.status -eq 'passed'}).Count -eq 2){$manifest.status='completed_passed';Save-Manifest}
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Frozen source integrity failed after handoff.'}
Write-Output ('PORTABLE_HANDOFF_STATUS='+$manifest.status)
