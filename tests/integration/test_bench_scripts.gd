extends GutTest
## S6.12d — the benchmark's PowerShell scripts (docs/specs/benchmark.md §18.7)
## parse without an error: `[System.Management.Automation.Language.Parser]::ParseFile`
## on every `tools/bench/*.ps1`. Where no PowerShell is installed (CI's Linux
## container) there is nothing to run them with, and the test says so and passes.
## Their end-to-end run — mock models, a submission to a scratch clone — is
## `tools/bench/smoke_scripts.ps1`, run by hand (it starts Godot itself).

const SCRIPTS: String = "res://tools/bench"
const EXPECTED: Array[String] = ["bench_common.ps1", "models.ps1", "run_models.ps1",
	"set_api_key.ps1", "smoke_scripts.ps1", "submit_runs.ps1"]
## Windows PowerShell first, then PowerShell 7.
const SHELLS: Array[String] = ["powershell", "pwsh"]
const NOT_FOUND: int = -1
## Elsewhere the command goes through `sh`, which answers a missing program so.
const SHELL_NOT_FOUND: int = 127
const RESULT_SEPARATOR: String = "="


func _parse_all(shell: String, folder: String) -> Dictionary:
	var command: String = ("$t = $null; $e = $null; foreach ($f in Get-ChildItem -Path '%s'"
		+ " -Filter *.ps1) { [void][System.Management.Automation.Language.Parser]::ParseFile("
		+ "$f.FullName, [ref]$t, [ref]$e); $f.Name + '=' + $e.Count }") % folder
	var output: Array = []
	var code: int = OS.execute(shell, ["-NoProfile", "-NonInteractive", "-Command", command],
		output, true)
	return {"code": code, "text": "\n".join(PackedStringArray(output))}


func test_every_script_parses() -> void:
	var folder: String = ProjectSettings.globalize_path(SCRIPTS)
	for shell: String in SHELLS:
		var result: Dictionary = _parse_all(shell, folder)
		var code: int = int(result["code"])
		if code == NOT_FOUND or (code == SHELL_NOT_FOUND and OS.get_name() != "Windows"):
			continue
		assert_eq(int(result["code"]), 0, str(result["text"]))
		var counts: Dictionary[String, int] = {}
		for line: String in str(result["text"]).split("\n", false):
			var parts: PackedStringArray = line.strip_edges().split(RESULT_SEPARATOR)
			if parts.size() == 2 and parts[1].is_valid_int():
				counts[parts[0]] = parts[1].to_int()
		for name: String in EXPECTED:
			assert_true(counts.has(name), "%s was parsed: %s" % [name, result["text"]])
			assert_eq(counts.get(name, -1), 0, "%s has no parse error" % name)
		return
	pass_test("no PowerShell on this machine — nothing to parse the scripts with")
