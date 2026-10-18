$ErrorActionPreference='Stop'
$base=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$root=Join-Path $base 'runs\N3R2_continuous_codegen_short_once'
if(Test-Path -LiteralPath $root){throw 'Continuous bridge main short already started; zero retry.'}
$py='C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$proof=Get-Content -LiteralPath (Join-Path $base 'runs\N3R2_freewheel_inheritance_once\report.json') -Raw|ConvertFrom-Json
if(-not ($proof.all_passed -and $proof.normal_comparison.all_passed -and $proof.rapid_comparison.all_passed)){throw 'Bridge component prerequisite failed.'}
$derivation=Get-Content -LiteralPath (Join-Path $base 'robust\continuous_codegen\derivation.json') -Raw|ConvertFrom-Json
foreach($property in $derivation.outputs_sha256.PSObject.Properties){
 $file=Join-Path $base ('robust\continuous_codegen\'+$property.Name)
 if((Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant() -ne $property.Value){throw 'Derived source changed.'}
}
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Frozen candidate integrity failed.'}
New-Item -ItemType Directory -Path $root|Out-Null
$manifest=[ordered]@{schema=1;node='N3R2';execution_version='continuous_inherited_codegen_adapter';campaign_type='development_continuous_codegen_strict_short';status='running';R2_passed=$false;simulation_retries=0;jobs=@()}
function Save-Manifest {$manifest|ConvertTo-Json -Depth 16|Set-Content -LiteralPath (Join-Path $root 'campaign.json') -Encoding utf8}
Save-Manifest
$backend=(Join-Path $base 'robust\continuous_codegen').Replace('\','/');$format=(Join-Path $base 'robust\execution_v8').Replace('\','/')
$build=Join-Path $root 'build';$execution=Join-Path $root 'r1_short_logging_check_attempt_1'
foreach($stage in @('build','execute')){
 $pref=Join-Path $base ('.build\continuous_codegen_short_preferences\'+$stage)
 if(Test-Path -LiteralPath $pref){throw 'Fresh private preferences required.'}
 New-Item -ItemType Directory -Path $pref -Force|Out-Null
 $mPref=$pref.Replace('\','/');$mBuild=$build.Replace('\','/');$mExecution=$execution.Replace('\','/')
 $expression="assert(strcmpi(char(java.io.File(prefdir).getCanonicalPath),char(java.io.File('$mPref').getCanonicalPath)));addpath('$backend','$format');"
 if($stage -eq 'build'){$expression+="build_sensorless_r2_continuous('r1_short_logging_check','$mBuild');"}
 else {
  $dependency=Get-Content -LiteralPath (Join-Path $base 'milestones\N3R2\isolated_compiler_20261018.json') -Raw|ConvertFrom-Json
  $mRoot=$dependency.compiler_root.Replace('\','/');$expression+="setenv('MW_MINGW64_LOC','$mRoot');mex('-setup','C');mex('-setup','C++');execute_sensorless_r2_continuous('$mBuild','$mExecution');normalize_sensorless_r2_v8_archive('$mExecution');"
 }
 $job=[ordered]@{stage=$stage;case_id='r1_short_logging_check';status='running';exit_code=$null;folder=$(if($stage -eq 'build'){$build}else{$execution});attempts=@();started_at=[DateTime]::UtcNow.ToString('o')}
 $manifest.jobs+=,$job;Save-Manifest;$savedPref=$env:MATLAB_PREFDIR
 try {
  $env:MATLAB_PREFDIR=$pref
  $process=Start-Process -FilePath 'D:\DevTools\MATLAB\R2026a\bin\matlab.exe' -ArgumentList @('-singleCompThread','-batch',('"'+$expression+'"')) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root ($stage+'_private_stdout.log')) -RedirectStandardError (Join-Path $root ($stage+'_private_stderr.log')) -PassThru
 } finally {$env:MATLAB_PREFDIR=$savedPref}
 $process.WaitForExit();$process.Refresh();$job.exit_code=$process.ExitCode;$job.status='exited'
 $job.attempts=@(@{folder=$job.folder;exit_code=$job.exit_code;native_failure=$false;launcher_log=(Join-Path $root ($stage+'_private_stdout.log'));logfile=(Join-Path $root ($stage+'_private_stderr.log'))});Save-Manifest
 if($job.exit_code -ne 0){$manifest.status='stopped_execution_failure';Save-Manifest;break}
 $r=Get-Content -LiteralPath (Join-Path $job.folder 'record.json') -Raw|ConvertFrom-Json
 $passed=$r.status -eq 'passed' -and $r.bridge_metadata_restored
 if($stage -eq 'execute'){
  $c=Get-Content -LiteralPath (Join-Path $execution 'log_format\v7_complete_log_comparison.json') -Raw|ConvertFrom-Json
  $passed=$passed -and $c.all_passed -and $c.logs -eq 96 -and $c.all_Time_Data_equal
 }
 if(-not $passed){$manifest.status='stopped_check_failure';Save-Manifest;break}
 $job.status='passed';Save-Manifest
}
if(@($manifest.jobs|Where-Object {$_.status -eq 'passed'}).Count -eq 2){$manifest.status='completed_passed';Save-Manifest}
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Frozen candidate integrity failed after short.'}
Write-Output ('CONTINUOUS_CODEGEN_SHORT_STATUS='+$manifest.status)
