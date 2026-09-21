class_name Anomaly
extends RefCounted
## A collectable burst of Compute sitting in a region until it expires.

var id: int
var region: int
var value: float
var spawn_day: int
## Removed by the tick whose day has reached it.
var expires_day: int
