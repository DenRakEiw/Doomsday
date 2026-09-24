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
# The words for a closed region, shared by the region panel and the prompt strip
# (first-run.md §2), so the two can never say different things.
const KEY_ORIGIN_AIRGAP: String = "UI_ORIGIN_INELIGIBLE_AIRGAP"
const KEY_ORIGIN_COMPUTE: String = "UI_ORIGIN_INELIGIBLE_COMPUTE"
## scenarios.md §2: open in general, closed by the run's scenario.
const KEY_ORIGIN_SCENARIO: String = "UI_ORIGIN_INELIGIBLE_SCENARIO"
const PREFIX_FAIL: String = "CMD_FAIL_"
const PREFIX_ELIGIBLE: String = "UI_ELIGIBLE_"
const PREFIX_ATTR: String = "UI_ATTR_"
const PREFIX_STATUS: String = "STATUS_"
const SUFFIX_NAME: String = "_NAME"
const KEY_CONTINENT: String = "CONTINENT_"

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


## Why a region is not a site, in words — or "" when it is one. The origin's rule
## is a command's, so it has command reasons; every other request answers with an
## `Eligibility` code and its arguments (§17.2).
func reason_text(region_index: int) -> String:
	var reason: String = reason_for(region_index)
	if reason.is_empty():
		return ""
	if kind == KIND_ORIGIN:
		if reason == Command.FAIL_ORIGIN_SCENARIO:
			return TranslationServer.translate(KEY_ORIGIN_SCENARIO)
		var region: Region = Game.sim.world.regions[region_index]
		return TranslationServer.translate(KEY_ORIGIN_AIRGAP if region.air_gapped
			else KEY_ORIGIN_COMPUTE)
	if not Eligibility.REASONS.has(reason):
		return TranslationServer.translate(PREFIX_FAIL + reason.to_upper())
	return String(TranslationServer.translate(PREFIX_ELIGIBLE + reason.to_upper())).format(
		_reason_args(region_index))


## The failing key's own arguments, with every id turned into a name.
func _reason_args(region_index: int) -> Dictionary:
	if rule == null:
		return {}
	var raw: Dictionary = rule.detail(Game.sim.world, region_index)
	var args: Dictionary = raw.duplicate()
	if raw.has("attr"):
		args["attr"] = TranslationServer.translate(PREFIX_ATTR + str(raw["attr"]).to_upper())
	if raw.has("kind"):
		args["kind"] = TechText.asset_name(str(raw["kind"]), int(raw.get("count", 1)))
	if raw.has("status"):
		args["status"] = TranslationServer.translate(PREFIX_STATUS + str(raw["status"]).to_upper()
			+ SUFFIX_NAME)
	if raw.has("value"):
		args["value"] = Format.percent(float(raw["value"]))
	if raw.has("continent"):
		args["continent"] = TranslationServer.translate(KEY_CONTINENT
			+ str(raw["continent"]).to_upper())
	return args


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
