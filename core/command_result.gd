class_name CommandResult
extends RefCounted
## What `Simulation.apply` gives back.
##
## The events a command caused travel here and are **not** put in the outbox:
## the outbox is the tick's. The `Game` autoload (S2.1) re-emits both, so
## nothing is reported twice and nothing piles up when nobody is listening.

var ok: bool = false
## A failure reason from `Command`; empty when `ok`.
var reason: String = ""
var events: Array[SimEvent] = []


static func rejected(reason: String) -> CommandResult:
	var result: CommandResult = CommandResult.new()
	result.reason = reason
	return result


static func accepted() -> CommandResult:
	var result: CommandResult = CommandResult.new()
	result.ok = true
	return result
