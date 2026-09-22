class_name RegionData
extends RefCounted
## The map's data texture of spec ui-foundation.md §7.2: one pixel per region,
## rewritten on every tick and handed to the shader.
##
## Pure and static, like `MapPicker`, so the encoding can be checked without a
## viewport: `MapView` owns the `Image` and the `ImageTexture`, this decides what
## is in them. The shader's decoding rules are the inverse of `encode`.

## Pixel `i` is region index `i`; pixel 0 is unused because index 0 is "no
## region". A world with a higher index than this row holds cannot be drawn.
const WIDTH: int = 256
const FORMAT: Image.Format = Image.FORMAT_RGBA8

## The A channel, bit by bit. The shader reads them back with
## `int(round(a * 255.0))`.
const FLAG_SEEDED: int = 1
const FLAG_DARK: int = 2
const FLAG_AIR_GAPPED: int = 4
const FLAG_CONTROLLED: int = 8
const FLAG_ANOMALY: int = 16


## An all-zero row: no region, no flags. Every pixel is overwritten by `write`
## before it is drawn, so the contents matter only for a world smaller than the
## row.
static func create_image() -> Image:
	return Image.create_empty(WIDTH, 1, false, FORMAT)


## Fills `image` from `world`. False means the world does not fit the row and
## nothing was written — the caller reports it; a silently wrapped index would
## paint one region with another's numbers.
static func write(image: Image, world: World, db: ContentDB) -> bool:
	if highest_index(world) >= WIDTH:
		return false
	var with_anomaly: Dictionary[int, bool] = {}
	for anomaly: Anomaly in world.anomalies:
		with_anomaly[anomaly.region] = true
	for i: int in range(1, world.regions.size()):
		image.set_pixel(i, 0,
			encode(world.regions[i], db.balance.control_complete, with_anomaly.has(i)))
	return true


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
