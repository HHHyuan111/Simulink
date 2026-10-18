param()
$ErrorActionPreference='Stop'
$python='C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$checker=Join-Path $PSScriptRoot 'robust/formal_r2/candidate.py'
$candidatePath=Join-Path $PSScriptRoot 'milestones/N3R2/final_candidate.json'
& $python $checker verify
if($LASTEXITCODE -ne 0){throw 'Frozen candidate verification failed. No simulation started.'}
$candidate=Get-Content -LiteralPath $candidatePath -Raw | ConvertFrom-Json
$candidateSha=(Get-FileHash -LiteralPath $candidatePath).Hash.ToLower()
$runs=Join-Path $PSScriptRoot 'runs'
foreach($previous in Get-ChildItem -LiteralPath $runs -Directory -Filter 'N3R2_*') {
 $file=Join-Path $previous.FullName 'campaign.json';if(-not(Test-Path -LiteralPath $file)){continue}
 $prior=Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
 if($prior.status -eq 'running'){throw ('Active campaign exists: '+$previous.Name)}
 if($prior.campaign_type -eq 'formal_frozen_candidate_matrix' -and $prior.execution_version -eq $candidate.execution_version){throw 'Formal matrix already started for this implementation. Repeated matrices are forbidden.'}
}
$campaign=Join-Path $runs ('N3R2_formal_'+$candidateSha.Substring(0,8)+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $campaign
Copy-Item -LiteralPath $candidatePath -Destination (Join-Path $campaign 'frozen_candidate.json')
$manifest=[ordered]@{schema=1;node='N3R2';campaign_type='formal_frozen_candidate_matrix';execution_version=$candidate.execution_version;candidate_sha256=$candidateSha;folder=$campaign;status='running';formal_retries=0;formal_case_order=@($candidate.formal_case_order);jobs=@();remaining_cases=@($candidate.formal_case_order);R2_passed=$false;R3_started=$false}
function Save-Manifest {$manifest | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $campaign 'campaign.json') -Encoding utf8}
Save-Manifest
$source=(Join-Path $PSScriptRoot 'robust/model_reference').Replace('\','/').Replace("'","''")
$support=(Join-Path $PSScriptRoot 'robust/execution_v8').Replace('\','/').Replace("'","''")
foreach($id in $candidate.formal_case_order) {
 & $python $checker verify
 if($LASTEXITCODE -ne 0 -or (Get-FileHash -LiteralPath $candidatePath).Hash.ToLower() -ne $candidateSha){$manifest.status='stopped_integrity_failure';Save-Manifest;throw 'Candidate changed before formal start.'}
 $folder=Join-Path $campaign ($id+'_attempt_1');if(Test-Path -LiteralPath $folder){throw 'Formal attempt folder exists.'}
 $target=$folder.Replace('\','/').Replace("'","''")
 $expression="addpath('$source','$support');validate_sensorless_r2_reference_case('$id','$target');normalize_sensorless_r2_v8_archive('$target');"
 $started=(Get-Date).ToUniversalTime().ToString('o')
 @{case_id=$id;candidate_sha256=$candidateSha;started_at=$started;folder=$folder;formal_starts=1;formal_retries=0;expression=$expression} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $campaign ($id+'_formal_start.json')) -Encoding utf8
 $job=[ordered]@{case_id=$id;status='running';started_at=$started;attempts=@(@{folder=$folder;status='running';exit_code=$null;native_failure=$false});completed_folder='';formal_provenance=''}
 $manifest.jobs+=,$job;Save-Manifest
 $console=Join-Path $campaign ($id+'_console.log');$launcher=Join-Path $campaign ($id+'_launcher.log')
 & $candidate.matlab_executable -singleCompThread -batch $expression -logfile $console *> $launcher
 $code=$LASTEXITCODE;$job.attempts[0].exit_code=$code;$job.attempts[0].status='exited';$job.attempts[0].launcher_log=$launcher;$job.attempts[0].logfile=$console
 $job.attempts[0].native_failure=($code -in @(-1073741819,-1073741795))
 & $python $checker verify
 if($LASTEXITCODE -ne 0 -or (Get-FileHash -LiteralPath $candidatePath).Hash.ToLower() -ne $candidateSha){$job.status='failed_integrity';$manifest.status='stopped_integrity_failure';Save-Manifest;throw 'Candidate changed during formal execution.'}
 if($code -ne 0){$job.status='failed_execution';$manifest.status='stopped_execution_failure';Save-Manifest;throw ('Formal case stopped without retry: '+$id+'; retained exit '+$code)}
 & $python $checker outcome $folder
 if($LASTEXITCODE -ne 0){$job.status='failed_acceptance_or_provenance';$manifest.status='stopped_acceptance_failure';Save-Manifest;throw ('Formal acceptance/provenance failed: '+$id)}
 $job.status='passed';$job.completed_folder=$folder;$job.formal_provenance=Join-Path $folder 'formal_provenance.json'
 $manifest.remaining_cases=@($manifest.remaining_cases | Where-Object {$_ -ne $id});Save-Manifest
 Write-Output ('FORMAL_R2_CASE_PASSED='+$id)
}
& $python $checker verify
if($LASTEXITCODE -ne 0 -or (Get-FileHash -LiteralPath $candidatePath).Hash.ToLower() -ne $candidateSha){$manifest.status='stopped_final_integrity_failure';Save-Manifest;throw 'Final candidate verification failed.'}
if($manifest.jobs.Count -ne 14 -or $manifest.remaining_cases.Count -ne 0 -or @($manifest.jobs | Where-Object {$_.status -ne 'passed'}).Count){throw 'Incomplete formal matrix cannot pass.'}
$manifest.status='completed_passed';$manifest.R2_passed=$true;Save-Manifest
Write-Output ('FORMAL_R2_ALL14_PASSED='+$campaign)
