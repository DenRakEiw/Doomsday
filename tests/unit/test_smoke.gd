extends GutTest
## Smoke test for the test framework itself: GUT is installed and enabled, the
## headless runner discovers `res://tests`, and a fully typed test script passes
## the project's strict GDScript warnings. Every later step builds on this.


func test_a_typed_test_script_runs() -> void:
	var answer: int = 6 * 7
	assert_eq(answer, 42, "arithmetic works inside a typed test script")


func test_project_is_the_doomsday_project() -> void:
	var project_name: String = str(ProjectSettings.get_setting("application/config/name"))
	assert_eq(project_name, "Doomsday", "the runner opened this project, not another one")
