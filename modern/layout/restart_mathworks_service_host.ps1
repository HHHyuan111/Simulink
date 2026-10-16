# Recovery for the licensing backend, without changing proxy or security settings.
# Refuses to stop the backend while MATLAB is running, to protect unsaved work.
$ErrorActionPreference = 'Stop'
if (Get-Process -Name MATLAB -ErrorAction SilentlyContinue) {
    throw 'Save your work and close MATLAB before running this recovery script.'
}
$serviceRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'MathWorks\ServiceHost'))
$backendProcesses = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -in @('MathWorksServiceHost.exe', 'MathWorksServiceHost-Monitor.exe')
}
foreach ($backend in ($backendProcesses | Sort-Object {
    if ($_.Name -eq 'MathWorksServiceHost-Monitor.exe') { 0 } else { 1 }
})) {
    if (-not $backend.ExecutablePath -or
        -not ([IO.Path]::GetFullPath($backend.ExecutablePath)).StartsWith(
            $serviceRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Unexpected Service Host executable path; no further processes will be stopped.'
    }
    Stop-Process -Id $backend.ProcessId -ErrorAction SilentlyContinue
    Wait-Process -Id $backend.ProcessId -Timeout 10 -ErrorAction SilentlyContinue
}
$matlabExecutable = 'D:\DevTools\MATLAB\R2026a\bin\matlab.exe'
if (-not (Test-Path -LiteralPath $matlabExecutable)) { throw 'MATLAB executable not found.' }
$recoveryLog = Join-Path $PSScriptRoot ('license_probe_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')
& $matlabExecutable -wait -logfile $recoveryLog -batch "fprintf('MATLAB_START_OK %s\n',version); assert(license('test','Simulink')==1,'Simulink license unavailable'); fprintf('SIMULINK_LICENSE_OK\n');"
if ($LASTEXITCODE -ne 0) { throw "Recovery probe failed. See $recoveryLog" }
Write-Output "Recovery probe passed. Log: $recoveryLog"
