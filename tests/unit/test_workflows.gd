extends GutTest
## S6.12b — the leaderboard workflow's safety rules (docs/specs/benchmark.md §16.5),
## read from the file as text: it never runs on a pull request, its token is
## read-only, the deploy key reaches a step only through `env`, GitHub's host key
## is pinned, and workflow commands are stopped around the verifier's output.

const WORKFLOW: String = "res://.github/workflows/leaderboard.yml"
const TRIGGERS: Array[String] = ["schedule", "workflow_dispatch"]
const SECRET: String = "secrets.LEADERBOARD_DEPLOY_KEY"
const SUBMIT_SECRET: String = "secrets.SUPABASE_SECRET_KEY"
const KNOWN_HOST: String = "github.com ssh-ed25519" \
	+ " AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"
const STOP: String = "echo \"::stop-commands::$token\""
const RESUME: String = "echo \"::$token::\""
const COLLECTOR: String = "tools/bench/collect_submissions.gd"
const VERIFIER: String = "tools/bench/verify_runs.gd"

var _lines: PackedStringArray = []
var _text: String = ""


func before_all() -> void:
	_text = FileAccess.get_file_as_string(WORKFLOW)
	_lines = _text.replace("\r", "").split("\n")


func _indent(line: String) -> int:
	return line.length() - line.lstrip(" ").length()


func _is_content(line: String) -> bool:
	return not line.strip_edges().is_empty() and not line.strip_edges().begins_with("#")


## The key a line sits under: the nearest earlier content line indented less.
func _parent(index: int) -> String:
	var own: int = _indent(_lines[index])
	for i: int in range(index - 1, -1, -1):
		if _is_content(_lines[i]) and _indent(_lines[i]) < own:
			return _lines[i].strip_edges()
	return ""


func test_it_runs_on_a_schedule_and_by_hand_only() -> void:
	assert_false(_text.is_empty(), "the workflow exists")
	var triggers: Array[String] = []
	var inside: bool = false
	for line: String in _lines:
		if not _is_content(line):
			continue
		if _indent(line) == 0:
			inside = line.strip_edges() == "on:"
			continue
		if inside and _indent(line) == 2:
			triggers.append(line.strip_edges().trim_suffix(":"))
	assert_eq(triggers, TRIGGERS)
	assert_false(_text.contains("pull_request"), "no pull request trigger of any kind")


func test_its_token_reads_only() -> void:
	var index: int = _lines.find("permissions:")
	assert_true(index >= 0)
	assert_eq(_lines[index + 1], "  contents: read")
	assert_false(_text.contains(": write"), "nothing asks to write")


func test_the_deploy_key_reaches_a_step_only_through_env() -> void:
	var uses: int = 0
	var shape: RegEx = RegEx.create_from_string(
		"^ +[A-Z_]+: \\$\\{\\{ secrets\\.(LEADERBOARD_DEPLOY_KEY|SUPABASE_SECRET_KEY).*\\}\\}$")
	for i: int in _lines.size():
		if not _lines[i].contains("secrets."):
			continue
		uses += 1
		assert_true(_lines[i].contains(SECRET) or _lines[i].contains(SUBMIT_SECRET),
			"no other secret: " + _lines[i])
		assert_not_null(shape.search(_lines[i]), "an env value, nothing else: " + _lines[i])
		assert_eq(_parent(i), "env:", "under an env block: " + _lines[i])
	assert_gt(uses, 0)


func test_workflow_commands_are_stopped_around_the_collector() -> void:
	var collect: int = _text.find(COLLECTOR)
	var stop: int = _text.rfind(STOP, collect)
	var resume: int = _text.find(RESUME, collect)
	assert_true(stop >= 0 and collect >= 0 and resume >= 0)
	assert_true(stop < collect and collect < resume, "stop, collect, resume")


func test_the_host_key_is_pinned_and_never_scanned() -> void:
	assert_true(_text.contains(KNOWN_HOST))
	assert_true(_text.contains("StrictHostKeyChecking=yes"))
	assert_false(_text.contains("ssh-keyscan"))


func test_workflow_commands_are_stopped_around_the_verifier() -> void:
	var run: int = _text.find(VERIFIER)
	var stop: int = _text.rfind(STOP, run)
	var resume: int = _text.find(RESUME, run)
	assert_true(stop >= 0 and run >= 0 and resume >= 0)
	assert_true(stop < run and run < resume, "stop, verify, resume")


## S6.13 (benchmark.md §16.6, release.md §9.2): the release export refreshes the
## shipped copy of the global leaderboard before it exports, and keeps the
## committed one when the download fails.
func test_the_release_export_refreshes_the_shipped_board_first() -> void:
	var release: String = FileAccess.get_file_as_string("res://.github/workflows/release.yml")
	var refresh: int = release.find("The shipped copy of the global leaderboard")
	var export: int = release.find("--export-release \"Windows\"")
	assert_gt(refresh, 0, "the refresh step exists")
	assert_lt(refresh, export, "and runs before the export")
	assert_string_contains(release, "mv /tmp/leaderboard.json benchmark/global/leaderboard.json")
	var step: String = release.substr(refresh, release.find("- name:", refresh) - refresh)
	assert_string_contains(step, "if curl -fsSL --max-time 30",
		"a failed download is not a failed build")
