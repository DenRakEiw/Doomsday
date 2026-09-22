class_name FactionTrack
extends VBoxContainer
## One containment track: who is hunting you, how far along they are, and how
## fast (spec m3-screens.md §4.2).
##
## M3 has one of these; S4.1 has four and changes nothing here. The bands come
## from `balance.containment.thresholds`, never from a number written down twice.

## The band a value falls in, in the order of the thresholds.
enum Band { QUIET, ALERT, MOBILISED, CLOSING }

const BAND_KEY: Array[String] = ["UI_CONTAINMENT_BAND_QUIET", "UI_CONTAINMENT_BAND_ALERT",
	"UI_CONTAINMENT_BAND_MOBILISED", "UI_CONTAINMENT_BAND_CLOSING"]
const BAND_KIND: Array[Chip.Kind] = [Chip.Kind.DEFAULT, Chip.Kind.ACCENT, Chip.Kind.ACCENT,
	Chip.Kind.ALERT]

const KEY_RATE: String = "UI_CONTAINMENT_RATE"
const PLACEHOLDER_RATE: String = "rate"
## The end of the run is the last mark on the bar (§4.2).
const TICK_END: float = 1.0

@onready var _name_label: CapsLabel = %TrackName
@onready var _band: Chip = %Band
@onready var _value: ValueLabel = %TrackValue
@onready var _bar: StatBar = %TrackBar


func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, float(UiTokens.TRACK_HEIGHT))


## Everything the track shows. `thresholds` are the escalation marks; the end of
## the run is added to them here, because it is the same kind of mark.
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
