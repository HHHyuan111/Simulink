$ErrorActionPreference='Stop'
$base=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$folder=Join-Path $base 'runs\N3R2_single_reference_logging_once'
$launch=Join-Path $base 'runs\N3R2_single_reference_logging_launch.json'
if((Test-Path -LiteralPath $folder) -or (Test-Path -LiteralPath $launch)){throw 'Single-reference logging diagnostic already started; no retry.'}
$py='C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Frozen candidate integrity failed.'}
$pref=Join-Path $base '.build\single_reference_logging_preferences'
if(Test-Path -LiteralPath $pref){throw 'Fresh preferences required.'}
New-Item -ItemType Directory -Path $pref|Out-Null
$source=Join-Path $PSScriptRoot 'probe_sensorless_r2_single_reference_logging.m'
$job=[ordered]@{kind='single_reference_logging';status='running';folder=$folder;started_at=[DateTime]::UtcNow.ToString('o');exit_code=$null;native_retries=0;probe_sha256=(Get-FileHash -LiteralPath $source).Hash.ToLowerInvariant();R2_passed=$false}
$job|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $launch -Encoding utf8
$dependency=Get-Content -LiteralPath (Join-Path $base 'milestones\N3R2\isolated_compiler_20261018.json') -Raw|ConvertFrom-Json
$mRoot=$dependency.compiler_root.Replace('\','/');$mPref=$pref.Replace('\','/');$mFolder=$folder.Replace('\','/');$mScripts=$PSScriptRoot.Replace('\','/')
$expression="assert(strcmpi(char(java.io.File(prefdir).getCanonicalPath),char(java.io.File('$mPref').getCanonicalPath)));setenv('MW_MINGW64_LOC','$mRoot');mex('-setup','C');mex('-setup','C++');addpath('$mScripts');probe_sensorless_r2_single_reference_logging('$mFolder');"
$savedPref=$env:MATLAB_PREFDIR
try {
 $env:MATLAB_PREFDIR=$pref
 $process=Start-Process -FilePath 'D:\DevTools\MATLAB\R2026a\bin\matlab.exe' -ArgumentList @('-singleCompThread','-batch',('"'+$expression+'"')) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $base 'runs\N3R2_single_reference_logging_private_stdout.log') -RedirectStandardError (Join-Path $base 'runs\N3R2_single_reference_logging_private_stderr.log') -PassThru
} finally {$env:MATLAB_PREFDIR=$savedPref}
$process.WaitForExit();$process.Refresh();$job.exit_code=$process.ExitCode;$job.status='stopped_execution_failure'
if($job.exit_code -eq 0){
 $r=Get-Content -LiteralPath (Join-Path $folder 'report.json') -Raw|ConvertFrom-Json
 if($r.all_passed){$job.status='completed_passed'}else{$job.status='stopped_check_failure'}
}
$job|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $launch -Encoding utf8
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Frozen candidate integrity failed after diagnostic.'}
Write-Output ('SINGLE_REFERENCE_LOGGING_STATUS='+$job.status)
