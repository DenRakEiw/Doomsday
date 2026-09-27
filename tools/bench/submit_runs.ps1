<#
.SYNOPSIS
Puts recorded benchmark runs onto the global leaderboard (docs/specs/benchmark.md section 18.6).

.DESCRIPTION
1. Pulls the leaderboard clone (default: ..\doomsday-leaderboard next to the game).
2. Copies the run files (default: %APPDATA%\Doomsday\benchmark\runs, where run_models.ps1
   writes) into its runs\ - only model runs: bot and mock runs are left out, -Model keeps
   one model's.
3. Runs the repository's own check, tools/validate.py --all (uv run --no-project python).
4. Shows what would be committed. Without -Push that is all: the copies are taken back and
   the clone is left as it was.

With -Push the runs are committed and pushed to the public repository's main, and then
EITHER (default) the private workflow "leaderboard" is dispatched (gh workflow run) - it
verifies and publishes only when the secret LEADERBOARD_DEPLOY_KEY exists, otherwise it is a
read-only dry run; OR, with -VerifyLocally, this machine does the workflow's work: the bot
reference rows (bench_run.gd --bots --if-missing, about 3 minutes; -SkipBots leaves them
out), the replay verifier (verify_runs.gd against the clone, with a scratch APPDATA), then
commits the records and the rebuilt leaderboard.json and LEADERBOARD.md and pushes them. The
verification is only as good as this checkout: it should be the game's main.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\bench\submit_runs.ps1 -Model anthropic/claude-opus-5.5
.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\bench\submit_runs.ps1 -Push -VerifyLocally
#>
param(
	# Only this model's runs.
	[string]$Model = "",
	# Commit and push (without it: show what would be committed and change nothing).
	[switch]$Push,
	# With -Push: verify and publish here instead of dispatching the workflow.
	[switch]$VerifyLocally,
	# With -VerifyLocally: do not play the bot reference rows.
	[switch]$SkipBots,
	# With -Push and without -VerifyLocally: do not dispatch the workflow.
	[switch]$NoDispatch,
	# Also submit runs of the mock backends (tests only - they are not models).
	[switch]$IncludeMock,
	# The doomsday-leaderboard clone.
	[string]$Board = "",
	# Where the run files are.
	[string]$Runs = "",
	# The game repository whose workflow is dispatched.
	[string]$GameRepo = "DenRakEiw/Doomsday",
	# The Godot console executable (default: $env:GODOT, then .claude/settings.local.json).
	[string]$Godot = ""
)

# "Continue": git and Godot write progress to stderr; the exit codes decide.
$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "bench_common.ps1")

$root = Get-BenchRoot
if (-not $Board) { $Board = Join-Path (Split-Path $root -Parent) "doomsday-leaderboard" }
if (-not $Runs) { $Runs = Join-Path $env:APPDATA "Doomsday\benchmark\runs" }
$Workflow = "leaderboard.yml"

function Invoke-Git([string[]]$Arguments) {
	$output = & git -C $Board @Arguments 2>&1
	return @{ Code = $LASTEXITCODE; Lines = @($output | ForEach-Object { [string]$_ }) }
}

function Stop-Submit([string]$Message, [int]$Code) {
	Write-Output "submit_runs: $Message"
	exit $Code
}

function Get-Head([string]$Path, [string]$Key) {
	# A top-level string of a run file, from its first lines (the writer puts
	# model and backend there) - the file is not parsed whole.
	$head = (Get-Content -Encoding UTF8 -TotalCount 8 $Path) -join "`n"
	if ($head -match ('"' + $Key + '":\s*"([^"]*)"')) { return $Matches[1] }
	return ""
}

if (-not (Test-Path (Join-Path $Board "tools\validate.py")) -or -not (Test-Path (Join-Path $Board "runs"))) {
	Stop-Submit "$Board is not a doomsday-leaderboard clone (no runs\ or tools\validate.py)" 1
}
if (-not (Test-Path $Runs)) { Stop-Submit "no runs in $Runs" 1 }

