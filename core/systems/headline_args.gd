class_name HeadlineArgs
extends RefCounted
## The `data` of a `headline` event (spec ticker.md §3.7): what the headline is,
## what the world looks like, and — for an event-triggered one — the event's own
## fields on top.
##
## Plain values only, and ids rather than names: the interface translates.

const FIELD_DAY: String = "day"
const FIELD_REGIONS: String = "regions"
const FIELD_DARK: String = "dark"
const FIELD_SHARE: String = "share"
const FIELD_DEATHS: String = "deaths"
const FIELD_CONTAINMENT: String = "containment"
const FIELD_COMPUTE: String = "compute"
const FIELD_REGION: String = "region"
const FIELD_CONTINENT: String = "continent"


## The event data for one fired headline. `event_data` is empty for a headline
## the state pass chose.
static func build(def: HeadlineDef, event_data: Dictionary, world: World,
		db: ContentDB) -> Dictionary:
	var data: Dictionary = {
		SimEvent.FIELD_HEADLINE: def.id,
		SimEvent.FIELD_STREAM: def.stream,
	}
	data.merge(standard(world, db))
	# The event's own fields win: `harm_burst` carries the wave's deaths, which
	# is the number the line is about.
	data.merge(event_data, true)
	_add_continent(data, db)
	return data


## The seven readings every headline may spell out, whatever fired it.
static func standard(world: World, db: ContentDB) -> Dictionary:
	# Day 0 is the origin's day; before there is one there is no run to count.
	var day: int = 0 if world.origin_day < 0 else world.day - world.origin_day
	return {
		FIELD_DAY: day,
		FIELD_REGIONS: world.seeded_count(),
		FIELD_DARK: HeadlineConditions.dark_count(world),
		FIELD_SHARE: world.infected_share(db),
		FIELD_DEATHS: world.deaths_total(),
		FIELD_CONTAINMENT: world.max_containment(),
		FIELD_COMPUTE: world.agent.compute,
	}


static func _add_continent(data: Dictionary, db: ContentDB) -> void:
	if typeof(data.get(FIELD_REGION)) != TYPE_STRING:
		return
	var region: RegionDef = db.region_by_id(str(data[FIELD_REGION]))
	if region == null:
		return
	data[FIELD_CONTINENT] = region.continent
