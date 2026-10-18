# Read-only host evidence. A corrected hardware event does not establish cause.
$ErrorActionPreference='Stop'
$base=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$captured=Get-Date
$start=$captured.AddDays(-2)
$events=@(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-WHEA-Logger';StartTime=$start} -ErrorAction SilentlyContinue)
$rows=@($events | ForEach-Object {
 [ordered]@{time=$_.TimeCreated.ToString('o');event_id=$_.Id;level=$_.LevelDisplayName;message=$_.Message}
})
$nearby=@()
foreach($event in $events) {
 $apps=@(Get-WinEvent -FilterHashtable @{LogName='Application';Id=1000;StartTime=$event.TimeCreated.AddMinutes(-2);EndTime=$event.TimeCreated.AddMinutes(2)} -ErrorAction SilentlyContinue)
 foreach($app in $apps) {
  $xml=[xml]$app.ToXml();$fields=@{}
  foreach($data in $xml.Event.EventData.Data){$fields[$data.Name]=[string]$data.'#text'}
  $nearby+=,[ordered]@{time=$app.TimeCreated.ToString('o');app=[IO.Path]::GetFileName($fields.AppName);module=[IO.Path]::GetFileName($fields.ModuleName);exception_code=$fields.ExceptionCode}
 }
}
$report=[ordered]@{
 kind='read_only_host_observation';captured_at=$captured.ToString('o');query_start=$start.ToString('o')
 source='Windows System WHEA-Logger and Application1000; Win32_Processor.Name'
 generator_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLower()
 cpu_names=@(Get-CimInstance Win32_Processor | ForEach-Object {$_.Name})
 whea_events=$rows;application1000_within_two_minutes=$nearby
 native_failure_causality_confirmed=$false;host_settings_changed=$false;model_parameters_changed=$false
 interpretation='A corrected processor event is an independent host-stability lead. It does not prove a defective CPU, associate a MATLAB crash with this event, or identify a model error. Empty nearby Application1000 results mean no matching logged event in this query window.'
 primary_explanation='https://learn.microsoft.com/en-us/windows-hardware/drivers/whea/whea-hardware-error-events'
}
$destination=Join-Path $base 'milestones/N3R2/isolation_20261017/host_observation_20261018.json'
$report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $destination -Encoding utf8
[pscustomobject]@{whea_events=$rows.Count;nearby_application1000=$nearby.Count;causality_confirmed=$false}
