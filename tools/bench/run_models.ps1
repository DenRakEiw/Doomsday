<#
.SYNOPSIS
Plays the benchmark with one or more models, one after the other (docs/specs/benchmark.md section 18.5).

.DESCRIPTION
1. Asks tools/bench/model_list.gd for each model's estimate at the chosen effort and suite
   (OpenRouter's public list, no key) and prints it with the total.
2. One confirmation for everything (skip it with -Yes).
3. Runs tools/bench/bench_run.gd per model - with -Parallel N in N processes, each playing
   its own seeds (--seeds) - writing into user://benchmark (%APPDATA%\Doomsday\benchmark),
   so the runs show in the game under Benchmark -> Recorded runs. What -Effort high or ultra
   sends is resolved once, in step 1, and given to every process (--effort-reasoning), so
   all shards of a model record the same params and make one leaderboard row.
4. Stops at the first fatal error (a refused key, no credits, the service down, a cost cap,
   a replay that does not reproduce): the other shards of that model are stopped, no later
   model starts. Runs finished before it are kept.
5. Rebuilds the local leaderboard once and prints a summary: model, effort, runs, score,
   wins, cost.

Keys come from this window's environment or, if it was opened before set_api_key.ps1 ran,
from the user's (HKCU\Environment). They are handed to the child processes only and never
printed. -Mock plays the mock backend: no key, no request, prices from a fixture list, and -
unless -Out says otherwise - its runs go to a scratch folder under %TEMP%, never into the
game's list (mock runs under a real model id would look like that model's).

Each model gets its own cost cap: the likely cost x 1.5, at least 1 USD (the tool's default
cap when the price is unknown); -MaxTotal refuses a batch whose likely total is above it and
scales the caps down so that together they stay within it. Shards share their model's cap. A
free model plays under any cap, 0 included; a batch where a paid (or unknown-price) model's
share rounds to 0.00 USD per process is refused before anything starts.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\bench\run_models.ps1 -Models openai/gpt-6-luna,anthropic/claude-opus-5.5 -Effort high -Suite quick
.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\bench\run_models.ps1 -Models deepseek/deepseek-v4.1-flash -Effort high -Suite standard -Parallel 5 -MaxTotal 10 -Yes
#>
param(
	# Model ids as OpenRouter names them (or typesafe/jev-latest), comma-separated.
	[Parameter(Mandatory = $true)][string[]]$Models,
	# normal: no reasoning parameter; high: reasoning effort high; ultra: the model's highest.
	[ValidateSet("normal", "high", "ultra")][string]$Effort = "normal",
	# quick = 3 seeds (a look), standard = 10 seeds (the ranked suite).
	[ValidateSet("quick", "standard")][string]$Suite = "standard",
	# Processes per model, each playing a share of the seeds.
	[ValidateRange(1, 10)][int]$Parallel = 1,
	# Refuse the batch when its likely total is above this many USD; also bounds the caps.
	[double]$MaxTotal = -1,
	# Start without asking.
	[switch]$Yes,
	# The mock backend: no key, no request (tests and a dry run of the whole flow).
	[switch]$Mock,
	# Where the runs go (bench_run.gd --out); with -Mock a scratch folder unless given.
	[string]$Out = "user://benchmark",
	# Where each process's output is kept (default: a new folder under %TEMP%).
	[string]$LogDir = "",
	# The Godot console executable (default: $env:GODOT, then .claude/settings.local.json).
	[string]$Godot = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "bench_common.ps1")

$Invariant = [Globalization.CultureInfo]::InvariantCulture
$MockBackend = "mock:cheapest"
$MockPrices = "tests\fixtures\bench\openrouter_models.json"
$CapFactor = 1.5
$CapMinimum = 1.0
$PollMs = 1000
$ExitMeaning = @{
	1 = "bad arguments, content or config, or a missing key"
	3 = "a replay did not reproduce its run (a defect in the game, not the model's fault)"
	4 = "the service refused (key, credits, forbidden or a bad request)"
	5 = "the service was unavailable after the retries"
	6 = "the cost cap (or TypeSafe's request cap) was reached"
	7 = "the estimate was above the cap"
}

