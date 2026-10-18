$ErrorActionPreference='Stop'
# Unelevated diagnostic: same saved model and execution sources, at most one sim.
$base=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$installRoot=Join-Path $base '.build\matlab_clean'
$target=Join-Path $installRoot 'R2026a_U5'
$setup=Get-Content -LiteralPath (Join-Path $installRoot 'installation_status.json') -Raw|ConvertFrom-Json
if($setup.status -ne 'installed_pending_runtime_preflight'){throw 'Installation must complete successfully first'}
$root=Join-Path $base 'runs\N3R2_clean_install_control_once'
if(Test-Path -LiteralPath $root){throw 'Diagnostic already started; no retries'}
$py='C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$guard=Join-Path $base 'robust\normal_serialized\qualification_sources.py'
& $py $guard verify
if($LASTEXITCODE -ne 0){throw 'Bound source mismatch'}
$protocolFile=Join-Path $base 'contracts\nonideal_r2_clean_install_control.json'
$protocol=Get-Content -LiteralPath $protocolFile -Raw|ConvertFrom-Json
$diagnosticSources=Join-Path $base 'milestones\N3R2\clean_install_20261018\pre_execution_sources.json'
$sourceMap=Get-Content -LiteralPath $diagnosticSources -Raw|ConvertFrom-Json
foreach($entry in $sourceMap.files){
 if((Get-FileHash -LiteralPath (Join-Path $base $entry.path)).Hash.ToLowerInvariant() -ne $entry.sha256){throw 'Diagnostic source mismatch'}
}
foreach($item in @(@{path=$protocol.artifacts.parent_file;hash=$protocol.artifacts.parent_sha256},@{path=$protocol.artifacts.child_file;hash=$protocol.artifacts.child_sha256},@{path=(Join-Path $protocol.artifacts.build_folder 'handoff.mat');hash=$protocol.artifacts.handoff_sha256})){
 if((Get-FileHash -LiteralPath $item.path).Hash.ToLowerInvariant() -ne $item.hash){throw 'Saved artifact mismatch'}
}
New-Item -ItemType Directory -Path $root|Out-Null
$manifest=[ordered]@{schema=1;type='same_host_same_version_installation_diagnostic';status='preflight';R2_passed=$false;retries=0;maximum_sim_calls=1;simulation_job_launched=$false;protocol_sha256=(Get-FileHash -LiteralPath $protocolFile).Hash.ToLowerInvariant();diagnostic_sources_sha256=(Get-FileHash -LiteralPath $diagnosticSources).Hash.ToLowerInvariant();jobs=@()}
function Save-Manifest {$manifest|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $root 'campaign.json') -Encoding utf8}
Save-Manifest
[xml]$version=Get-Content -LiteralPath (Join-Path $target 'VersionInfo.xml') -Raw
if($version.MathWorks_version_info.version -ne '26.1.0.3346908' -or $version.MathWorks_version_info.description -ne 'Update 5'){$manifest.status='stopped_version_mismatch';Save-Manifest;throw 'Exact runtime mismatch'}
$previous=Get-Content -LiteralPath (Join-Path $base 'milestones\N3R2\crash_context_20261018\installation_observation.json') -Raw|ConvertFrom-Json
$binaries=@()
foreach($binary in $previous.binaries){
 $fresh=Join-Path $target ('bin\win64\'+$binary.name)
 $signature=Get-AuthenticodeSignature -LiteralPath $fresh
 $newHash=(Get-FileHash -LiteralPath $fresh).Hash.ToLowerInvariant()
 $oldHash=(Get-FileHash -LiteralPath $binary.path).Hash.ToLowerInvariant()
 $binaries+=,[ordered]@{name=$binary.name;fresh_signature=$signature.Status.ToString();fresh_sha256=$newHash;old_sha256=$oldHash;bytes_equal=($newHash -eq $oldHash)}
 if($signature.Status -ne 'Valid'){$manifest.status='stopped_binary_signature_failure';Save-Manifest;throw 'Invalid fresh binary signature'}
}
$binaries|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $root 'binary_comparison.json') -Encoding utf8
$diag=$PSScriptRoot.Replace('\','/');$backend=(Join-Path $base 'robust\normal_serialized').Replace('\','/')
$build=$protocol.artifacts.build_folder.Replace('\','/')
foreach($stage in @('runtime_preflight','short_once')){
 $pref=Join-Path $installRoot ('preferences\'+$stage)
 if(Test-Path -LiteralPath $pref){throw 'Fresh private preferences required'}
 New-Item -ItemType Directory -Path $pref -Force|Out-Null
 $folder=Join-Path $root $stage;$mFolder=$folder.Replace('\','/');$mPref=$pref.Replace('\','/');$mTarget=$target.Replace('\','/')
 $expression="assert(strcmpi(char(java.io.File(prefdir).getCanonicalPath),char(java.io.File('$mPref').getCanonicalPath)));assert(strcmpi(char(java.io.File(matlabroot).getCanonicalPath),char(java.io.File('$mTarget').getCanonicalPath)));assert(strcmp(version,'26.1.0.3346908 (R2026a) Update 5'));"
 if($stage -eq 'runtime_preflight'){$expression+="addpath('$diag');preflight_sensorless_r2_clean_matlab('$mFolder','$mTarget','$mPref');"}
 else {$expression+="addpath('$backend');execute_sensorless_r2_normal_serialized('$build','$mFolder');normalize_sensorless_r2_normal_serialized_archive('$mFolder');";$manifest.simulation_job_launched=$true}
 $job=[ordered]@{stage=$stage;status='running';pid=$null;exit_code=$null;exit_hex=$null;started_at=[DateTime]::UtcNow.ToString('o');finished_at=$null}
 $manifest.jobs+=,$job;Save-Manifest
 $savedPref=$env:MATLAB_PREFDIR
 try {
  $env:MATLAB_PREFDIR=$pref
  $process=Start-Process -FilePath (Join-Path $target 'bin\matlab.exe') -WorkingDirectory 'D:\simulink\dev' -ArgumentList @('-singleCompThread','-batch',('"'+$expression+'"')) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root ($stage+'_private_stdout.log')) -RedirectStandardError (Join-Path $root ($stage+'_private_stderr.log')) -PassThru
 } finally {$env:MATLAB_PREFDIR=$savedPref}
 $job.pid=$process.Id;Save-Manifest
 $process.WaitForExit();$process.Refresh();$job.exit_code=$process.ExitCode;$job.finished_at=[DateTime]::UtcNow.ToString('o')
 $job.exit_hex='0x'+([BitConverter]::ToUInt32([BitConverter]::GetBytes([int32]$job.exit_code),0)).ToString('x8');$job.status='exited';Save-Manifest
 if($job.exit_code -ne 0){$manifest.status='stopped_execution_failure';Save-Manifest;break}
 $r=Get-Content -LiteralPath (Join-Path $folder 'report.json') -Raw|ConvertFrom-Json
 $passed=$r.all_passed
 if($stage -eq 'short_once'){
  $r=Get-Content -LiteralPath (Join-Path $folder 'record.json') -Raw|ConvertFrom-Json
  $c=Get-Content -LiteralPath (Join-Path $folder 'log_format\v7_complete_log_comparison.json') -Raw|ConvertFrom-Json
  $passed=$passed -and $r.status -eq 'passed' -and $r.native_endpoint_verified -and $r.reference_restored -and $r.main_bridge_preserved -and $c.all_passed -and $c.logs -eq 96 -and $c.all_Time_Data_equal
 }
 if(-not $passed){$manifest.status='stopped_check_failure';Save-Manifest;break}
 $job.status='passed';Save-Manifest
}
if(@($manifest.jobs|Where-Object {$_.status -eq 'passed'}).Count -eq 2){$manifest.status='diagnostic_passed_not_R2_qualified';Save-Manifest}
& $py $guard verify
if($LASTEXITCODE -ne 0){throw 'Post-run bound source mismatch'}
Write-Output ('CLEAN_INSTALL_CONTROL_STATUS='+$manifest.status)
