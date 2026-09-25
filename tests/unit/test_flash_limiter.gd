extends GutTest
## S6.1 — the photosensitivity guard of spec polish-visuals.md §6: at most three
## full-screen flashes a second, never two closer than a third of one.


func test_first_flash_is_allowed() -> void:
	assert_true(FlashLimiter.new().allow(0))


func test_flash_within_min_gap_is_refused() -> void:
	var limiter: FlashLimiter = FlashLimiter.new()
	assert_true(limiter.allow(1000))
	assert_false(limiter.allow(1000 + UiTokens.FLASH_MIN_GAP - 1))
	assert_true(limiter.allow(1000 + UiTokens.FLASH_MIN_GAP), "a refusal is not counted")


func test_fourth_flash_in_one_second_is_refused() -> void:
	var limiter: FlashLimiter = FlashLimiter.new()
	# Three as fast as the gap allows; a fourth before the first leaves the
	# window is refused.
	var now: int = 0
	for i: int in UiTokens.FLASH_MAX:
		assert_true(limiter.allow(now), "flash %d" % i)
		now += UiTokens.FLASH_MIN_GAP
	assert_false(limiter.allow(UiTokens.FLASH_WINDOW - 1))


func test_flash_after_window_is_allowed_again() -> void:
	var limiter: FlashLimiter = FlashLimiter.new()
	var now: int = 0
	for i: int in UiTokens.FLASH_MAX:
		limiter.allow(now)
		now += UiTokens.FLASH_MIN_GAP
	assert_true(limiter.allow(UiTokens.FLASH_WINDOW + UiTokens.FLASH_MIN_GAP))
