<#
.SYNOPSIS
End-to-end check of the benchmark scripts without a key and without touching anything real
(docs/specs/benchmark.md section 18.7).

.DESCRIPTION
In a scratch folder (default: a new one under %TEMP%), with a scratch APPDATA for every Godot
process:
1. parses every tools\bench\*.ps1 (System.Management.Automation.Language.Parser);
2. models.ps1 on the fixture price list;
3. run_models.ps1 -Mock: two mock models, effort high, the quick suite, two processes each;
4. a bare clone of the leaderboard repository as a stand-in origin, and a clone of that;
5. submit_runs.ps1 -IncludeMock without -Push (the clone must stay as it was), then with
   -Push -VerifyLocally -SkipBots (the stand-in origin must receive the runs, verified, and
   a leaderboard whose rows carry the effort).
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

	# 3 - two mock models, effort high, two processes each.
	$run = Invoke-Script "run_models.ps1" @("-Models", "mock/alpha,mock/beta", "-Effort", "high",
		"-Suite", "quick", "-Parallel", "2", "-Mock", "-Yes", "-LogDir", (Join-Path $Scratch "logs"), "-Godot", $godotExe)
	$runsDir = Join-Path $env:APPDATA "Doomsday\benchmark\runs"
	$written = @(Get-ChildItem -Path $runsDir -Filter "*.json" -ErrorAction SilentlyContinue)
	Test-Check "run_models.ps1 -Mock plays both models" ($run.Code -eq 0 -and $written.Count -eq 6) $run.Text
	Test-Check "run_models.ps1 summary names the effort" ($run.Text -match "mock/alpha\s+high\s+3") $run.Text

	# 4 - a stand-in origin and a clone of it.
	$origin = Join-Path $Scratch "origin.git"
	$board = Join-Path $Scratch "board"
	& git clone -q --bare $Source $origin 2>&1 | Out-Null
	& git clone -q $origin $board 2>&1 | Out-Null
	& git -C $board config user.name "smoke" 2>&1 | Out-Null
	& git -C $board config user.email "smoke@example.invalid" 2>&1 | Out-Null
	$before = (& git -C $origin rev-parse HEAD 2>$null | Select-Object -First 1)

	# 5a - a dry run changes nothing.
	$dry = Invoke-Script "submit_runs.ps1" @("-Board", $board, "-Runs", $runsDir, "-IncludeMock", "-Godot", $godotExe)
	$clean = -not ((& git -C $board status --porcelain 2>$null) -join "").Trim()
	Test-Check "submit_runs.ps1 dry run validates and leaves the clone clean" ($dry.Code -eq 0 -and $clean -and $dry.Text.Contains("dry run")) $dry.Text

	# 5b - push, verified here.
	$push = Invoke-Script "submit_runs.ps1" @("-Board", $board, "-Runs", $runsDir, "-IncludeMock", "-Push",
		"-VerifyLocally", "-SkipBots", "-Godot", $godotExe)
	$after = (& git -C $origin rev-parse HEAD 2>$null | Select-Object -First 1)
	$records = @(Get-ChildItem -Path (Join-Path $board "verified") -Filter "*.json" -ErrorAction SilentlyContinue)
	$verified = @($records | Where-Object { (Get-Content -Raw -Encoding UTF8 $_.FullName) -match '"verified":\s*true' })
	$boardJson = Get-Content -Raw -Encoding UTF8 (Join-Path $board "leaderboard.json")
	Test-Check "submit_runs.ps1 -Push -VerifyLocally pushes to the stand-in origin" ($push.Code -eq 0 -and $after -ne $before) $push.Text
	Test-Check "every submitted run is verified" ($records.Count -eq 6 -and $verified.Count -eq 6) "$($records.Count) records, $($verified.Count) verified"
	Test-Check "the published rows carry the effort" ($boardJson -match '"effort":\s*"high"')
} finally {
	$env:APPDATA = $savedAppData
}

Write-Output ""
Write-Output ("smoke_scripts: " + $(if ($failures -eq 0) { "all checks passed" } else { "$failures check(s) failed" }) + " (scratch: $Scratch)")
exit ([int]($failures -gt 0))
