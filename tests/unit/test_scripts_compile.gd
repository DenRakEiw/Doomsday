extends GutTest
## Every script in the project compiles — the whole project, not only what a test
## happens to touch.
##
## `tools/check_scripts.gd` runs the same scan before the suite, but it runs as
## the main loop and therefore without autoloads, so it cannot judge the scripts
## that name `Game` or `EventBus`. Inside the tree they resolve, and this is the
## test that says so.

const Scan := preload("res://tools/script_scan.gd")


func test_every_script_in_the_project_compiles() -> void:
	var paths: PackedStringArray = Scan.collect()
	assert_gt(paths.size(), 0, "the scan must find something")
	var failed: PackedStringArray = Scan.failures(paths)
	assert_eq(failed, PackedStringArray(), "scripts that do not compile")
