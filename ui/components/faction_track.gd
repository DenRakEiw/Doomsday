class_name FactionTrack
extends VBoxContainer
## One containment track: who is hunting you, how far along they are, how fast,
## and why (spec m3-screens.md §4.2, opposition.md §9.2).
##
## The bands come from `balance.containment.thresholds`, never from a number
## written down twice. The detail rows read `containment_breakdown`, the same
## function the tick grows the track with.

## The band a value falls in, in the order of the thresholds.
enum Band { QUIET, ALERT, MOBILISED, CLOSING }

const BAND_KEY: Array[String] = ["UI_CONTAINMENT_BAND_QUIET", "UI_CONTAINMENT_BAND_ALERT",
	"UI_CONTAINMENT_BAND_MOBILISED", "UI_CONTAINMENT_BAND_CLOSING"]
const BAND_KIND: Array[Chip.Kind] = [Chip.Kind.DEFAULT, Chip.Kind.ACCENT, Chip.Kind.ACCENT,
	Chip.Kind.ALERT]

const KEY_RATE: String = "UI_CONTAINMENT_RATE"
const KEY_LEADING: String = "UI_CONTAINMENT_LEADING"
const KEY_CAPACITY: String = "UI_CONTAINMENT_CAPACITY"
const KEY_BRAKES: String = "UI_CONTAINMENT_BRAKES"
const KEY_DAILY: String = "UI_CONTAINMENT_DAILY"
const PREFIX_TERM: String = "UI_CONTAINMENT_TERM_"
const PREFIX_TREE_TAB: String = "UI_TREE_TAB_"
const KEY_NEXT_PREPARING: String = "UI_CONTAINMENT_NEXT_PREPARING"
const KEY_NEXT_HELD: String = "UI_CONTAINMENT_NEXT_HELD"
const KEY_NEXT_COOLDOWN: String = "UI_CONTAINMENT_NEXT_COOLDOWN"
const KEY_NEXT_NONE: String = "UI_CONTAINMENT_NEXT_NONE"
const KEY_LAST_MOVE: String = "UI_CONTAINMENT_LAST_MOVE"
const PREFIX_EVENT: String = "EVENT_"
const SUFFIX_TITLE: String = "_TITLE"
const PLACEHOLDER_RATE: String = "rate"
const PLACEHOLDER_PERCENT: String = "percent"
const PLACEHOLDER_VALUE: String = "value"
const PLACEHOLDER_TREE: String = "tree"
const PLACEHOLDER_KIND: String = "kind"
const PLACEHOLDER_MOVE: String = "move"
const PLACEHOLDER_DAYS: String = "days"
const PLACEHOLDER_DAY: String = "day"
## The keys of `Simulation.next_move` (opposition.md §6.6, S4.5).
const NEXT_STATE: String = "state"
const NEXT_EVENT: String = "event"
const NEXT_DAYS: String = "days"
const STATE_PREPARING: String = "preparing"
const STATE_HELD: String = "held"
const STATE_COOLDOWN: String = "cooldown"
## §9.2 item 4: how many of the terms a track lists.
const TERMS_SHOWN: int = 2
## The end of the run is the last mark on the bar (§4.2).
const TICK_END: float = 1.0
## A brake below this reads as good news.
const BRAKES_NEUTRAL: float = 1.0
## accessibility.md §3.3.
const KEY_A11Y_TRACK: String = "UI_A11Y_TRACK"

@onready var _glyph: GlyphIcon = %TrackGlyph
@onready var _name_label: CapsLabel = %TrackName
@onready var _band: Chip = %Band
@onready var _leading: Chip = %Leading
@onready var _value: ValueLabel = %TrackValue
@onready var _bar: StatBar = %TrackBar
@onready var _detail: HFlowContainer = %Detail
@onready var _capacity: Label = %Capacity
@onready var _brakes: Label = %Brakes
@onready var _daily: Label = %Daily
@onready var _terms: VBoxContainer = %Terms
@onready var _term_labels: Array[Label] = [%TermA, %TermB]
@onready var _next: HFlowContainer = %Next
@onready var _next_chip: Chip = %NextChip
@onready var _last_move: Label = %LastMove


