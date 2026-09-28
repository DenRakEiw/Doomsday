extends GutHookScript
## Runs once before the suite (`.gutconfig.json`, `pre_run_script`).
##
## `Settings` reads `user://settings.json`, which the game shares with the test
## runner, and since S4.9 the text scale in it reaches every themed control. A
## scale left at 150 % by a play session would move every layout the tests
## measure, so the suite starts at the default. Nothing is written: the player's
## file keeps what the player chose.


## The profile (S5.3) is written by every run that ends in front of the game, so
## the suite gets a file of its own, emptied at the start.
const TEST_PROFILE: String = "user://test_profile.json"
## The saves likewise (S6.10): the run-flow tests write and delete the autosave,
## which used to be the player's own — a stray day-0 run on the title was one.
const TEST_SAVES: String = "user://test_saves/"
## The benchmark list's folders likewise (S6.13): the player's recorded runs and
## their online cache are never read or written by a test. The shipped showcase
## stays where it is (the build's own, empty until G6).
const TEST_BENCH_RUNS: String = "user://test_bench_library/runs/"
const TEST_BENCH_DEV: String = "user://test_bench_library/dev/"
const TEST_BENCH_ONLINE: String = "user://test_bench_online/"
## The player's own benchmark (S6.12f): job folders, entries and cache of a
## stray start never land in the player's `benchmark/`, and no test reads the
## real key store.
const TEST_BENCH_JOBS: String = "user://test_bench_jobs/"
## S6.12g: the model list's cache and *Submit*'s folder likewise.
const TEST_BENCH_MODELS: String = "user://test_bench_models/"
const TEST_BENCH_SUBMIT: String = "user://test_bench_submit/"


func run() -> void:
	Settings.text_scale = Settings.DEFAULT_TEXT_SCALE
	ProfileManager.use_path(TEST_PROFILE)
	SaveManager.save_dir = TEST_SAVES
	BenchLibrary.user_dir = TEST_BENCH_RUNS
	BenchLibrary.dev_dir = TEST_BENCH_DEV
	GlobalBoardClient.default_cache_dir = TEST_BENCH_ONLINE
	BenchJobs.out_dir = TEST_BENCH_JOBS
	ModelListCache.default_dir = TEST_BENCH_MODELS
	BenchGroup.submit_root = TEST_BENCH_SUBMIT
	BenchJobs.key_store.backend_override = func(_op: String, _key: String) -> Dictionary:
		return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_ERROR}
	# *Reset progress* keeps the achievements (release.md §2.2); the suite's
	# profile starts without them all the same.
	ProfileManager.achievements.clear()
	ProfileManager.reset()
