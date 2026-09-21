class_name ValidationError
extends RefCounted
## One problem found in a content file.
##
## Errors are collected, never thrown: `SchemaValidator` reports everything it
## finds in one pass so that the first mistake in a file does not hide the rest.

## Path of the file as it was given to the loader.
var file: String
## Position inside the file, `"regions[2].attributes.compute"` or `"line 14"`.
## Empty for a problem with the file as a whole.
var path: String
## English, for developers. Never shown to a player.
var message: String


func _init(p_file: String = "", p_path: String = "", p_message: String = "") -> void:
	file = p_file
	path = p_path
	message = p_message


func _to_string() -> String:
	return "%s: %s: %s" % [file, path, message]
