param(
    [string[]]$CaseIds=@(),
    [string]$Label='formal',
    [string]$ReplayOf='',
    [switch]$IncludeBaselines,
    [string]$MatlabExe='D:\DevTools\MATLAB\R2026a\bin\matlab.exe'
)
$ErrorActionPreference='Stop'
$plan=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'contracts/test_plan_v1.json') -Raw | ConvertFrom-Json
$selected=@($plan.cases | Where-Object { $_.node -eq 'N3' })
if($CaseIds.Count -gt 0) { $selected=@($selected | Where-Object { $_.id -in $CaseIds }) }
if($selected.Count -eq 0) { throw 'No N3 cases selected.' }
$campaign=Join-Path $PSScriptRoot ('runs/N3_'+$Label+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $campaign
$manifest=[ordered]@{schema=1;node='N3';label=$Label;folder=$campaign;replay_of=$ReplayOf;status='running';startup_options=@('-singleCompThread');driver_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLower();entries=@()}
$manifestPath=Join-Path $campaign 'campaign.json'
$sourcePath=$PSScriptRoot.Replace('\','/').Replace("'","''")
$jobs=@()
foreach($case in $selected) { $jobs+=@{case_id=$case.id;observer=$true;kind='observer'} }
if($IncludeBaselines) {
    $baseIds=@('steady_1000','steady_2000','steady_3000','dynamic_speed_load','reverse_1000','reverse_3000','detailed_bridge_0us','detailed_bridge_2us','low_speed_stop')
    foreach($id in $baseIds) { $jobs+=@{case_id=$id;observer=$false;kind='plant_reference'} }
}
foreach($job in $jobs) {
    $entry=[ordered]@{case_id=$job.case_id;kind=$job.kind;attempts=@();completed_folder='';status='incomplete'}
    for($attempt=1;$attempt -le 2;$attempt++) {
        $folder=Join-Path $campaign ($job.kind+'/'+$job.case_id+'/attempt_'+$attempt)
        $null=New-Item -ItemType Directory -Path $folder
        $matFolder=$folder.Replace('\','/').Replace("'","''")
        $present='true';if(-not $job.observer) { $present='false' }
        $expression="addpath('$sourcePath'); validate_sensorless_n3_case('$($job.case_id)','$matFolder','$Label',$present);"
        $log=Join-Path $folder 'console.log'
        $launcherLog=Join-Path $folder 'launcher.log'
        & $MatlabExe -singleCompThread -batch $expression -logfile $log 2>&1 | Tee-Object -FilePath $launcherLog
        $exitCode=$LASTEXITCODE
        $entry.attempts+=@{folder=$folder;exit_code=$exitCode}
        if($exitCode -eq 0) {
            $r=Get-Content -LiteralPath (Join-Path $folder 'record.json') -Raw | ConvertFrom-Json
            $entry.completed_folder=$folder;$entry.status=$r.status;break
        }
        $native=($exitCode -in @(-1073741819,-1073741795)) -or ((Get-Content -LiteralPath $launcherLog -Raw) -match '0xc0000005|0xc000001d')
        $failure=@{status='failed_launcher';exit_code=$exitCode;native_failure=$native;case_id=$job.case_id;attempt=$attempt}
        $failure | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $folder 'launcher_failure.json') -Encoding utf8
        if(-not $native) {
            $manifest.entries+=,$entry;$manifest.status='failed_execution'
            $manifest | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $manifestPath -Encoding utf8
            throw "N3 script/compile failure; preserve $folder"
        }
    }
    $manifest.entries+=,$entry
    $manifest | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $manifestPath -Encoding utf8
}
$manifest.status='completed';if(@($manifest.entries | Where-Object {$_.status -ne 'passed'}).Count -gt 0) { $manifest.status='has_failed_or_incomplete_cases' }
$manifest | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Output "N3_CAMPAIGN_FOLDER=$campaign"
