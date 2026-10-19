$ErrorActionPreference='Stop'
$base=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$root=Join-Path $base 'runs\N3R2_clean_normal_qualification_once'
if(Test-Path -LiteralPath $root){throw 'Normal serialized qualification already started; no retries.'}
$py='C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$guard=Join-Path $base 'robust\normal_serialized\clean_qualification.py'
& $py $guard verify
if($LASTEXITCODE -ne 0){throw 'Qualification source guard failed.'}
$manifestFile=Join-Path $base 'milestones\N3R2\clean_qualification_20261019\qualification_sources.json'
New-Item -ItemType Directory -Path $root|Out-Null
$build=Join-Path $base 'runs\N3R2_normal_serialized_short_once\build';$first=Join-Path $root 'short_1';$second=Join-Path $root 'short_2'
$manifest=[ordered]@{schema=1;node='N3R2';execution_version='normal_serialized_parent_and_observer';environment='new_official_activated_installation';campaign_type='two_independent_clean_normal_qualification_shorts';status='running';R2_passed=$false;retries=0;source_manifest_sha256=(Get-FileHash -LiteralPath $manifestFile).Hash.ToLowerInvariant();jobs=@()}
foreach($name in @('short_1','short_2','compare')){
 $folder=Join-Path $root $name
 $manifest.jobs+=,[ordered]@{stage=$name;case_id='r1_short_logging_check';folder=$folder;status='pending';exit_code=$null;exit_hex=$null;native_failure=$null;started_at=$null;finished_at=$null}
}
function Save-Manifest {$manifest|ConvertTo-Json -Depth 15|Set-Content -LiteralPath (Join-Path $root 'campaign.json') -Encoding utf8}
Save-Manifest
$backend=(Join-Path $base 'robust\normal_serialized').Replace('\','/')
$mBuild=$build.Replace('\','/');$mFirst=$first.Replace('\','/');$mSecond=$second.Replace('\','/')
foreach($job in $manifest.jobs){
 & $py $guard verify
 if($LASTEXITCODE -ne 0){$manifest.status='stopped_integrity_failure';Save-Manifest;break}
 $pref=Join-Path $base ('.build\clean_normal_qualification_preferences\'+$job.stage)
 if(Test-Path -LiteralPath $pref){throw 'Fresh isolated preferences required.'}
 New-Item -ItemType Directory -Path $pref -Force|Out-Null
 $mPref=$pref.Replace('\','/');$mFolder=$job.folder.Replace('\','/')
 $expression="assert(strcmpi(strrep(matlabroot,'\','/'),'D:/simulink/dev/modern/sensorless/.build/matlab_clean/R2026a_U5'));assert(strcmpi(char(java.io.File(prefdir).getCanonicalPath),char(java.io.File('$mPref').getCanonicalPath)));addpath('$backend');"
 switch($job.stage){
  'compare' {$mComparison=(Join-Path $root 'cross_process_comparison.json').Replace('\','/');$expression+="compare_sensorless_r2_normal_serialized_shorts('$mFirst','$mSecond','$mComparison');"}
  default {$expression+="execute_sensorless_r2_normal_serialized('$mBuild','$mFolder');normalize_sensorless_r2_normal_serialized_archive('$mFolder');"}
 }
 $job.status='running';$job.started_at=[DateTime]::UtcNow.ToString('o');Save-Manifest;$savedPref=$env:MATLAB_PREFDIR
 try {
  $env:MATLAB_PREFDIR=$pref
  $process=Start-Process -FilePath 'D:\simulink\dev\modern\sensorless\.build\matlab_clean\R2026a_U5\bin\matlab.exe' -ArgumentList @('-singleCompThread','-batch',('"'+$expression+'"')) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root ($job.stage+'_private_stdout.log')) -RedirectStandardError (Join-Path $root ($job.stage+'_private_stderr.log')) -PassThru
 } finally {$env:MATLAB_PREFDIR=$savedPref}
 $process.WaitForExit();$process.Refresh();$job.exit_code=$process.ExitCode;$job.finished_at=[DateTime]::UtcNow.ToString('o')
 $unsigned=[BitConverter]::ToUInt32([BitConverter]::GetBytes([int32]$job.exit_code),0);$job.exit_hex='0x'+$unsigned.ToString('x8')
 $job.native_failure=$job.exit_hex -in @('0xc0000005','0xc0000409','0xc000001d','0x80000003');$job.status='exited';Save-Manifest
 if($job.exit_code -ne 0){$manifest.status='stopped_execution_failure';Save-Manifest;break}
 $passed=$false
 if($job.stage -eq 'compare'){$c=Get-Content -LiteralPath (Join-Path $root 'cross_process_comparison.json') -Raw|ConvertFrom-Json;$passed=$c.all_passed -and $c.logs -eq 96 -and $c.all_Time_Data_class_dimensions_equal}
 else {
  $r=Get-Content -LiteralPath (Join-Path $job.folder 'record.json') -Raw|ConvertFrom-Json
  $passed=$r.status -eq 'passed' -and $r.main_bridge_preserved -and $r.reference_restored
  if($job.stage -ne 'build'){
   $c=Get-Content -LiteralPath (Join-Path $job.folder 'log_format\v7_complete_log_comparison.json') -Raw|ConvertFrom-Json
   $passed=$passed -and $r.native_endpoint_verified -and $c.all_passed -and $c.logs -eq 96 -and $c.all_Time_Data_equal
  }
 }
 if(-not $passed){$manifest.status='stopped_check_failure';Save-Manifest;break}
 $job.status='passed';Save-Manifest
}
if(@($manifest.jobs|Where-Object {$_.status -eq 'passed'}).Count -eq 3){$manifest.status='completed_passed';Save-Manifest}
& $py $guard verify
if($LASTEXITCODE -ne 0){throw 'Qualification source guard failed after exit.'}
Write-Output ('CLEAN_NORMAL_QUALIFICATION_STATUS='+$manifest.status)
