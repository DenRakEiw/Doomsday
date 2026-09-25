# The S6.11 performance runs (release.md §11.3), Windows only.
#
#   Bench:  tools\perf\run_perf.ps1 -Exe build\perf\Doomsday-perf.exe -Label igpu_1080 -IntegratedGpu
#           tools\perf\run_perf.ps1 -Exe build\perf\Doomsday-perf.exe -Label igpu_800 -IntegratedGpu -Resolution 1280x800
#           tools\perf\run_perf.ps1 -Exe build\perf\Doomsday-perf.exe -Label cpu_4t -Affinity 0xF
#   Start:  tools\perf\run_perf.ps1 -Exe build\windows\Doomsday.exe -StartTime
#
# Every run is started muted (the dummy audio driver) and three times; the run
# with the median p95 frame time counts. The peak working set is read from
# outside the process every 250 ms. -IntegratedGpu sets Windows' per-application
# GPU preference to "power saving" for the executable and runs ANGLE over
# Direct3D 11 so the preference applies; the registry value is removed again
# afterwards, whatever happens. Every process logs to -LogDir (default: a
# folder under the system's temp directory), never to the game's own
# user://logs/, so the player's log is left alone while they play.
param(
	[Parameter(Mandatory = $true)] [string] $Exe,
	[string] $Label = "bench",
	[string] $Resolution = "1920x1080",
	[int] $Affinity = 0,
	[switch] $IntegratedGpu,
	[switch] $StartTime,
	[int] $Runs = 3,
	[int] $StartWaitSeconds = 8,
	[string] $LogDir = (Join-Path ([System.IO.Path]::GetTempPath()) "doomsday_perf_logs")
)

$ErrorActionPreference = "Stop"
$exePath = (Resolve-Path $Exe).Path
$userDir = Join-Path $env:APPDATA "Doomsday"
$perfDir = Join-Path $userDir "perf"
$gpuKey = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
$pollMs = 250
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Get-Median([double[]] $values) {
	$sorted = $values | Sort-Object
	return $sorted[[int][math]::Floor(($sorted.Count - 1) / 2)]
}

if ($StartTime) {
	# release.md §11.3 "Start time": the release export three times; each prints
	# "first screen <ms>" once, which the log keeps. The window is closed like a
	# player closes it, so the log is complete when it is read.
	$times = @()
	for ($i = 1; $i -le $Runs; $i++) {
		$log = Join-Path $LogDir ("start_{0}.log" -f $i)
		if (Test-Path $log) { Remove-Item $log }
		$p = Start-Process -FilePath $exePath -ArgumentList @("--audio-driver", "Dummy", "--log-file", $log) -PassThru
		Start-Sleep -Seconds $StartWaitSeconds
		[void] $p.CloseMainWindow()
		if (-not $p.WaitForExit(15000)) { Stop-Process -Id $p.Id -Force }
		$line = Select-String -Path $log -Pattern "^first screen (\d+)" | Select-Object -Last 1
		if ($null -eq $line) { Write-Output "run ${i}: no 'first screen' line"; continue }
		$ms = [int] $line.Matches[0].Groups[1].Value
		$times += $ms
		Write-Output "run ${i}: first screen $ms ms"
	}
	if ($times.Count -gt 0) { Write-Output ("start median: {0} ms" -f (Get-Median $times)) }
	exit 0
}

$results = @()
try {
	if ($IntegratedGpu) {
		if (-not (Test-Path $gpuKey)) { New-Item -Path $gpuKey -Force | Out-Null }
		New-ItemProperty -Path $gpuKey -Name $exePath -Value "GpuPreference=1;" -PropertyType String -Force | Out-Null
	}
	for ($i = 1; $i -le $Runs; $i++) {
		$runLabel = "{0}_{1}" -f $Label, $i
		$arguments = @("--audio-driver", "Dummy", "--resolution", $Resolution, "--position", "0,0",
			"--log-file", (Join-Path $LogDir "$runLabel.log"))
		if ($IntegratedGpu) { $arguments += @("--rendering-driver", "opengl3_angle") }
		$arguments += @("--", "--label=$runLabel")
		$p = Start-Process -FilePath $exePath -ArgumentList $arguments -PassThru
		if ($Affinity -ne 0) { $p.ProcessorAffinity = [IntPtr] $Affinity }
		$peak = 0
		while (-not $p.HasExited) {
			$p.Refresh()
			try { $peak = [math]::Max($peak, $p.PeakWorkingSet64) } catch { }
			Start-Sleep -Milliseconds $pollMs
		}
		$summaryPath = Join-Path $perfDir "$runLabel.json"
		if (-not (Test-Path $summaryPath)) { Write-Output "${runLabel}: no summary (exit $($p.ExitCode))"; continue }
		$summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
		$summary | Add-Member -NotePropertyName peak_working_set_mb -NotePropertyValue ([math]::Round($peak / 1MB, 1))
		$summary | Add-Member -NotePropertyName exit_code -NotePropertyValue $p.ExitCode
		$results += $summary
		Write-Output ("{0}: adapter={1} p50={2:N2} p95={3:N2} p99={4:N2} max={5:N1} (with changes {6:N1}) process_p95={7:N2} tick_frame_p99={8:N2} tick_mean={9:N2} tick_max={10:N2} draw={11} vmem={12:N0}MB peak_ws={13}MB load={14:N0}ms boot={15}ms reloads={16}" -f `
			$runLabel, $summary.adapter, $summary.frame_p50_ms, $summary.frame_p95_ms, $summary.frame_p99_ms, `
			$summary.frame_max_ms, $summary.frame_max_with_changes_ms, $summary.process_p95_ms, `
			$summary.tick_frame_p99_ms, $summary.tick_mean_ms, $summary.tick_max_ms, $summary.draw_calls_max, `
			$summary.video_mem_max_mb, $summary.peak_working_set_mb, $summary.load_ms, $summary.boot_ms, $summary.reloads)
	}
} finally {
	if ($IntegratedGpu) { Remove-ItemProperty -Path $gpuKey -Name $exePath -ErrorAction SilentlyContinue }
}
if ($results.Count -gt 0) {
	$median = Get-Median ($results | ForEach-Object { [double] $_.frame_p95_ms })
	$chosen = $results | Where-Object { [double] $_.frame_p95_ms -eq $median } | Select-Object -First 1
	Write-Output ("median run: {0}" -f $chosen.label)
	$chosen | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $perfDir "$Label.median.json")
}
