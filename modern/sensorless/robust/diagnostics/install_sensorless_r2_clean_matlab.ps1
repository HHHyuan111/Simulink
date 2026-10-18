$ErrorActionPreference='Stop'
# Only this installer is elevated. Never elevate MATLAB simulation or modify the old installation.
$base=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if($base -ne 'D:\simulink\dev\modern\sensorless'){throw 'Unexpected workspace'}
$root=Join-Path $base '.build\matlab_clean'
$target=Join-Path $root 'R2026a_U5'
$tool=Join-Path $root 'tools\mpm.exe'
$statusFile=Join-Path $root 'installation_status.json'
if(Test-Path -LiteralPath $statusFile){throw 'Installation already attempted; preserve the previous attempt'}
if(Test-Path -LiteralPath $target){throw 'A new installation directory is required'}
$sig=Get-AuthenticodeSignature -LiteralPath $tool
$toolHash=(Get-FileHash -LiteralPath $tool -Algorithm SHA256).Hash.ToLowerInvariant()
if($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'MathWorks' -or $toolHash -ne '10a7265efd1660d39ee27c24629fd7826aea6eeb7f6ad721f5e00ff7f0037939'){throw 'Official tool verification failed'}
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Standard Windows administrator approval required'}
$state=[ordered]@{schema=1;status='installing';started_at=[DateTime]::UtcNow.ToString('o');finished_at=$null;release='R2026aU5';products=@('MATLAB','Simulink','Stateflow');target=$target;mpm_sha256=$toolHash;installer_pid=$PID;exit_code=$null;simulation_started=$false;existing_installation_modified_by_script=$false}
function Save-State {$state|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $statusFile -Encoding utf8}
Save-State
$privateTemp=Join-Path $root 'temp'
New-Item -ItemType Directory -Path $privateTemp -Force|Out-Null
$env:HTTP_PROXY='http://127.0.0.1:7897'
$env:HTTPS_PROXY='http://127.0.0.1:7897'
$env:TEMP=$privateTemp;$env:TMP=$privateTemp;$env:TMPDIR=$privateTemp
try {
 Set-Location -LiteralPath $root
 & $tool install --release=R2026aU5 "--destination=$target" --products=MATLAB Simulink Stateflow 1> (Join-Path $root 'private_install_stdout.log') 2> (Join-Path $root 'private_install_stderr.log')
 $state.exit_code=$LASTEXITCODE
 $state.status='failed_installation'
 if($state.exit_code -eq 0 -and (Test-Path -LiteralPath (Join-Path $target 'bin\matlab.exe'))){$state.status='installed_pending_runtime_preflight'}
} catch {
 $state.status='failed_installation';$state.error_type=$_.Exception.GetType().FullName
 $_|Out-String|Add-Content -LiteralPath (Join-Path $root 'private_install_exception.log') -Encoding utf8
} finally {$state.finished_at=[DateTime]::UtcNow.ToString('o');Save-State}
if($state.status -ne 'installed_pending_runtime_preflight'){exit 1}
