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

# "Continue", not "Stop": with "Stop", anything Godot writes to stderr — an
# engine error, a `push_error` a test is *asserting* on — becomes a terminating
# NativeCommandError and the run dies half-way through. The exit codes below are
# what decides whether this script failed.
$ErrorActionPreference = "Continue"

$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
$root = Split-Path -Parent $PSScriptRoot

& $godot --headless --path $root --import
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# --import does not parse scripts, and GUT only compiles what a test touches, so
# every script is checked in between.
& $godot --headless --path $root -s tools/check_scripts.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# A key the code names and the string table lacks fails here, before any test
# could render it as its own name (UI.md §4).
& $godot --headless --path $root -s tools/check_strings.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# The GUT arguments are quoted: PowerShell otherwise splits `-name=value` into
# two tokens and GUT rejects the value as an unknown argument.
& $godot --headless --path $root -s addons/gut/gut_cmdln.gd "-gconfig=.gutconfig.json" "-gexit" @args
exit $LASTEXITCODE
