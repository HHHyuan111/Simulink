$ErrorActionPreference='Stop'
$base=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$folder=Join-Path $base 'runs\N3R2_stopped_bootstrap_once'
$launch=Join-Path $base 'runs\N3R2_stopped_bootstrap_launch.json'
if((Test-Path -LiteralPath $folder) -or (Test-Path -LiteralPath $launch)){throw 'Isolated compiler fixture already started; no repeat.'}
$py='C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Frozen source integrity failed.'}
$dependency=Get-Content -LiteralPath (Join-Path $base 'milestones\N3R2\isolated_compiler_20261018.json') -Raw|ConvertFrom-Json
$probe=Join-Path $PSScriptRoot 'probe_sensorless_r2_stopped_bootstrap.m'
if((Get-FileHash -LiteralPath $probe).Hash.ToLower() -ne '0e7caab1ea9618fabebfe61682a50371039a2fb9cd15788981166a6d7b9f85ba'){throw 'Fixture source changed.'}
$pref=Join-Path $base '.build\stopped_bootstrap_preferences'
if(Test-Path -LiteralPath $pref){throw 'Fresh private preferences required.'}
New-Item -ItemType Directory -Path $pref|Out-Null
function Default-CompilerHashes {
 $root=Join-Path $env:APPDATA 'MathWorks\MATLAB'
 $values=@{}
 if(Test-Path -LiteralPath $root){
  foreach($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.xml'){
   if($file.Name -match 'mex|compiler'){$values[$file.FullName]=(Get-FileHash -LiteralPath $file.FullName).Hash.ToLower()}
  }
 }
 return $values
}
$before=Default-CompilerHashes
$job=[ordered]@{kind='stopped_preamble_isolation';status='running';started_at=[DateTime]::UtcNow.ToString('o');folder=$folder;private_preferences=$pref;default_compiler_hashes_before=$before;exit_code=$null;native_retries=0;host_settings_changed=$false}
$job|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $launch -Encoding utf8
$psPref=$env:MATLAB_PREFDIR
try {
 $env:MATLAB_PREFDIR=$pref
 $mPref=$pref.Replace('\','/');$mRoot=$dependency.compiler_root.Replace('\','/');$mFolder=$folder.Replace('\','/');$mScripts=$PSScriptRoot.Replace('\','/')
 $command="assert(strcmpi(char(java.io.File(prefdir).getCanonicalPath),char(java.io.File('$mPref').getCanonicalPath)));setenv('MW_MINGW64_LOC','$mRoot');mex('-setup','C');mex('-setup','C++');addpath('$mScripts');probe_sensorless_r2_stopped_bootstrap('$mFolder');"
 $stdout=Join-Path $base 'runs\N3R2_stopped_bootstrap_private_stdout.log';$stderr=Join-Path $base 'runs\N3R2_stopped_bootstrap_private_stderr.log'
 $process=Start-Process -FilePath 'D:\DevTools\MATLAB\R2026a\bin\matlab.exe' -ArgumentList @('-singleCompThread','-batch',('"'+$command+'"')) -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
} finally { $env:MATLAB_PREFDIR=$psPref }
$process.WaitForExit();$process.Refresh();$job.exit_code=$process.ExitCode;$job.status='exited';$job.default_compiler_hashes_after=Default-CompilerHashes
$job.default_compiler_preferences_unchanged=($before.Count -eq $job.default_compiler_hashes_after.Count)
foreach($key in $before.Keys){if($job.default_compiler_hashes_after[$key] -ne $before[$key]){$job.default_compiler_preferences_unchanged=$false}}
$job|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $launch -Encoding utf8
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Frozen source integrity failed after diagnostic.'}
if(-not $job.default_compiler_preferences_unchanged){throw 'Default compiler preferences changed.'}
Write-Output ('ISOLATED_COMPILER_TOY_EXIT='+$job.exit_code)
if($job.exit_code -ne 0){throw 'Compiler fixture failed; no retry.'}
