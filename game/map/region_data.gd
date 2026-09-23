class_name RegionData
extends RefCounted
## The map's data texture of spec ui-foundation.md §7.2 and
## `loop-mechanics.md` §16.3.1: **two** pixels per region, rewritten on every
## tick and handed to the shader.
##
## Row 0 is the region's own numbers and its six flags; row 1 is what the
## interface is saying about it right now — the status colour, whether it is an
## eligible site, whether it is flashing, and whether a standing status draws its
## border.
##
## Pure and static, like `MapPicker`, so the encoding can be checked without a
## viewport: `MapView` owns the `Image` and the `ImageTexture`, this decides what
## is in them. The shader's decoding rules are the inverse of `encode`.

## Pixel `i` is region index `i`; pixel 0 is unused because index 0 is "no
## region". A world with a higher index than this row holds cannot be drawn.
const WIDTH: int = 256
## Row 0: the region. Row 1: what the interface says about it (§16.3.1).
const HEIGHT: int = 2
const ROW_REGION: int = 0
const ROW_INTERFACE: int = 1
const FORMAT: Image.Format = Image.FORMAT_RGBA8

## Row 1's R channel: 0 none, 1 a player status, 2…5 the faction of a world
## status (`Faction.FACTION_IDS` index + 2).
const STATUS_NONE: int = 0
const STATUS_PLAYER: int = 1
const STATUS_FACTION_BASE: int = 2
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
			encode_row1(world, i, eligible.has(i), flashing.has(i)))
	return true


## Row 1 of §16.3.1. The status colour is read off the status's **source**: a
## world status a chain applied has no faction, so anything that is not
## `faction:<id>` is the player's own colour.
##
## Statuses arrive with S4.2; until then the channel is always 0 and the row
## carries the eligibility of site select alone.
static func encode_row1(world: World, region_index: int, eligible: bool,
		flashing: bool) -> Color:
	return Color(
		float(status_index(world, region_index)) / 255.0,
		ON if eligible else OFF,
		ON if flashing else OFF,
		OFF)


## The status colour index of a region (§16.3.1). 0 until S4.2 fills
## `World.statuses`.
@warning_ignore("unused_parameter")
static func status_index(world: World, region_index: int) -> int:
	return STATUS_NONE


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
