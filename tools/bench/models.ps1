<#
.SYNOPSIS
The model catalogue: OpenRouter's public model list with what a benchmark suite of each
model would likely cost (docs/specs/benchmark.md section 18.4). No key is needed or sent.

.DESCRIPTION
Runs tools/bench/model_list.gd headless. The table shows each model's context, price per
million input and output tokens, whether it reasons ("always" = it cannot switch reasoning
off), and the likely cost of the quick (3 seeds) and standard (10 seeds) suites at the
effort level normal, and of the standard suite at high and ultra - by the benchmark tool's
own pre-flight rule. "*" marks a free model; typesafe/jev-latest (the decision model) is
listed first at its published price.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\bench\models.ps1 -Search claude
.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\bench\models.ps1 -Free
.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\bench\models.ps1 -MaxCost 5 -Effort high
#>
param(
	# Only models whose id or name contains this text (any case).
	[string]$Search = "",
	# Only free models (":free" ids and models priced at zero).
	[switch]$Free,
	# Only models whose likely cost of -Suite at -Effort is at most this many USD.
	[double]$MaxCost = -1,
	# The suite -MaxCost is judged on.
	[ValidateSet("standard", "quick")][string]$Suite = "standard",
	# Show both suites at this one level instead of the four default columns.
	[ValidateSet("", "normal", "high", "ultra")][string]$Effort = "",
	# Read the list from a saved GET /models body instead of the network (tests).
	[string]$Prices = "",
	# The Godot console executable (default: $env:GODOT, then .claude/settings.local.json).
	[string]$Godot = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "bench_common.ps1")

$godotExe = Resolve-BenchGodot $Godot
$arguments = @("-s", "tools/bench/model_list.gd", "--", "--suite=$Suite")
if ($Search) { $arguments += "--search=$Search" }
if ($Free) { $arguments += "--free" }
if ($MaxCost -ge 0) { $arguments += ("--max-cost=" + $MaxCost.ToString([Globalization.CultureInfo]::InvariantCulture)) }
if ($Effort) { $arguments += "--effort=$Effort" }
if ($Prices) { $arguments += "--prices=" + (Resolve-Path $Prices).Path }

$result = Invoke-BenchGodot $godotExe $arguments
# Godot's own banner and the game's version line are not the table.
$result.Lines | Where-Object { $_ -notmatch "^(Godot Engine|Doomsday \d)" } | ForEach-Object { Write-Output $_ }
exit $result.Code
