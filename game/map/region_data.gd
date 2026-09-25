class_name RegionData
extends RefCounted
## The map's data texture of spec ui-foundation.md §7.2 and
## `loop-mechanics.md` §16.3.1: **three** pixels per region, rewritten on every
## tick and handed to the shader.
##
## Row 0 is the region's own numbers and its six flags; row 1 is what the
## interface is saying about it right now — the status colour, whether it is an
## eligible site, whether it is flashing, and whether a standing status draws its
## border; row 2 is its Societal Function stage (polish-visuals.md §10.1).
##
## Pure and static, like `MapPicker`, so the encoding can be checked without a
## viewport: `MapView` owns the `Image` and the `ImageTexture`, this decides what
## is in them. The shader's decoding rules are the inverse of `encode`.

## Pixel `i` is region index `i`; pixel 0 is unused because index 0 is "no
## region". A world with a higher index than this row holds cannot be drawn.
const WIDTH: int = 256
## Row 0: the region. Row 1: what the interface says about it (§16.3.1).
## Row 2: the Societal Function stage (polish-visuals.md §10.1).
const HEIGHT: int = 3
const ROW_REGION: int = 0
const ROW_INTERFACE: int = 1
const ROW_SOCIETY: int = 2
const FORMAT: Image.Format = Image.FORMAT_RGBA8

## Row 1's R channel: 0 none, 1 a player status, 2…5 the faction of a world
## status (`Faction.FACTION_IDS` index + 2), 6 the Task Force's (G5 1/3).
const STATUS_NONE: int = 0
const STATUS_PLAYER: int = 1
const STATUS_FACTION_BASE: int = 2
const STATUS_TASK_FORCE: int = 6
## The G and B channels are flags, so they are full or nothing.
const ON: float = 1.0
const OFF: float = 0.0

## The A channel, bit by bit. The shader reads them back with
## `int(round(a * 255.0))`.
const FLAG_SEEDED: int = 1
const FLAG_DARK: int = 2
const FLAG_AIR_GAPPED: int = 4
const FLAG_CONTROLLED: int = 8
const FLAG_ANOMALY: int = 16
## m3-screens §8.1: a held region keeps its colour at half strength.
const FLAG_DORMANT: int = 32


## An all-zero row: no region, no flags. Every pixel is overwritten by `write`
## before it is drawn, so the contents matter only for a world smaller than the
## row.
static func create_image() -> Image:
	return Image.create_empty(WIDTH, HEIGHT, false, FORMAT)


## Fills `image` from `world`. False means the world does not fit the row and
## nothing was written — the caller reports it; a silently wrapped index would
## paint one region with another's numbers.
## `eligible` holds the region indices site select is offering, `flashing` the
## ones in a scope flash (§16.2). Both are empty outside those moments.
static func write(image: Image, world: World, db: ContentDB,
		eligible: Dictionary[int, bool] = {}, flashing: Dictionary[int, bool] = {}) -> bool:
	if highest_index(world) >= WIDTH:
		return false
	var with_anomaly: Dictionary[int, bool] = {}
	for anomaly: Anomaly in world.anomalies:
		with_anomaly[anomaly.region] = true
	for i: int in range(1, world.regions.size()):
		image.set_pixel(i, ROW_REGION,
			encode(world.regions[i], db.balance.control_complete, with_anomaly.has(i)))
		image.set_pixel(i, ROW_INTERFACE,
			encode_row1(world, db, i, eligible.has(i), flashing.has(i)))
		image.set_pixel(i, ROW_SOCIETY, encode_society(world.regions[i], db.balance))
	return true


## Row 2 of polish-visuals.md §10.1: R is the stage (0…5) stored the way the
## flags are, `stage / 255`, so the shader reads an integer back and never sees
## the thresholds; G, B and A are reserved.
static func encode_society(region: Region, balance: BalanceDef) -> Color:
	var stage: int = SocietalFunctionSystem.stage(region.society, balance)
	return Color(float(stage) / 255.0, OFF, OFF, OFF)


## The stage a row-2 pixel carries, decoded the way the shader decodes it.
static func society_stage_of(pixel: Color) -> int:
	return roundi(pixel.r * 255.0)


## Row 1 of §16.3.1. The status colour is read off the status's **source**: a
## world status a chain applied has no faction, so anything that is not
## `faction:<id>` is the player's own colour.
static func encode_row1(world: World, db: ContentDB, region_index: int, eligible: bool,
		flashing: bool) -> Color:
	return Color(
		float(status_index(world, region_index)) / 255.0,
		ON if eligible else OFF,
		ON if flashing else OFF,
		ON if has_border(world, db, region_index) else OFF)


## The status colour index of a region (§16.3.1): 0 for none, 1 for one of the
## player's own, the faction's index + 2 for the world's, and
## `STATUS_TASK_FORCE` for one the team put there (`UiTokens.status_token`).
##
## The world wins over the player's; among the world's — the team's included —
## the one with the most days left — a standing status (−1 day left) never wins that, because the one
## that is about to end is the one the border is about to lose.
static func status_index(world: World, region_index: int) -> int:
	var best: int = STATUS_NONE
	var best_days: int = -2
	for status: Status in world.statuses_in_region(region_index):
		var candidate: int = STATUS_NONE
		if UiTokens.is_task_force_source(status.source):
			candidate = STATUS_TASK_FORCE
		else:
			var index: int = Faction.FACTION_IDS.find(status.faction())
			if index >= 0:
				candidate = STATUS_FACTION_BASE + index
		if candidate == STATUS_NONE:
			if best == STATUS_NONE:
				best = STATUS_PLAYER
			continue
		var days: int = status.days_left(world.day)
		if best >= STATUS_FACTION_BASE and days <= best_days:
			continue
		best = candidate
		best_days = days
	return best


## Whether a status standing in the region draws its border (§16.3.1). The A
## channel is a flag on row 1, not the bit field row 0 carries.
static func has_border(world: World, db: ContentDB, region_index: int) -> bool:
	if db == null:
		return false
	for status: Status in world.statuses_in_region(region_index):
		var definition: StatusDef = db.status(status.id)
		if definition != null and definition.border:
			return true
	return false


## One region as the pixel §7.2 describes. `alive / population` rather than the
## deaths share, so a region that was never touched is full.
static func encode(region: Region, control_complete: float, has_anomaly: bool) -> Color:
	var population: float = float(region.def.population)
	var alive_share: float = 1.0 if population <= 0.0 else clampf(
		region.alive / population, 0.0, 1.0)
	var flags: int = 0
	if region.seeded_day >= 0:
		flags |= FLAG_SEEDED
	if region.dark:
		flags |= FLAG_DARK
	if region.air_gapped:
		flags |= FLAG_AIR_GAPPED
	if region.control >= control_complete:
		flags |= FLAG_CONTROLLED
	if has_anomaly:
		flags |= FLAG_ANOMALY
	if region.dormant:
		flags |= FLAG_DORMANT
	return Color(
		clampf(region.penetration, 0.0, 1.0),
		clampf(region.control, 0.0, 1.0),
		alive_share,
		float(flags) / 255.0)


## The flags of a pixel, decoded the way the shader decodes them. For tests and
## for anything that reads the texture back.
static func flags_of(pixel: Color) -> int:
	return roundi(pixel.a * 255.0)


## The largest region index the world uses. `regions[0]` is null, so an empty
## world answers 0 — which fits any row.
static func highest_index(world: World) -> int:
	return maxi(world.regions.size() - 1, 0)
