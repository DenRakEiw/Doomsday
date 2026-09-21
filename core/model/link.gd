class_name Link
extends RefCounted
## The mutable state of one connection. Nothing in M1 closes a link; tests and
## the counter-actions of M4 do.

var def: LinkDef
var open: bool = true


static func create(definition: LinkDef) -> Link:
	var link: Link = Link.new()
	link.def = definition
	return link
