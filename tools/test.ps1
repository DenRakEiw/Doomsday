#!/usr/bin/env pwsh
# Runs the headless test suite. Exit code 0 means every test passed.
#
# The Godot executable comes from $env:GODOT, otherwise `godot` on PATH. On
# Windows point GODOT at the *_console.exe* build or the headless output never
# reaches the terminal.
#
# Extra arguments are passed straight to GUT, e.g.
#   tools\test.ps1 -gtest=res://tests/unit/test_smoke.gd
#   tools\test.ps1 -gunit_test_name=test_spread

$ErrorActionPreference = "Stop"

$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
$root = Split-Path -Parent $PSScriptRoot

& $godot --headless --path $root --import
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# The GUT arguments are quoted: PowerShell otherwise splits `-name=value` into
# two tokens and GUT rejects the value as an unknown argument.
& $godot --headless --path $root -s addons/gut/gut_cmdln.gd "-gconfig=.gutconfig.json" "-gexit" @args
exit $LASTEXITCODE