# 1 - up to date first.
$pulled = Invoke-Git @("pull", "--ff-only")
if ($pulled.Code -ne 0) {
	$pulled.Lines | ForEach-Object { Write-Output "  $_" }
	Stop-Submit "git pull failed in $Board - resolve it first" 1
}
$status = Invoke-Git @("status", "--porcelain")
if ($status.Lines.Count -gt 0 -and ($status.Lines -join "").Trim()) {
	Stop-Submit "$Board has uncommitted changes - commit or discard them first" 1
}

# 2 - the runs to submit.
$added = @()
$changed = @()
$skipped = 0
foreach ($file in Get-ChildItem -File -Path $Runs -Filter "*.json" | Sort-Object Name) {
	if ($file.Name -notmatch "^[a-z0-9._-]+\.json$") { $skipped += 1; continue }
	$runModel = Get-Head $file.FullName "model"
	$backend = Get-Head $file.FullName "backend"
	if ($backend -eq "bot" -or $runModel.StartsWith("bot:")) { continue }
	if ($backend.StartsWith("mock") -and -not $IncludeMock) { continue }
	if ($Model -and $runModel -ne $Model) { continue }
	$target = Join-Path $Board ("runs\" + $file.Name)
	if (Test-Path $target) {
		if ((Get-FileHash $target).Hash -eq (Get-FileHash $file.FullName).Hash) { continue }
		$changed += $file.Name
	} else {
		$added += $file.Name
	}
	Copy-Item -LiteralPath $file.FullName -Destination $target -Force
}
$names = @($added + $changed)
if ($names.Count -eq 0) {
	Stop-Submit ("nothing new to submit from $Runs" + $(if ($Model) { " for $Model" } else { "" })) 0
}

function Undo-Copies {
	foreach ($name in $added) { Remove-Item -LiteralPath (Join-Path $Board ("runs\" + $name)) -Force }
	if ($changed.Count -gt 0) { $null = Invoke-Git (@("checkout", "--") + @($changed | ForEach-Object { "runs/$_" })) }
}

# 3 - the public repository's own check.
Push-Location $Board
$validation = & uv run --no-project python tools/validate.py --all 2>&1
$validCode = $LASTEXITCODE
Pop-Location
$validation | ForEach-Object { Write-Output "  $_" }
if ($validCode -ne 0) {
	Undo-Copies
	Stop-Submit "validate.py refused the runs - nothing was committed" 1
}

# 4 - what would be committed.
Write-Output ""
Write-Output ("submit_runs: $($added.Count) new, $($changed.Count) changed run file(s)" + $(if ($skipped -gt 0) { ", $skipped file(s) with another name ignored" } else { "" }))
(Invoke-Git @("status", "--short", "--", "runs")).Lines | ForEach-Object { Write-Output "  $_" }
if (-not $Push) {
	Undo-Copies
	Write-Output "submit_runs: dry run - nothing committed, the clone is as it was. Add -Push to submit."
	exit 0
}

$models = @($names | ForEach-Object { Get-Head (Join-Path $Board ("runs\" + $_)) "model" } | Sort-Object -Unique)
$message = "runs: $($names.Count) run(s) of " + ($models -join ", ")
$null = Invoke-Git (@("add", "--") + @($names | ForEach-Object { "runs/$_" }))
$commit = Invoke-Git @("commit", "-q", "-m", $message)
if ($commit.Code -ne 0) { $commit.Lines | ForEach-Object { Write-Output "  $_" }; Stop-Submit "the commit failed" 1 }

if ($VerifyLocally) {
	$godotExe = Resolve-BenchGodot $Godot
	$gameCommit = (& git -C $root rev-parse HEAD 2>$null | Select-Object -First 1)
	$mainCommit = (& git -C $root rev-parse origin/main 2>$null | Select-Object -First 1)
	if ($gameCommit -ne $mainCommit) {
		Write-Output "submit_runs: warning - this game checkout is not origin/main; runs are judged against its content"
	}
	if ((& git -C $root status --porcelain -- data 2>$null | Measure-Object).Count -gt 0) {
		Write-Output "submit_runs: warning - data/ has uncommitted changes; runs are judged against them"
	}
	$boardPath = (Resolve-Path $Board).Path
	# The Godot processes get a scratch APPDATA of their own (nothing of the
	# user's profile is touched); this window's is put back afterwards.
	$savedAppData = $env:APPDATA
	$env:APPDATA = Join-Path $env:TEMP "doomsday-verify-appdata"
	New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
	$messageFile = Join-Path $env:APPDATA "verify-message.txt"
	$problem = ""
	$problemCode = 0
	try {
		if (-not $SkipBots) {
			Write-Output "submit_runs: the bot reference rows (only those missing on this content) ..."
			$bots = Invoke-BenchGodot $godotExe @("-s", "tools/bench/bench_run.gd", "--", "--bots",
				"--suite=standard", "--out=$boardPath", "--if-missing", "--no-rebuild")
			if ($bots.Code -ne 0) {
				$problem = "the bot rows failed (exit $($bots.Code)) - nothing pushed; the runs commit is local only"
				$problemCode = $bots.Code
			}
		}
		if (-not $problem) {
			Write-Output "submit_runs: verifying ..."
			$verify = Invoke-BenchGodot $godotExe @("-s", "tools/bench/verify_runs.gd", "--",
				"--board=$boardPath", "--game-commit=$gameCommit", "--message=$messageFile")
			$verify.Lines | Where-Object { $_ -match "^verify: " } | ForEach-Object { Write-Output "  $_" }
			if ($verify.Code -ne 0) {
				$problem = "the verifier failed (exit $($verify.Code)) - nothing pushed; the runs commit is local only"
				$problemCode = $verify.Code
			}
		}
		if (-not $problem) {
			$null = Invoke-Git @("add", "-A", "--", "runs", "verified", "leaderboard.json", "LEADERBOARD.md")
			$staged = Invoke-Git @("diff", "--cached", "--name-only")
			if (($staged.Lines -join "").Trim()) {
				$published = Invoke-Git @("commit", "-q", "-F", $messageFile)
				if ($published.Code -ne 0) { $problem = "the verification commit failed"; $problemCode = 1 }
			}
		}
	} finally {
		$env:APPDATA = $savedAppData
	}
	if ($problem) { Stop-Submit $problem $problemCode }
}

$pushed = Invoke-Git @("push", "-q", "origin", "HEAD:main")
if ($pushed.Code -ne 0) {
	# Someone pushed meanwhile (a merged pull request, the workflow): once more on top of it.
	$null = Invoke-Git @("pull", "-q", "--rebase", "origin", "main")
	$pushed = Invoke-Git @("push", "-q", "origin", "HEAD:main")
	if ($pushed.Code -ne 0) {
		$pushed.Lines | ForEach-Object { Write-Output "  $_" }
		Stop-Submit "the push was refused twice - the commits are local in $Board" 1
	}
}
Write-Output "submit_runs: pushed $($names.Count) run(s) to the leaderboard's main"

if ($VerifyLocally) {
	Write-Output "submit_runs: verified and published from this machine; players see it the next time they open the list"
} elseif ($NoDispatch) {
	Write-Output "submit_runs: not dispatched - the daily run of the workflow verifies them"
} elseif (Get-Command gh -ErrorAction SilentlyContinue) {
	& gh workflow run $Workflow -R $GameRepo 2>&1 | ForEach-Object { Write-Output "  $_" }
	if ($LASTEXITCODE -eq 0) {
		Write-Output "submit_runs: workflow '$Workflow' dispatched - it publishes only when the secret LEADERBOARD_DEPLOY_KEY exists (else a read-only dry run; use -VerifyLocally)"
	} else {
		Write-Output "submit_runs: the dispatch failed - start it on GitHub (Actions -> leaderboard -> Run workflow) or use -VerifyLocally"
	}
} else {
	Write-Output "submit_runs: gh is not installed - start the workflow on GitHub (Actions -> leaderboard -> Run workflow) or use -VerifyLocally"
}
exit 0
