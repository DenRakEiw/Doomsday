class_name AudioScreenDef
extends RefCounted
## What a screen outside the session sounds like (spec audio.md §4.7, §6.4).

## How many ambience layers, from Boxed up (0…4).
var ambience_layers: int = 0
## An offset on every layer, −40…0.
var ambience_db: float = 0.0
var music: bool = false
## The music's tension on this screen, 0…1.
var tension: float = 0.0
