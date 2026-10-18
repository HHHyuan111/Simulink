$ErrorActionPreference='Stop'
$base=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$package=Join-Path $base 'runs\N3R2_child_only_build_bundle'
$folder=Join-Path $base 'runs\N3R2_child_only_build_once'
$launch=Join-Path $base 'runs\N3R2_child_only_build_launch.json'
if((Test-Path -LiteralPath $folder) -or (Test-Path -LiteralPath $launch)){throw 'Standalone child diagnostic already started; no retry.'}
$pref=Join-Path $base '.build\child_only_build_preferences'
if(Test-Path -LiteralPath $pref){throw 'Fresh preferences required.'}
New-Item -ItemType Directory -Path $pref|Out-Null
$dependency=Get-Content -LiteralPath (Join-Path $package 'compiler_dependency.json') -Raw|ConvertFrom-Json
$job=[ordered]@{kind='standalone_child_only_build';status='running';folder=$folder;package=$package;simulation_starts=0;native_retries=0;exit_code=$null;manifest_sha256=(Get-FileHash -LiteralPath (Join-Path $package 'manifest.json')).Hash.ToLowerInvariant();started_at=[DateTime]::UtcNow.ToString('o');R2_passed=$false}
$job|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $launch -Encoding utf8
$mRoot=$dependency.compiler_root.Replace('\','/');$mPref=$pref.Replace('\','/');$mPackage=$package.Replace('\','/');$mFolder=$folder.Replace('\','/')
$expression="assert(strcmpi(char(java.io.File(prefdir).getCanonicalPath),char(java.io.File('$mPref').getCanonicalPath)));setenv('MW_MINGW64_LOC','$mRoot');mex('-setup','C');mex('-setup','C++');addpath('$mPackage');reproduce_sensorless_r2_child_build('$mFolder');"
$savedPref=$env:MATLAB_PREFDIR
try {
 $env:MATLAB_PREFDIR=$pref
 $process=Start-Process -FilePath 'D:\DevTools\MATLAB\R2026a\bin\matlab.exe' -ArgumentList @('-singleCompThread','-batch',('"'+$expression+'"')) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $base 'runs\N3R2_child_only_build_private_stdout.log') -RedirectStandardError (Join-Path $base 'runs\N3R2_child_only_build_private_stderr.log') -PassThru
} finally {$env:MATLAB_PREFDIR=$savedPref}
$process.WaitForExit();$process.Refresh();$job.exit_code=$process.ExitCode;$job.status='stopped_execution_failure'
if($job.exit_code -eq 0){$r=Get-Content -LiteralPath (Join-Path $folder 'report.json') -Raw|ConvertFrom-Json;if($r.all_passed){$job.status='completed_passed'}else{$job.status='stopped_check_failure'}}
$job|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $launch -Encoding utf8
$py='C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Frozen candidate integrity failed.'}
Write-Output ('CHILD_ONLY_BUILD_STATUS='+$job.status)
