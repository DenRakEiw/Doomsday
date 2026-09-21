class_name ContentLoadResult
extends RefCounted
## What `ContentLoader` returns: either a database or every reason there is none.

## Null unless `errors` is empty — definitions are built from validated data only.
var db: ContentDB = null
var errors: Array[ValidationError] = []


func ok() -> bool:
	return errors.is_empty()


## Every error on its own line, for a test failure message or a tool's output.
func error_text() -> String:
	var lines: PackedStringArray = []
	for error: ValidationError in errors:
		lines.append(str(error))
	return "\n".join(lines)
