# Shared helpers of the benchmark scripts (docs/specs/benchmark.md section 18). Dot-source it:
#   . (Join-Path $PSScriptRoot "bench_common.ps1")
# Nothing here prints a key: Get-BenchKey only tells whether one was found.

function Get-BenchRoot {
	# The game repository: two levels above tools/bench.
	return (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

function Resolve-BenchGodot([string]$Given) {
	# The Godot console executable: -Godot, else $env:GODOT, else the per-machine
	# .claude/settings.local.json (env.GODOT), else `godot` on PATH.
	if ($Given) { return $Given }
	if ($env:GODOT) { return $env:GODOT }
	$settings = Join-Path (Get-BenchRoot) ".claude\settings.local.json"
	if (Test-Path $settings) {
		try {
			$json = Get-Content -Raw -Encoding UTF8 $settings | ConvertFrom-Json
			if ($json.env -and $json.env.GODOT) { return [string]$json.env.GODOT }
		} catch { }
	}
	$found = Get-Command godot -ErrorAction SilentlyContinue
	if ($found) { return $found.Source }
	throw "Godot not found: pass -Godot <path to the *_console.exe>, or set GODOT."
}

function Import-BenchKey([string]$Name) {
	# Makes the key visible to the child processes: from this process's
	# environment, else from the user's (HKCU\Environment, where set_api_key.ps1
	# stores it - a window opened before that does not see it). Returns whether
	# a key was found; the key itself is never printed or returned.
	$value = [Environment]::GetEnvironmentVariable($Name, "Process")
	if (-not $value) {
		$value = [Environment]::GetEnvironmentVariable($Name, "User")
		if ($value) { [Environment]::SetEnvironmentVariable($Name, $value, "Process") }
	}
	return [bool]$value
}

function Invoke-BenchGodot([string]$Godot, [string[]]$Arguments) {
	# Runs a headless Godot tool in the game repository and returns
	# @{ Code = <exit code>; Lines = <stdout lines> }.
	# "Continue": in Windows PowerShell 5.1 a native program's stderr would
	# otherwise become a terminating error; the exit code decides.
	$ErrorActionPreference = "Continue"
	$root = Get-BenchRoot
	$lines = & $Godot --headless --path $root @Arguments 2>$null
	return @{ Code = $LASTEXITCODE; Lines = @($lines) }
}

function Get-BenchSlug([string]$Model) {
	# benchmark.md section 10.2's slug: lower-case, `/` -> `--`, anything else outside [a-z0-9._-] -> `-`.
	$lowered = $Model.ToLowerInvariant().Replace("/", "--")
	return ($lowered -replace "[^a-z0-9._-]", "-")
}