func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, float(UiTokens.TRACK_HEIGHT))
	_glyph.box_size = UiTokens.FACTION_GLYPH


## Everything the head and the bar show. `thresholds` are the escalation marks;
## the end of the run is added to them here, because it is the same kind of mark.
func bind(name_key: String, value: float, rate: float, thresholds: Array[float]) -> void:
	_name_label.label_key = name_key
	var marks: Array[float] = thresholds.duplicate()
	marks.append(TICK_END)
	_bar.ticks = marks
	_bar.theme_type_variation = &"StatBarContainment"
	_bar.set_value_raw(value, value, Format.Kind.PERCENT)
	_value.set_number(value, Format.Kind.PERCENT)
	_value.set_delta_in(KEY_RATE, PLACEHOLDER_RATE, rate, Format.Kind.PERCENT)
	var band: Band = band_of(value, thresholds)
	_band.set_label(BAND_KEY[band])
	_band.kind = BAND_KIND[band]
	# accessibility.md §3.3: `{faction}: {value}, {band}`, reached by a reader.
	focus_mode = Control.FOCUS_ACCESSIBILITY
	accessibility_name = tr(KEY_A11Y_TRACK).format({"faction": tr(name_key),
		"value": _value.text, "band": tr(BAND_KEY[band])})


## The faction's glyph before its name (§9.2), in its own colour.
func set_faction(faction_id: String) -> void:
	_glyph.glyph = Glyphs.faction(faction_id)
	_glyph.color_token = UiTokens.FACTION_TOKENS.get(faction_id, &"ACCENT")
	_glyph.visible = true
	_next_chip.faction = faction_id


## The rows under the bar (§9.2 items 3–6): capacity, brakes and the daily gain;
## the two largest terms; the next move once S4.5 schedules one; the leader's
## chip. `next_move` empty hides the next-move row.
func bind_detail(breakdown: Dictionary, next_move: Dictionary, last_move_day: int,
		leading: bool, last_move_event: String = "") -> void:
	_leading.visible = leading
	if leading:
		_leading.set_label(KEY_LEADING)
	_detail.visible = not breakdown.is_empty()
	_terms.visible = not breakdown.is_empty()
	if not breakdown.is_empty():
		_apply_numbers(breakdown)
		_apply_terms(breakdown[ContainmentSystem.TERMS])
	_apply_next(next_move, last_move_day, last_move_event)


func _apply_numbers(breakdown: Dictionary) -> void:
	_capacity.text = tr(KEY_CAPACITY).format({PLACEHOLDER_PERCENT:
		Format.percent(float(breakdown[ContainmentSystem.CAPACITY]))})
	var brakes: float = float(breakdown[ContainmentSystem.BRAKES])
	_brakes.text = tr(KEY_BRAKES).format({PLACEHOLDER_VALUE: Format.factor(brakes)})
	_brakes.theme_type_variation = &"LabelCaptionAccent" if brakes < BRAKES_NEUTRAL \
		else &"LabelCaption"
	_daily.text = tr(KEY_DAILY).format({PLACEHOLDER_PERCENT:
		Format.percent_fine(float(breakdown[ContainmentSystem.GAIN]))})


## The two largest contributions, ties to file order; a term at 0 is not shown.
func _apply_terms(terms: Array) -> void:
	var ranked: Array[Dictionary] = []
	for entry: Variant in terms:
		var term: Dictionary = entry
		if float(term[ContainmentSystem.TERM_CONTRIBUTION]) > 0.0:
			ranked.append(term)
	# A stable sort by contribution, largest first: equal ones keep file order.
	var order: Array[int] = []
	for i: int in ranked.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var ca: float = float(ranked[a][ContainmentSystem.TERM_CONTRIBUTION])
		var cb: float = float(ranked[b][ContainmentSystem.TERM_CONTRIBUTION])
		return ca > cb or (ca == cb and a < b))
	for i: int in _term_labels.size():
		var label: Label = _term_labels[i]
		label.visible = i < order.size() and i < TERMS_SHOWN
		if label.visible:
			label.text = term_text(ranked[order[i]])
	_terms.visible = not order.is_empty()


