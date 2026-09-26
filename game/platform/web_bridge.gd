class_name WebBridge
extends Node
## web.md §6.3, §7.3, §7.4: every `JavaScriptBridge` call of the game.
##
## `PlatformService` adds one on the web and nowhere else. Every JavaScript
## callback is kept in a member: the bridge frees a callback whose last
## reference is gone, and the browser would then call into nothing.

## The page went to the background (another tab, minimised).
signal page_hidden
## The page is visible again.
signal page_shown
## `pick_text_file` has an answer: the text, or a reason ("" on success).
signal file_picked(text: String, reason: String)

const REASON_CANCELLED: String = "cancelled"
const REASON_TOO_LARGE: String = "too_large"
## 1 MiB; a profile is a few KB.
const MAX_IMPORT_BYTES: int = 1048576
const FEATURE_WEB: String = "web"
## web.md §5.1: what the shell reads before the engine runs.
const LOCALE_KEY: String = "doomsday_locale"
const JSON_MIME: String = "application/json"
## The globals the snippets below call back through.
const GLOBAL_VISIBILITY: String = "__doomsdayVisibility"
const GLOBAL_PICKED: String = "__doomsdayPicked"
## web.md §17.2 items 8 and 12: what a debug web export lets the browser check
## drive — never a release build.
const GLOBAL_DEBUG_CRASH: String = "doomsdayDebugCrash"
const GLOBAL_DEBUG_AUDIO: String = "doomsdayDebugAudioUnlocked"

const JS_LISTEN: String = """
document.addEventListener('visibilitychange', function () {
	window.__doomsdayVisibility(document.visibilityState === 'hidden');
});
"""
const JS_PERSIST: String = """
try {
	if (navigator.storage && navigator.storage.persist) {
		navigator.storage.persist().catch(function () {});
	}
} catch (e) {}
"""
const JS_REMEMBER_LOCALE: String = """
try { window.localStorage.setItem('%s', '%s'); } catch (e) {}
"""
## The chooser: a hidden input clicked in the frame of the button press (the
## browser allows a file dialog for a few seconds after a gesture).
const JS_PICK: String = """
(function () {
	var input = document.createElement('input');
	input.type = 'file';
	input.accept = '.json,application/json';
	input.style.display = 'none';
	document.body.appendChild(input);
	var answered = false;
	function answer(text, reason) {
		if (answered) { return; }
		answered = true;
		input.remove();
		window.__doomsdayPicked(text, reason);
	}
	input.addEventListener('cancel', function () { answer('', '%s'); });
	input.addEventListener('change', function () {
		var file = input.files && input.files[0];
		if (!file) { answer('', '%s'); return; }
		if (file.size > %d) { answer('', '%s'); return; }
		var reader = new FileReader();
		reader.onload = function () { answer(String(reader.result), ''); };
		reader.onerror = function () { answer('', '%s'); };
		reader.readAsText(file);
	});
	input.click();
}());
"""

var _visibility_callback: JavaScriptObject = null
var _picked_callback: JavaScriptObject = null
var _debug_crash_callback: JavaScriptObject = null
var _debug_audio_callback: JavaScriptObject = null
var _persist_requested: bool = false
var _is_web: bool = false


func _ready() -> void:
	_is_web = OS.has_feature(FEATURE_WEB)
	if not _is_web:
		return
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	_visibility_callback = JavaScriptBridge.create_callback(_on_visibility_changed)
	_picked_callback = JavaScriptBridge.create_callback(_on_file_picked)
	window.set(GLOBAL_VISIBILITY, _visibility_callback)
	window.set(GLOBAL_PICKED, _picked_callback)
	JavaScriptBridge.eval(JS_LISTEN)
	if OS.is_debug_build():
		_debug_crash_callback = JavaScriptBridge.create_callback(_on_debug_crash)
		_debug_audio_callback = JavaScriptBridge.create_callback(_on_debug_audio)
		window.set(GLOBAL_DEBUG_CRASH, _debug_crash_callback)
		window.set(GLOBAL_DEBUG_AUDIO, _debug_audio_callback)


## Asks the browser to keep the game's storage under pressure. Once per launch;
## the answer is ignored — it only lowers the chance of eviction.
func request_persistent_storage() -> void:
	if not _is_web or _persist_requested:
		return
	_persist_requested = true
	JavaScriptBridge.eval(JS_PERSIST)


## §5.1: the shell's language on the next load.
func remember_locale(locale: String) -> void:
	if not _is_web or not locale.is_valid_identifier():
		return
	JavaScriptBridge.eval(JS_REMEMBER_LOCALE % [LOCALE_KEY, locale])


## §7.4: offers `text` as a download named `file_name`. False where there is no
## browser to download through.
func download_text(file_name: String, text: String) -> bool:
	if not _is_web:
		return false
	JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file_name, JSON_MIME)
	return true


## §7.3: the browser's file dialog; `file_picked` answers later.
func pick_text_file() -> void:
	if not _is_web:
		file_picked.emit("", REASON_CANCELLED)
		return
	JavaScriptBridge.eval(JS_PICK % [REASON_CANCELLED, REASON_CANCELLED, MAX_IMPORT_BYTES,
		REASON_TOO_LARGE, REASON_CANCELLED])


## The browser's answer, emitted at once: a hidden tab gets no more frames, so a
## deferred call would run only when the player is back.
func _on_visibility_changed(args: Array) -> void:
	var hidden: bool = not args.is_empty() and bool(args[0])
	if hidden:
		page_hidden.emit()
	else:
		page_shown.emit()


func _on_file_picked(args: Array) -> void:
	var text: String = str(args[0]) if args.size() > 0 else ""
	var reason: String = str(args[1]) if args.size() > 1 else REASON_CANCELLED
	file_picked.emit(text, reason)


func _on_debug_crash(_args: Array) -> void:
	Game.debug_crash()


## Answers through the console, which the browser check reads.
func _on_debug_audio(_args: Array) -> void:
	print("audio unlocked: %s" % Audio.is_unlocked())
