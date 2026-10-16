param([string]$MatlabExe='D:\DevTools\MATLAB\R2026a\bin\matlab.exe')
$ErrorActionPreference='Stop'
$campaign=Join-Path $PSScriptRoot ('runs/N3R1_formal_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $campaign
$candidate=Join-Path $PSScriptRoot 'milestones/N3R1/frozen_candidate.json'
if(-not(Test-Path -LiteralPath $candidate)) { throw 'Freeze candidate before formal execution.' }
$frozen=Get-Content -LiteralPath $candidate -Raw | ConvertFrom-Json
foreach($file in $frozen.files) {
    if((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $file.path) -Algorithm SHA256).Hash.ToLower() -ne $file.sha256) { throw "Frozen R1 source mismatch: $($file.path)" }
}
Copy-Item -LiteralPath $candidate -Destination (Join-Path $campaign 'frozen_candidate.json')
$manifest=[ordered]@{schema=1;node='N3R1';folder=$campaign;status='running';candidate_sha256=(Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLower();driver_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLower();startup_options=@('-singleCompThread','-batch');jobs=@()}
$manifestPath=Join-Path $campaign 'campaign.json'
$integration=(Join-Path $PSScriptRoot 'robust/integration').Replace('\','/').Replace("'","''")
function Save-Manifest { $manifest | ConvertTo-Json -Depth 25 | Set-Content -LiteralPath $manifestPath -Encoding utf8 }
function Run-Job([string]$label,[string]$caseId='',[bool]$observer=$true) {
    $job=[ordered]@{label=$label;case_id=$caseId;observer=$observer;status='incomplete';attempts=@();completed_folder=''}
    for($attempt=1;$attempt -le 2;$attempt++) {
        $folder=Join-Path $campaign ($label+'_attempt_'+$attempt)
        $target=$folder.Replace('\','/').Replace("'","''")
        $expression="addpath('$integration');validate_sensorless_v2_components('$target');"
        if($caseId) {
            $present='false';if($observer) { $present='true' }
            $expression="addpath('$integration');validate_sensorless_v2_case('$caseId','$target',$present);"
        }
        if($label -eq 'verification') { $target=$campaign.Replace('\','/').Replace("'","''");$expression="addpath('$integration');verify_sensorless_v2_campaign('$target');" }
        $log=Join-Path $campaign ($label+'_attempt_'+$attempt+'_console.log')
        $launcher=Join-Path $campaign ($label+'_attempt_'+$attempt+'_launcher.log')
        & $MatlabExe -singleCompThread -batch $expression -logfile $log 2>&1 | Tee-Object -FilePath $launcher | Out-Host
        $code=$LASTEXITCODE;$native=($code -in @(-1073741819,-1073741795)) -or ((Get-Content -LiteralPath $launcher -Raw) -match '0xc0000005|0xc000001d')
        $job.attempts+=,@{folder=$folder;exit_code=$code;native_failure=$native;expression=$expression;logfile=$log;launcher_log=$launcher}
        if($code -eq 0) {
            $job.status='passed';$job.completed_folder=$folder
            if($label -eq 'verification') { $job.completed_folder=$campaign }
            break
        }
        if(-not $native) {
            $manifest.jobs+=,$job;$manifest.status='failed_execution';Save-Manifest;throw "R1 numerical/script failure retained: $launcher"
        }
    }
    $manifest.jobs+=,$job;Save-Manifest
    if($job.status -ne 'passed') { $manifest.status='native_attempts_exhausted';Save-Manifest;throw "R1 native retry limit reached: $label" }
}
Save-Manifest
Run-Job 'component_first'
Run-Job 'component_replay'
foreach($id in @('combined','rail','window','deadline')) {
    Run-Job ($id+'_formal') $id $true
    Run-Job ($id+'_replay') $id $true
    Run-Job ($id+'_baseline') $id $false
}
Run-Job 'verification'
$manifest.status='passed';Save-Manifest
Write-Output "N3R1_CAMPAIGN_FOLDER=$campaign"