function Format-Usd([double]$Value) { return $Value.ToString("0.00", $Invariant) }

function Get-JsonLines($Lines) {
	# The machine-readable lines of a tool's output; everything else is banner or prose.
	$out = @()
	foreach ($line in $Lines) {
		$text = [string]$line
		if ($text.StartsWith("{")) {
			try { $out += ($text | ConvertFrom-Json) } catch { }
		}
	}
	return $out
}

function Join-Arguments([string[]]$Items) {
	# Start-Process joins its arguments with spaces; quote the ones that hold one.
	return ($Items | ForEach-Object { if ($_ -match "\s") { '"' + $_ + '"' } else { $_ } }) -join " "
}

$root = Get-BenchRoot
$godotExe = Resolve-BenchGodot $Godot
if (-not $LogDir) {
	$LogDir = Join-Path $env:TEMP ("doomsday-bench\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
# A rehearsal never lands in the game's list: mock runs under a real model id score 0.
if ($Mock -and -not $PSBoundParameters.ContainsKey("Out")) {
	$Out = (Join-Path $LogDir "benchmark").Replace("\", "/")
}
$ids = @($Models | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($ids.Count -eq 0) { Write-Output "run_models: -Models names no model"; exit 1 }

# 1 - the estimate, from the tool's own rule.
$listArgs = @("-s", "tools/bench/model_list.gd", "--", ("--models=" + ($ids -join ",")),
	"--effort=$Effort", "--suite=$Suite", "--json")
if ($Mock) { $listArgs += "--prices=" + (Join-Path $root $MockPrices) }
$listed = Invoke-BenchGodot $godotExe $listArgs
$plans = @(Get-JsonLines $listed.Lines)
if ($listed.Code -ne 0 -or $plans.Count -ne $ids.Count) {
	$listed.Lines | ForEach-Object { Write-Output $_ }
	Write-Output "run_models: the estimate could not be made (exit $($listed.Code))"
	exit 1
}
$refused = @($plans | Where-Object { $_.error })
foreach ($plan in $refused) { Write-Output ("run_models: " + $plan.error) }
if ($refused.Count -gt 0) { exit 1 }

# Keys: only the services this batch talks to, and never printed.
if (-not $Mock) {
	$needs = @()
	if (@($plans | Where-Object { -not $_.typesafe }).Count -gt 0) { $needs += "OPENROUTER_API_KEY" }
	if (@($plans | Where-Object { $_.typesafe }).Count -gt 0) { $needs += "TYPESAFE_API_KEY" }
	foreach ($name in $needs) {
		if (-not (Import-BenchKey $name)) {
			Write-Output "run_models: $name is not set. Set it once with:"
			Write-Output "  powershell -ExecutionPolicy Bypass -File tools\bench\set_api_key.ps1 -Name $name"
			exit 1
		}
	}
}

# Warnings, not refusals: the user decides.
foreach ($plan in $plans) {
	if ($plan.typesafe) { continue }
	if ($Effort -eq "normal" -and $plan.reasons_by_default) {
		Write-Output ("run_models: warning - $($plan.id) reasons by default: at normal its limit of $($plan.max_completion_tokens) tokens may cut answers short (still billed); -Effort high gives it room")
	}
	if ($Effort -ne "normal" -and -not $plan.listed) {
		Write-Output ("run_models: warning - OpenRouter's list does not name $($plan.id) (or could not be read): -Effort $Effort sends reasoning $($plan.reasoning_sent), which OpenRouter maps to the model's nearest effort")
	}
}

$totalLikely = 0.0
$unknown = 0
foreach ($plan in $plans) {
	if ($plan.known) {
		$cap = [Math]::Max($CapMinimum, [Math]::Ceiling([double]$plan.likely * $CapFactor * 100) / 100)
		$totalLikely += [double]$plan.likely
	} else {
		$cap = [double]$plan.cap
		$unknown += 1
	}
	$plan | Add-Member -NotePropertyName run_cap -NotePropertyValue $cap
}
if ($MaxTotal -ge 0) {
	if ($totalLikely -gt $MaxTotal) {
		Write-Output ("run_models: the likely total " + (Format-Usd $totalLikely) + " USD is above -MaxTotal " + (Format-Usd $MaxTotal) + " USD - nothing started")
		exit 7
	}
	$capSum = ($plans | Measure-Object -Property run_cap -Sum).Sum
	if ($capSum -gt $MaxTotal -and $capSum -gt 0) {
		foreach ($plan in $plans) { $plan.run_cap = [Math]::Floor($plan.run_cap * $MaxTotal / $capSum * 100) / 100 }
	}
}
# Each process gets its share of its model's cap. A share of 0.00 would stop a paid model's
# first request (bench_run.gd exit 6); only a free model plays under it.
$zeroCaps = @()
foreach ($plan in $plans) {
	$shards = [Math]::Min($Parallel, @($plan.seeds).Count)
	$shardCap = [Math]::Floor($plan.run_cap / $shards * 100) / 100
	$plan | Add-Member -NotePropertyName shard_cap -NotePropertyValue $shardCap
	if ($shardCap -le 0 -and -not $plan.free) { $zeroCaps += $plan.id }
}
if ($zeroCaps.Count -gt 0) {
	Write-Output ("run_models: the cap per process of " + ($zeroCaps -join ", ") + " rounds to 0.00 USD - raise -MaxTotal or lower -Parallel; nothing started")
	exit 1
}

Write-Output ""
Write-Output ("{0,-48} {1,-7} {2,-10} {3,10} {4,10} {5,8}" -f "Model", "Effort", "Reasoning", "Likely", "At most", "Cap")
foreach ($plan in $plans) {
	$effortText = if ($plan.typesafe) { "-" } else { $plan.effort }
	$reasoning = if ($plan.reasoning_sent) { $plan.reasoning_sent } else { "-" }
	$likely = if ($plan.known) { Format-Usd $plan.likely } else { "?" }
	$atMost = if ($plan.known) { Format-Usd $plan.at_most } else { "?" }
	Write-Output ("{0,-48} {1,-7} {2,-10} {3,10} {4,10} {5,8}" -f $plan.id, $effortText, $reasoning, $likely, $atMost, (Format-Usd $plan.run_cap))
}
$suiteSeeds = @($plans[0].seeds)
Write-Output ""
Write-Output ("Suite $Suite ($($suiteSeeds.Count) seeds), $($plans.Count) model(s), likely total " + (Format-Usd $totalLikely) + " USD" + $(if ($unknown -gt 0) { " + $unknown with an unknown price" } else { "" }) + $(if ($Mock) { " - MOCK: nothing is requested" } else { "" }))

# 2 - one confirmation.
if (-not $Yes) {
	$answer = Read-Host "Start? [y/N]"
	if ($answer -notmatch "^(y|yes|j|ja)$") { Write-Output "run_models: nothing started"; exit 0 }
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
Write-Output "run_models: logs in $LogDir"

# 3 - the runs.
$failure = 0
$logs = @{}
foreach ($plan in $plans) {
	$seeds = @($plan.seeds)
	$shards = [Math]::Min($Parallel, $seeds.Count)
	$per = [Math]::Ceiling($seeds.Count / $shards)
	$shardCap = $plan.shard_cap
	$slug = Get-BenchSlug $plan.id
	$processes = @()
	$logs[$plan.id] = @()
	for ($i = 0; $i -lt $shards; $i++) {
		$first = $i * $per
		if ($first -ge $seeds.Count) { break }
		$last = [Math]::Min($first + $per, $seeds.Count) - 1
		$range = "$($seeds[$first])..$($seeds[$last])"
		$arguments = @("--headless", "--path", $root, "-s", "tools/bench/bench_run.gd", "--",
			"--model=$($plan.id)", "--suite=$Suite", "--seeds=$range", "--out=$Out",
			("--max-cost=" + $shardCap.ToString($Invariant)), "--yes", "--no-rebuild")
		if (-not $plan.typesafe -and $Effort -ne "normal") {
			$arguments += "--effort=$Effort"
			# Resolved once for all shards: one params_id, one row (benchmark.md section 18.2).
			if ($plan.reasoning_sent) { $arguments += "--effort-reasoning=$($plan.reasoning_sent)" }
		}
		if ($Mock) { $arguments += "--backend=$MockBackend" }
		$log = Join-Path $LogDir "$slug`__s$($seeds[$first])-$($seeds[$last]).log"
		$logs[$plan.id] += $log
		$process = Start-Process -FilePath $godotExe -ArgumentList (Join-Arguments $arguments) `
			-RedirectStandardOutput $log -RedirectStandardError "$log.err" -NoNewWindow -PassThru
		# Without its handle held, a finished process may report no exit code.
		$null = $process.Handle
		$processes += $process
	}
	Write-Output ("run_models: $($plan.id) - $($processes.Count) process(es), seeds " + ($seeds -join ","))
	# Wait; the first process that fails stops its siblings.
	while ($true) {
		$running = @($processes | Where-Object { -not $_.HasExited })
		$failed = @($processes | Where-Object { $_.HasExited -and $_.ExitCode -ne 0 })
		if ($failed.Count -gt 0) {
			$failure = $failed[0].ExitCode
			foreach ($process in $running) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
			break
		}
		if ($running.Count -eq 0) { break }
		Start-Sleep -Milliseconds $PollMs
	}
	if ($failure -ne 0) {
		$meaning = if ($ExitMeaning.ContainsKey($failure)) { $ExitMeaning[$failure] } else { "exit $failure" }
		Write-Output "run_models: $($plan.id) stopped - $meaning (exit $failure). No further model starts."
		foreach ($log in $logs[$plan.id]) {
			if (Test-Path $log) {
				Get-Content -Encoding UTF8 $log | Where-Object { $_ -match "^benchmark: " } | Select-Object -Last 3 |
					ForEach-Object { Write-Output ("  " + $_) }
			}
		}
		break
	}
}

# 4 - one rebuild of the local board, then the summary.
$rebuild = Invoke-BenchGodot $godotExe @("-s", "tools/bench/bench_run.gd", "--", "--rebuild", "--out=$Out")
if ($rebuild.Code -ne 0) { Write-Output "run_models: the leaderboard in $Out could not be rebuilt (exit $($rebuild.Code))" }

Write-Output ""
Write-Output ("{0,-48} {1,-7} {2,5} {3,7} {4,6} {5,10}" -f "Model", "Effort", "Runs", "Score", "Wins", "Cost USD")
foreach ($plan in $plans) {
	if (-not $logs.ContainsKey($plan.id)) { continue }
	$runs = @()
	foreach ($log in @($logs[$plan.id])) {
		if (Test-Path $log) { $runs += @(Get-JsonLines (Get-Content -Encoding UTF8 $log) | Where-Object { $null -ne $_.seed }) }
	}
	if ($runs.Count -eq 0) { continue }
	$score = ($runs | Measure-Object -Property score -Average).Average
	$wins = @($runs | Where-Object { ([string]$_.outcome).StartsWith("win_") }).Count
	$cost = ($runs | Measure-Object -Property cost_usd -Sum).Sum
	$effortText = if ($plan.typesafe) { "-" } else { $plan.effort }
	Write-Output ("{0,-48} {1,-7} {2,5} {3,7} {4,6} {5,10}" -f $plan.id, $effortText, $runs.Count,
		$score.ToString("0.0", $Invariant), "$wins/$($runs.Count)", (Format-Usd $cost))
}
Write-Output ""
Write-Output "run_models: runs in $Out/runs - the game lists them under Benchmark; submit with tools\bench\submit_runs.ps1"
exit $failure
