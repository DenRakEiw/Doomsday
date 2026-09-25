extends GutTest
## S6.8 — the pace of a spoken channel (accessibility.md §3.4): one text per gap,
## the newest waiting text wins.

const GAP_MS: int = 8000


func test_the_first_push_is_due_at_once() -> void:
	var queue: LiveQueue = LiveQueue.new(GAP_MS)
	queue.push("one", 100)
	assert_eq(queue.pop_due(100), "one")


func test_a_second_push_within_the_gap_waits() -> void:
	var queue: LiveQueue = LiveQueue.new(GAP_MS)
	queue.push("one", 0)
	queue.pop_due(0)
	queue.push("two", 1000)
	assert_eq(queue.pop_due(1000), "", "inside the gap")
	assert_eq(queue.pop_due(GAP_MS), "two", "once the gap is over")


func test_a_third_push_within_the_gap_replaces_the_second() -> void:
	var queue: LiveQueue = LiveQueue.new(GAP_MS)
	queue.push("one", 0)
	queue.pop_due(0)
	queue.push("two", 1000)
	queue.push("three", 2000)
	assert_eq(queue.pop_due(GAP_MS), "three")
	assert_eq(queue.pop_due(GAP_MS * 3), "", "the second was dropped, not kept")


func test_nothing_due_is_an_empty_text() -> void:
	var queue: LiveQueue = LiveQueue.new(GAP_MS)
	assert_eq(queue.pop_due(0), "")
	assert_false(queue.has_waiting())