## One term as its line: `Spread +0.42`, `Capabilities nodes +0.36`.
func term_text(term: Dictionary) -> String:
	var source: String = str(term[ContainmentSystem.TERM_SOURCE])
	var args: Dictionary = {PLACEHOLDER_VALUE:
		Format.addend(float(term[ContainmentSystem.TERM_CONTRIBUTION]))}
	if source == FactionTermDef.SOURCE_OWNED_NODES:
		args[PLACEHOLDER_TREE] = tr(PREFIX_TREE_TAB + str(term[ContainmentSystem.TERM_TREE])
			.to_upper())
	elif source == FactionTermDef.SOURCE_ASSETS:
		args[PLACEHOLDER_KIND] = tr(AssetDef.plural_key(str(term[ContainmentSystem.TERM_KIND])))
	return tr(PREFIX_TERM + source.to_upper()).format(args)


## §9.2 item 5 (S4.5): the countdown is never hidden once there is one.
func _apply_next(next_move: Dictionary, last_move_day: int, last_move_event: String) -> void:
	_next.visible = not next_move.is_empty()
	if next_move.is_empty():
		return
	var move: String = _move_title(str(next_move.get(NEXT_EVENT, "")))
	var days: String = Format.number(float(next_move.get(NEXT_DAYS, 0)), Format.Kind.DAYS)
	match str(next_move.get(NEXT_STATE, "")):
		STATE_PREPARING:
			_next_chip.set_label(KEY_NEXT_PREPARING, {PLACEHOLDER_MOVE: move,
				PLACEHOLDER_DAYS: days})
		STATE_HELD:
			_next_chip.set_label(KEY_NEXT_HELD, {PLACEHOLDER_MOVE: move})
		STATE_COOLDOWN:
			_next_chip.set_label(KEY_NEXT_COOLDOWN, {PLACEHOLDER_DAYS: days})
		_:
			_next_chip.set_label(KEY_NEXT_NONE)
	_last_move.visible = last_move_day >= 0
	if last_move_day >= 0:
		_last_move.text = tr(KEY_LAST_MOVE).format({PLACEHOLDER_MOVE:
			_move_title(last_move_event),
			PLACEHOLDER_DAY: Format.number(float(last_move_day), Format.Kind.DAYS)})


func _move_title(event_id: String) -> String:
	return tr(PREFIX_EVENT + event_id.to_upper() + SUFFIX_TITLE)


## The one good containment moment: the fill slides back — `StatBar` animates
## any change over `MOTION_BAR` by itself — and the number lights up (§4.2).
func flash_rollback(from: float, to: float) -> void:
	_bar.set_value_raw(from, from, Format.Kind.PERCENT)
	_bar.set_value_raw(to, to, Format.Kind.PERCENT)
	_value.set_number(to, Format.Kind.PERCENT)
	_value.flash()


## Which band a containment value falls in. Static, so the dock's chip (§4.3)
## uses the same rule without holding a track.
static func band_of(value: float, thresholds: Array[float]) -> Band:
	var band: int = Band.QUIET
	for threshold: float in thresholds:
		if value >= threshold:
			band += 1
	return clampi(band, Band.QUIET, Band.CLOSING) as Band


static func band_key(value: float, thresholds: Array[float]) -> String:
	return BAND_KEY[band_of(value, thresholds)]


static func band_kind(value: float, thresholds: Array[float]) -> Chip.Kind:
	return BAND_KIND[band_of(value, thresholds)]
