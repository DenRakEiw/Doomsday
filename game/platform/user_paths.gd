class_name UserPaths
extends RefCounted
## release.md §5 and web.md §7.1: where the game's files live.
##
## A desktop build has a user folder of its own (`custom_user_dir_name`), so its
## files sit at the root of `user://`. In a browser `user://` is `/userfs`, one
## IndexedDB store per origin — and itch.io serves every HTML game from one
## origin, so every Godot game there shares it. On the web every file the game
## writes therefore lives under a folder of its own.
##
## Never instantiated; a namespace of static functions.

const WEB_ROOT: String = "user://doomsday/"
const DESKTOP_ROOT: String = "user://"
const FEATURE_WEB: String = "web"


## The root for this build.
static func root() -> String:
	return root_for(OS.has_feature(FEATURE_WEB))


## The root for a build that is, or is not, running in a browser — the seam a
## desktop test checks the web's answer through.
static func root_for(is_web: bool) -> String:
	return WEB_ROOT if is_web else DESKTOP_ROOT


## `relative` under this build's root (`at("saves/")` → `user://saves/` on a
## desktop, `user://doomsday/saves/` in a browser).
static func at(relative: String) -> String:
	return at_root(root(), relative)


## `relative` under `base`; a trailing slash of `relative` is kept, so a folder
## stays recognisable as one.
static func at_root(base: String, relative: String) -> String:
	var joined: String = base.path_join(relative)
	if relative.ends_with("/") and not joined.ends_with("/"):
		joined += "/"
	return joined
