$ErrorActionPreference='Stop'
$base=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$root=Join-Path $base 'runs\N3R2_load_only_once'
if(Test-Path -LiteralPath $root){throw 'Load-only probe already started; no repeat.'}
$py='C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Frozen source changed.'}
New-Item -ItemType Directory -Path $root|Out-Null
$manifest=[ordered]@{kind='load_only_isolation';status='running';jobs=@();simulation_starts=0;R2_passed=$false}
function Save-Manifest {$manifest|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $root 'manifest.json') -Encoding utf8}
Save-Manifest
foreach($id in @('original_path','identical_copy')){
 $folder=Join-Path $root $id;$pref=Join-Path $base ('.build\load_only_preferences\'+$id)
 if(Test-Path -LiteralPath $pref){throw 'Fresh preferences required.'}
 New-Item -ItemType Directory -Path $pref -Force|Out-Null
 $job=[ordered]@{id=$id;folder=$folder;status='running';exit_code=$null;started_at=[DateTime]::UtcNow.ToString('o');private_preferences=$pref}
 $manifest.jobs+=,$job;Save-Manifest;$psPref=$env:MATLAB_PREFDIR
 try {
  $env:MATLAB_PREFDIR=$pref
  $mPref=$pref.Replace('\','/');$mScripts=$PSScriptRoot.Replace('\','/');$mFolder=$folder.Replace('\','/')
  $command="assert(strcmpi(char(java.io.File(prefdir).getCanonicalPath),char(java.io.File('$mPref').getCanonicalPath)));addpath('$mScripts');probe_sensorless_r2_load_only('$id','$mFolder');"
  $process=Start-Process -FilePath 'D:\DevTools\MATLAB\R2026a\bin\matlab.exe' -ArgumentList @('-singleCompThread','-batch',('"'+$command+'"')) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root ($id+'_private_stdout.log')) -RedirectStandardError (Join-Path $root ($id+'_private_stderr.log')) -PassThru
 } finally {$env:MATLAB_PREFDIR=$psPref}
 $process.WaitForExit();$process.Refresh();$job.exit_code=$process.ExitCode;$job.status='exited';Save-Manifest
 if($job.exit_code -ne 0){$manifest.status='stopped_execution_failure';Save-Manifest;break}
 $report=Get-Content -LiteralPath (Join-Path $folder 'report.json') -Raw|ConvertFrom-Json
 if(-not $report.all_passed){$manifest.status='stopped_check_failure';Save-Manifest;break}
 $job.status='passed';Save-Manifest
}
if(@($manifest.jobs|Where-Object {$_.status -eq 'passed'}).Count -eq 2){$manifest.status='completed_passed';Save-Manifest}
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Frozen source changed after load probe.'}
Write-Output ('LOAD_ONLY_STATUS='+$manifest.status)
