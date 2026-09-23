class_name TickerItem
extends RefCounted
## One line waiting in the ticker (spec ticker.md §4.1).
##
## A key and raw arguments, never finished text: the strip renders an item when
## it draws it, so a language change re-renders what is already on screen
## instead of starting the run over.

var key: String = ""
## Ids, floats and ints as `core/` produced them — `HeadlineText` converts.
var args: Dictionary = {}


static func make(key: String, args: Dictionary = {}) -> TickerItem:
	var item: TickerItem = TickerItem.new()
	item.key = key
	item.args = args
	return item


func render() -> String:
	return HeadlineText.render(key, args)
