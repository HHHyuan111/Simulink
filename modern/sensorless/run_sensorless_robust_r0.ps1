param([string]$MatlabExe='D:\DevTools\MATLAB\R2026a\bin\matlab.exe')
$ErrorActionPreference='Stop'
$id='N3R0_pipeline_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid()
$campaign=Join-Path $PSScriptRoot ('runs/'+$id)
$null=New-Item -ItemType Directory -Path $campaign
$manifest=[ordered]@{schema=1;node='N3R0';status='running';folder=$campaign;startup_options=@('-singleCompThread','-batch');driver_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLower();jobs=@()}
$manifestPath=Join-Path $campaign 'campaign.json'
$robust=(Join-Path $PSScriptRoot 'robust').Replace('\','/').Replace("'","''")
function Save-Manifest { $manifest | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $manifestPath -Encoding utf8 }
function Run-Job([string]$label,[string]$firstFolder='',[string]$secondFolder='') {
    $job=[ordered]@{label=$label;status='incomplete';attempts=@();completed_folder=''}
    for($attempt=1;$attempt -le 2;$attempt++) {
        $folder=Join-Path $campaign ($label+'_attempt_'+$attempt)
        $target=$folder.Replace('\','/').Replace("'","''")
        $expression="addpath('$robust');validate_sensorless_robust_r0('$target');"
        if($label -eq 'verification') {
            $a=$firstFolder.Replace('\','/').Replace("'","''");$b=$secondFolder.Replace('\','/').Replace("'","''")
            $expression="addpath('$robust');verify_sensorless_robust_r0('$a','$b');"
        }
        $log=Join-Path $campaign ($label+'_attempt_'+$attempt+'_console.log')
        $launcherLog=Join-Path $campaign ($label+'_attempt_'+$attempt+'_launcher.log')
        & $MatlabExe -singleCompThread -batch $expression -logfile $log 2>&1 | Tee-Object -FilePath $launcherLog | Out-Host
        $code=$LASTEXITCODE
        $native=($code -in @(-1073741819,-1073741795)) -or ((Get-Content -LiteralPath $launcherLog -Raw) -match '0xc0000005|0xc000001d')
        $launch=[ordered]@{exit_code=$code;native_failure=$native;matlab_exe=$MatlabExe;startup_options=$manifest.startup_options;logfile=$log;launcher_log=$launcherLog;expression=$expression}
        $job.attempts+=,$launch
        if(Test-Path -LiteralPath $folder) { $launch | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $folder 'launcher_record.json') -Encoding utf8 }
        if($code -eq 0) {
            $job.status='passed';$job.completed_folder=$folder
            if($label -eq 'verification') { $job.completed_folder=$secondFolder }
            break
        }
        if(-not $native) {
            $manifest.jobs+=,$job;$manifest.status='failed_execution';Save-Manifest
            throw "R0 numerical/script failure retained: $launcherLog"
        }
    }
    $manifest.jobs+=,$job;Save-Manifest
    if($job.status -ne 'passed') { $manifest.status='native_attempts_exhausted';Save-Manifest;throw "R0 native retry limit reached: $label" }
    return $job.completed_folder
}
Save-Manifest
$first=Run-Job 'first'
$second=Run-Job 'replay'
$null=Run-Job 'verification' $first $second
$manifest.status='passed';Save-Manifest
Write-Output "N3R0_CAMPAIGN_FOLDER=$campaign"
