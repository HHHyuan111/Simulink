$ErrorActionPreference='Stop'
$base=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$folder=Join-Path $base 'runs\N3R2_rapid_toy_once'
$launch=Join-Path $base 'runs\N3R2_rapid_toy_launch.json'
if((Test-Path -LiteralPath $folder) -or (Test-Path -LiteralPath $launch)){throw 'Standalone feasibility already started; no repeat.'}
$py='C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Frozen candidate integrity failed.'}
$job=[ordered]@{kind='rapid_execution_feasibility';started_at=[DateTime]::UtcNow.ToString('o');status='running';native_retries=0;folder=$folder;exit_code=$null;host_settings_changed=$false}
$job|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $launch -Encoding utf8
$command="addpath('$($PSScriptRoot.Replace('\','/'))');probe_sensorless_r2_rapid_toy('$($folder.Replace('\','/'))');"
$stdout=Join-Path $base 'runs\N3R2_rapid_toy_private_stdout.log'
$stderr=Join-Path $base 'runs\N3R2_rapid_toy_private_stderr.log'
$process=Start-Process -FilePath 'D:\DevTools\MATLAB\R2026a\bin\matlab.exe' -ArgumentList @('-singleCompThread','-batch',('"'+$command+'"')) -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
$process.WaitForExit();$process.Refresh();$job.exit_code=$process.ExitCode;$job.status='exited'
$job|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $launch -Encoding utf8
& $py (Join-Path $base 'robust\formal_r2\candidate.py') verify
if($LASTEXITCODE -ne 0){throw 'Frozen candidate integrity failed after diagnostic.'}
Write-Output ('RAPID_TOY_EXIT='+$job.exit_code)
