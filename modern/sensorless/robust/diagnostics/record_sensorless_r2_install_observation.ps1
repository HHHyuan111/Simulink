# Read-only targeted binary provenance; do not infer overall installation health.
$ErrorActionPreference='Stop'
$base=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$destination=Join-Path $base 'milestones\N3R2\crash_context_20261018\installation_observation.json'
if(Test-Path -LiteralPath $destination){throw 'Read-only observation already captured; preserve it.'}
$root='D:\DevTools\MATLAB\R2026a'
$names=@('m_lxe.dll','libmx.dll','SimulinkBlock.dll','libmwslexec_runtime.dll','MSVCP140.dll','libmwir.dll','libmwfl.dll','mcos_impl.dll','libmwsl_elem_blocks.dll','icuin74.dll','libmwfixedpointcore.dll')
$process=Get-Process -Id 35868 -ErrorAction SilentlyContinue
$loaded=@{};if($process){foreach($module in $process.Modules){if($module.ModuleName -in $names){$loaded[$module.ModuleName]=$module.FileName}}}
$rows=@()
foreach($name in $names){
 $path=Join-Path $root ('bin\win64\'+$name);$signature=Get-AuthenticodeSignature -LiteralPath $path
 $rows+=,[ordered]@{name=$name;path=$path;observed_loaded_gui_path=$loaded[$name];signature_status=[string]$signature.Status;sha256=(Get-FileHash -LiteralPath $path).Hash.ToLower();file_version=(Get-Item -LiteralPath $path).VersionInfo.FileVersion}
}
$os=Get-CimInstance Win32_OperatingSystem;$bios=Get-CimInstance Win32_BIOS
$report=[ordered]@{kind='read_only_targeted_installation_observation';captured_at=(Get-Date).ToString('o');generator_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLower();version_info_sha256=(Get-FileHash -LiteralPath (Join-Path $root 'VersionInfo.xml')).Hash.ToLower();os_caption=$os.Caption;os_version=$os.Version;os_build=$os.BuildNumber;bios_version=$bios.SMBIOSBIOSVersion;bios_release_date=$bios.ReleaseDate.ToString('o');binaries=$rows;all_target_signatures_valid=(@($rows|Where-Object {$_.signature_status -ne 'Valid'}).Count -eq 0);host_settings_changed=$false;gui_modified=$false;root_cause_confirmed=$false;interpretation='Target file signatures/provenance only. Not a complete installation integrity or dependency-version audit, not a diagnosis of hardware or runtime correctness. No repair, reinstall, BIOS, registry or environment mutation.'}
New-Item -ItemType Directory -Path (Split-Path $destination) -Force|Out-Null
$report|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $destination -Encoding utf8
[pscustomobject]@{TargetBinaries=$rows.Count;AllSignaturesValid=$report.all_target_signatures_valid;SettingsChanged=$false}
