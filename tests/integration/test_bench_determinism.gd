extends GutTest
## S6.12b — the cross-platform canary (docs/specs/benchmark.md §16.8): a mock
## benchmark run of 300 days recorded on Windows must replay to its recorded
## state hash here. The suite runs it on Windows and CI on Linux, so a divergence
## between the platforms turns CI red — and the verifier, which judges runs
## recorded anywhere on a Linux runner, uses the same file as its canary.

const Verifier := preload("res://tools/bench/bench_verifier.gd")
const VerifyRecord := preload("res://tools/bench/verify_record.gd")
const FIXTURE: String = "res://tests/fixtures/bench/determinism_entry.json"
const REGENERATE: String = "content changed — regenerate on Windows: \"$GODOT\" --headless" \
	+ " --path . -s tools/bench/bench_run.gd -- --determinism-fixture"


func test_the_windows_recorded_run_replays_to_its_hash_here() -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(FIXTURE)
	var entry: BenchEntry = BenchEntry.from_bytes(bytes)
	assert_not_null(entry, "the fixture reads: %s" % BenchEntry.last_error)
	if entry == null:
		return
	var db: ContentDB = ContentLoader.load_root("res://data").db
	# Another content hash is not a platform divergence: the fixture is stale.
	assert_eq(entry.content_hash, db.content_hash, REGENERATE)
	if entry.content_hash != db.content_hash:
		return
	var record: VerifyRecord = Verifier.check_canary(bytes, BenchConfig.load_file(), db,
		{Verifier.CONTEXT_COMMIT: ""})
	assert_true(record.verified, "this platform does not reproduce the Windows run: %s — %s"
		% [record.reason, record.detail])
	assert_eq(record.state_hash, entry.state_hash)
