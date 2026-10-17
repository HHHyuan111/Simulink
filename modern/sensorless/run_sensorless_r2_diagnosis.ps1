param(
    [ValidateSet('r1_short_logging_check','diagnostic_combined_3000')]
    [string[]]$CaseIds=@('r1_short_logging_check','diagnostic_combined_3000'),
    [string]$Label='R1_numerical_diagnosis',
    [string]$MatlabExe='D:\DevTools\MATLAB\R2026a\bin\matlab.exe'
)
$ErrorActionPreference='Stop'
$executionVersion='safe_init_v2_explicit_state'
$remainingAttempts=@{}
# A new campaign label cannot reset this execution version's native limit.
$previous=Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'runs') -Directory -Filter 'N3R2_*'
foreach($id in $CaseIds) {
    $nativeFailures=0
    foreach($prior in $previous) {
        $priorManifest=Join-Path $prior.FullName 'campaign.json'
        if(-not (Test-Path -LiteralPath $priorManifest)) { continue }
        $priorRecord=Get-Content -LiteralPath $priorManifest -Raw | ConvertFrom-Json
        if($priorRecord.execution_version -ne $executionVersion) { continue }
        foreach($priorJob in @($priorRecord.jobs | Where-Object {$_.case_id -eq $id})) {
            $nativeFailures+=@($priorJob.attempts | Where-Object {$_.native_failure}).Count
        }
    }
    if($nativeFailures -ge 2) {
        throw "R2 native retry limit already exhausted for $id ($executionVersion). No MATLAB process started. Diagnose before creating a substantive execution revision."
    }
    $remainingAttempts[$id]=2-$nativeFailures
}
$campaign=Join-Path $PSScriptRoot ('runs/N3R2_'+$Label+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $campaign
$source=(Join-Path $PSScriptRoot 'robust/performance').Replace('\','/').Replace("'","''")
$manifest=[ordered]@{schema=1;node='N3R2';label=$Label;status='running';folder=$campaign;numerical_version='accepted R1';execution_version=$executionVersion;driver_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLower();jobs=@()}
$manifestPath=Join-Path $campaign 'campaign.json'
function Save-Manifest { $manifest | ConvertTo-Json -Depth 25 | Set-Content -LiteralPath $manifestPath -Encoding utf8 }
Save-Manifest
foreach($id in $CaseIds) {
    $job=[ordered]@{case_id=$id;status='incomplete';attempts=@();completed_folder=''}
    for($attempt=1;$attempt -le $remainingAttempts[$id];$attempt++) {
        $folder=Join-Path $campaign ($id+'_attempt_'+$attempt)
        $target=$folder.Replace('\','/').Replace("'","''")
        $expression="addpath('$source');validate_sensorless_r2_case('$id','$target');"
        if($id -eq 'r1_short_logging_check') { $expression+="verify_sensorless_r2_logging('$target');" }
        $log=Join-Path $campaign ($id+'_attempt_'+$attempt+'_console.log')
        $launcher=Join-Path $campaign ($id+'_attempt_'+$attempt+'_launcher.log')
        & $MatlabExe -singleCompThread -batch $expression -logfile $log 2>&1 | Tee-Object -FilePath $launcher | Out-Host
        $code=$LASTEXITCODE;$native=($code -in @(-1073741819,-1073741795)) -or ((Get-Content -LiteralPath $launcher -Raw) -match '0xc0000005|0xc000001d')
        $job.attempts+=,@{exit_code=$code;native_failure=$native;expression=$expression;folder=$folder;logfile=$log;launcher_log=$launcher}
        if($code -eq 0) {
            $r=Get-Content -LiteralPath (Join-Path $folder 'record.json') -Raw | ConvertFrom-Json
            $job.status=$r.status;$job.completed_folder=$folder;break
        }
        if(-not $native) {
            $manifest.jobs+=,$job;$manifest.status='failed_execution';Save-Manifest;throw "R2 script/numerical execution failure retained: $launcher"
        }
    }
    $manifest.jobs+=,$job;Save-Manifest
    if(-not $job.completed_folder) { $manifest.status='native_attempts_exhausted';Save-Manifest;throw "R2 native retry limit reached: $id" }
}
$manifest.status='completed_passed'
if(@($manifest.jobs | Where-Object {$_.status -ne 'passed'}).Count) { $manifest.status='completed_performance_failed_needs_diagnosis' }
Save-Manifest
Write-Output "N3R2_DIAGNOSIS_CAMPAIGN=$campaign"
