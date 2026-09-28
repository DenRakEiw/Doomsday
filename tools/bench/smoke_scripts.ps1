<#
.SYNOPSIS
End-to-end check of the benchmark scripts without a key and without touching anything real
(docs/specs/benchmark.md section 18.7).

.DESCRIPTION
In a scratch folder (default: a new one under %TEMP%), with a scratch APPDATA for every Godot
process:
1. parses every tools\bench\*.ps1 (System.Management.Automation.Language.Parser);
2. models.ps1 on the fixture price list (a model that reasons by default is marked);
3. run_models.ps1 -Mock: two mock models, effort high, the quick suite, two processes each,
   into the log folder (never the game's list); fixture/ponder at ultra in two processes
   (one params_id, the plan's reasoning); the warning for a model that reasons by default,
   the refusal of a 0.00 cap for a paid model, a free model under -MaxTotal 0;
4. a bare clone of the leaderboard repository as a stand-in origin, and a clone of that;
5. submit_runs.ps1 -IncludeMock with neither uv nor python on PATH (refused, nothing
   changed), without -Push (the clone must stay as it was), then with -Push -VerifyLocally
   -SkipBots (the stand-in origin must receive the runs, verified, and a leaderboard whose
   rows carry the effort); runs pushed with a plain -Push verified by a later -Push
   -VerifyLocally; Publish-BenchBoard after someone else's push - a conflicting rebase
   aborted (nothing pushed, the clone not mid-rebase), a clean one rebuilt and published.
No request reaches a model service; the only network use is the clone when -Source is a URL.
Exit code 0 when every check passed.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\bench\smoke_scripts.ps1
#>
param(
	# The leaderboard repository to clone (default: ..\doomsday-leaderboard if it exists,
	# else GitHub). It is only read.
	[string]$Source = "",
	[string]$Scratch = "",
	[string]$Godot = ""
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "bench_common.ps1")

$root = Get-BenchRoot
$godotExe = Resolve-BenchGodot $Godot
if (-not $Source) {
	$sibling = Join-Path (Split-Path $root -Parent) "doomsday-leaderboard"
	$Source = if (Test-Path (Join-Path $sibling ".git")) { $sibling } else { "https://github.com/DenRakEiw/doomsday-leaderboard.git" }
}
if (-not $Scratch) { $Scratch = Join-Path $env:TEMP ("doomsday-bench-smoke-" + (Get-Date -Format "yyyyMMdd-HHmmss")) }
New-Item -ItemType Directory -Force -Path $Scratch | Out-Null
$failures = 0

function Test-Check([string]$Name, [bool]$Passed, [string]$Detail = "") {
	if ($Passed) { Write-Output "PASS $Name" } else { Write-Output "FAIL $Name $Detail"; $script:failures += 1 }
}

function Invoke-Script([string]$Name, [string[]]$Arguments) {
	$output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $Name) @Arguments 2>&1
	return @{ Code = $LASTEXITCODE; Text = (@($output | ForEach-Object { [string]$_ }) -join "`n") }
}

# 1 - every script parses.
foreach ($file in Get-ChildItem -Path $PSScriptRoot -Filter "*.ps1") {
	$tokens = $null
	$errors = $null
	[void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
	Test-Check "parse $($file.Name)" ($errors.Count -eq 0) (($errors | ForEach-Object { $_.Message }) -join "; ")
}

$savedAppData = $env:APPDATA
$env:APPDATA = Join-Path $Scratch "appdata"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
try {
	# 2 - the catalogue on the fixture.
	$fixture = Join-Path $root "tests\fixtures\bench\openrouter_models.json"
	$models = Invoke-Script "models.ps1" @("-Prices", $fixture, "-Godot", $godotExe)
	Test-Check "models.ps1 lists the fixture" ($models.Code -eq 0 -and $models.Text.Contains("fixture/thinker") -and $models.Text.Contains("typesafe/jev-latest")) $models.Text
	Test-Check "models.ps1 marks a model that reasons by default" ($models.Text -match "fixture/deep.*default, up to xhigh") $models.Text

	# 3 - two mock models, effort high, two processes each. A rehearsal never lands in the
	# game's list: without -Out its runs go under the log folder.
	$logs = Join-Path $Scratch "logs"
	$run = Invoke-Script "run_models.ps1" @("-Models", "mock/alpha,mock/beta", "-Effort", "high",
		"-Suite", "quick", "-Parallel", "2", "-Mock", "-Yes", "-LogDir", $logs, "-Godot", $godotExe)
	$runsDir = Join-Path $logs "benchmark\runs"
	$written = @(Get-ChildItem -Path $runsDir -Filter "*.json" -ErrorAction SilentlyContinue)
	Test-Check "run_models.ps1 -Mock plays both models" ($run.Code -eq 0 -and $written.Count -eq 6) $run.Text
	Test-Check "run_models.ps1 summary names the effort" ($run.Text -match "mock/alpha\s+high\s+3") $run.Text
	Test-Check "run_models.ps1 -Mock leaves the game's list alone" (-not (Test-Path (Join-Path $env:APPDATA "Doomsday\benchmark\runs")))

	# 3b - what ultra sends is resolved once: every shard records the plan's value.
	$ponderOut = Join-Path $Scratch "ponder"
	$ponder = Invoke-Script "run_models.ps1" @("-Models", "fixture/ponder", "-Effort", "ultra",
		"-Suite", "quick", "-Parallel", "2", "-Mock", "-Yes", "-Out", $ponderOut.Replace("\", "/"),
		"-LogDir", (Join-Path $Scratch "logs-ponder"), "-Godot", $godotExe)
	$ponderRuns = @(Get-ChildItem -Path (Join-Path $ponderOut "runs") -Filter "*.json" -ErrorAction SilentlyContinue)
	$ponderParams = @($ponderRuns | ForEach-Object { (Get-Content -Raw -Encoding UTF8 $_.FullName | ConvertFrom-Json) } |
		ForEach-Object { "$($_.params_id) $($_.params.reasoning)" } | Sort-Object -Unique)
	Test-Check "run_models.ps1 gives every shard the reasoning of its plan" ($ponder.Code -eq 0 -and $ponderRuns.Count -eq 3 -and $ponderParams.Count -eq 1 -and $ponderParams[0].EndsWith(" high")) ($ponder.Text + " / " + ($ponderParams -join ", "))

	# 3c - the warnings and the caps, before anything starts.
	$deep = Invoke-Script "run_models.ps1" @("-Models", "fixture/deep", "-Suite", "quick", "-Mock", "-Yes",
		"-MaxTotal", "0", "-LogDir", (Join-Path $Scratch "logs-deep"), "-Godot", $godotExe)
	Test-Check "run_models.ps1 warns about a model that reasons by default at normal" ($deep.Code -eq 7 -and $deep.Text.Contains("reasons by default")) $deep.Text
	$zero = Invoke-Script "run_models.ps1" @("-Models", "fixture/broken-price", "-Suite", "quick", "-Mock", "-Yes",
		"-MaxTotal", "0", "-LogDir", (Join-Path $Scratch "logs-zero"), "-Godot", $godotExe)
	Test-Check "run_models.ps1 refuses a cap of 0.00 for a model that is not free" ($zero.Code -eq 1 -and $zero.Text.Contains("rounds to 0.00")) $zero.Text
	$free = Invoke-Script "run_models.ps1" @("-Models", "fixture/steady:free", "-Suite", "quick", "-Parallel", "3", "-Mock", "-Yes",
		"-MaxTotal", "0", "-LogDir", (Join-Path $Scratch "logs-free"), "-Godot", $godotExe)
	Test-Check "run_models.ps1 -MaxTotal 0 plays a free model" ($free.Code -eq 0 -and $free.Text -match "fixture/steady:free\s+normal\s+3") $free.Text

	# 4 - a stand-in origin and a clone of it.
	$origin = Join-Path $Scratch "origin.git"
	$board = Join-Path $Scratch "board"
	& git clone -q --bare $Source $origin 2>&1 | Out-Null
	& git clone -q $origin $board 2>&1 | Out-Null
	& git -C $board config user.name "smoke" 2>&1 | Out-Null
	& git -C $board config user.email "smoke@example.invalid" 2>&1 | Out-Null
	$before = (& git -C $origin rev-parse HEAD 2>$null | Select-Object -First 1)

	# 5 - the check fails closed: without uv or python nothing is submitted.
	$savedPath = $env:Path
	$env:Path = (@($env:Path -split ";" | Where-Object { $_ -and -not (Test-Path (Join-Path $_ "uv.exe")) -and
		-not (Test-Path (Join-Path $_ "python.exe")) -and -not (Test-Path (Join-Path $_ "python3.exe")) }) -join ";")
	try {
		$blind = Invoke-Script "submit_runs.ps1" @("-Board", $board, "-Runs", $runsDir, "-IncludeMock", "-Push", "-NoDispatch", "-Godot", $godotExe)
	} finally {
		$env:Path = $savedPath
	}
	$clean = -not ((& git -C $board status --porcelain 2>$null) -join "").Trim()
	$unmoved = (& git -C $origin rev-parse HEAD 2>$null | Select-Object -First 1) -eq $before
	Test-Check "submit_runs.ps1 without uv or python refuses and leaves everything as it was" ($blind.Code -eq 1 -and $blind.Text.Contains("neither uv nor python") -and $clean -and $unmoved) $blind.Text

	# 5a - a dry run changes nothing.
	$dry = Invoke-Script "submit_runs.ps1" @("-Board", $board, "-Runs", $runsDir, "-IncludeMock", "-Godot", $godotExe)
	$clean = -not ((& git -C $board status --porcelain 2>$null) -join "").Trim()
	Test-Check "submit_runs.ps1 dry run validates and leaves the clone clean" ($dry.Code -eq 0 -and $clean -and $dry.Text.Contains("dry run")) $dry.Text

	# 5b - push, verified here. The board may already hold verified runs of its own.
	$baseRecords = @(Get-ChildItem -Path (Join-Path $board "verified") -Filter "*.json" -ErrorAction SilentlyContinue).Count
	$push = Invoke-Script "submit_runs.ps1" @("-Board", $board, "-Runs", $runsDir, "-IncludeMock", "-Push",
		"-VerifyLocally", "-SkipBots", "-Godot", $godotExe)
	$after = (& git -C $origin rev-parse HEAD 2>$null | Select-Object -First 1)
	$records = @(Get-ChildItem -Path (Join-Path $board "verified") -Filter "*.json" -ErrorAction SilentlyContinue)
	$verified = @($records | Where-Object { (Get-Content -Raw -Encoding UTF8 $_.FullName) -match '"verified":\s*true' })
	$boardJson = Get-Content -Raw -Encoding UTF8 (Join-Path $board "leaderboard.json")
	Test-Check "submit_runs.ps1 -Push -VerifyLocally pushes to the stand-in origin" ($push.Code -eq 0 -and $after -ne $before) $push.Text
	Test-Check "every submitted run is verified" ($records.Count -eq $baseRecords + 6 -and $verified.Count -eq $records.Count) "$($records.Count) records ($baseRecords before), $($verified.Count) verified"
	Test-Check "the published rows carry the effort" ($boardJson -match '"effort":\s*"high"')

	# 5c - runs pushed without a verification are verified by a later -VerifyLocally.
	$ponderDir = Join-Path $ponderOut "runs"
	$plain = Invoke-Script "submit_runs.ps1" @("-Board", $board, "-Runs", $ponderDir, "-IncludeMock", "-Push", "-NoDispatch", "-Godot", $godotExe)
	$late = Invoke-Script "submit_runs.ps1" @("-Board", $board, "-Runs", $ponderDir, "-IncludeMock", "-Push",
		"-VerifyLocally", "-SkipBots", "-Godot", $godotExe)
	$records = @(Get-ChildItem -Path (Join-Path $board "verified") -Filter "*.json" -ErrorAction SilentlyContinue)
	$originLog = (& git -C $origin log -1 --format=%s 2>$null | Select-Object -First 1)
	Test-Check "submit_runs.ps1 -Push -VerifyLocally verifies runs already on the board" ($plain.Code -eq 0 -and $late.Code -eq 0 -and $records.Count -eq $baseRecords + 9 -and $late.Text.Contains("verified and published")) ($plain.Text + "`n---`n" + $late.Text + "`n$($records.Count) records; origin: $originLog")

	# 5d - a refused push: a conflicting rebase is aborted, a clean one runs the rebuild.
	$other = Join-Path $Scratch "other"
	& git clone -q $origin $other 2>&1 | Out-Null
	& git -C $other config user.name "other" 2>&1 | Out-Null
	& git -C $other config user.email "other@example.invalid" 2>&1 | Out-Null
	Add-Content -Path (Join-Path $board "LEADERBOARD.md") -Value "mine"
	& git -C $board commit -q -am "mine" 2>&1 | Out-Null
	Add-Content -Path (Join-Path $other "LEADERBOARD.md") -Value "theirs"
	& git -C $other commit -q -am "theirs" 2>&1 | Out-Null
	& git -C $other push -q origin HEAD:main 2>&1 | Out-Null
	$mine = (& git -C $board rev-parse HEAD 2>$null | Select-Object -First 1)
	$conflict = Publish-BenchBoard $board $null
	$midRebase = (Test-Path (Join-Path $board ".git\rebase-merge")) -or (Test-Path (Join-Path $board ".git\rebase-apply"))
	$kept = (& git -C $board rev-parse HEAD 2>$null | Select-Object -First 1) -eq $mine
	$theirs = (& git -C $origin log -1 --format=%s 2>$null | Select-Object -First 1) -eq "theirs"
	Test-Check "a push whose rebase conflicts is aborted and pushes nothing" ($conflict.Code -eq 1 -and -not $midRebase -and $kept -and $theirs) ($conflict.Message + " midRebase=$midRebase kept=$kept theirs=$theirs")
	& git -C $board reset -q --hard origin/main 2>&1 | Out-Null
	& git -C $board pull -q --ff-only 2>&1 | Out-Null
	Set-Content -Path (Join-Path $board "mine.txt") -Value "mine"
	& git -C $board add mine.txt 2>&1 | Out-Null
	& git -C $board commit -q -m "mine, clean" 2>&1 | Out-Null
	Set-Content -Path (Join-Path $other "theirs.txt") -Value "theirs"
	& git -C $other add theirs.txt 2>&1 | Out-Null
	& git -C $other commit -q -m "theirs, clean" 2>&1 | Out-Null
	& git -C $other push -q origin HEAD:main 2>&1 | Out-Null
	$script:rebuilt = $false
	$clean = Publish-BenchBoard $board { $script:rebuilt = $true; "" }
	$top = (& git -C $origin log -1 --format=%s 2>$null | Select-Object -First 1)
	Test-Check "a push whose rebase is clean rebuilds, then publishes on the new base" ($clean.Code -eq 0 -and $script:rebuilt -and $top -eq "mine, clean") ($clean.Message + " rebuilt=$($script:rebuilt) top=$top")
} finally {
	$env:APPDATA = $savedAppData
}

Write-Output ""
Write-Output ("smoke_scripts: " + $(if ($failures -eq 0) { "all checks passed" } else { "$failures check(s) failed" }) + " (scratch: $Scratch)")
exit ([int]($failures -gt 0))
