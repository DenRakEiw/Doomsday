class_name SiteRequest
extends RefCounted
## One question the map is asked: **where** (`loop-mechanics.md` §16.1).
##
## The origin prompt, *Buy and place* on a deploying node and, from S4.2, an
## ability's target are the same mode with different callables: what is eligible,
## what command a region would build, and what happens when the player backs out.
##
## Presentation only — the simulation knows nothing about site select.

const KIND_ORIGIN: String = "origin"
const KIND_DEPLOY: String = "deploy"
const KIND_ABILITY: String = "ability"
## m3-screens §7.2's heading, which the origin request carries.
const KEY_ORIGIN_PROMPT: String = "UI_ORIGIN_PROMPT"

## Which of the three (`KIND_*`).
var kind: String = KIND_DEPLOY
## `UI_SITE_PROMPT_*` — the strip's heading.
var title_key: String = ""
## What is being placed or used: `TECH_<ID>_NAME` or `ABILITY_<ID>_NAME`.
var name_key: String = ""
## `(region_index: int) -> String` — "" or a reason code (§5).
var eligible: Callable
## The rule behind `eligible`, where there is one, so that the region panel can
## ask it what the failing key's arguments are. Null for a request whose reason
## is a command's rather than an `Eligibility`'s (the origin).
var rule: Eligibility = null
## `(region_id: String) -> Command`.
var build: Callable
## `() -> void`; the tree modal reopens on its node here.
var on_cancel: Callable = func() -> void: pass


## Where the run starts (m3-screens §7.2), as the same mode a deploy site uses.
## The eligibility is `ChooseOriginCommand`'s own rule, asked through the
## command, so the two can never disagree.
static func for_origin() -> SiteRequest:
	var request: SiteRequest = SiteRequest.new()
	request.kind = KIND_ORIGIN
	request.title_key = KEY_ORIGIN_PROMPT
	request.eligible = func(index: int) -> String:
		if Game.sim == null or index <= 0 or index >= Game.db.regions.size():
			return Command.FAIL_INVALID_REGION
		return Game.sim.can_apply(ChooseOriginCommand.new(Game.db.regions[index].id))
	request.build = func(region_id: String) -> Command:
		return ChooseOriginCommand.new(region_id)
	return request


## The reason a region is not a site, or "" when it is one. A request without an
## `eligible` callable accepts every region, which is what makes a half-built
## request in a test harmless rather than crashing.
func reason_for(region_index: int) -> String:
	if not eligible.is_valid():
		return ""
	return str(eligible.call(region_index))


## The command a region would send, or null when the request cannot build one.
func command_for(region_id: String) -> Command:
	if not build.is_valid():
		return null
	return build.call(region_id) as Command


## Whether the player may back out of this one. The origin is the run's first
## decision and there is nothing behind it (§16.1).
func can_cancel() -> bool:
	return kind != KIND_ORIGIN
