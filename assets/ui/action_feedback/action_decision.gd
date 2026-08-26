class_name ActionDecision
extends RefCounted

## Expected result of checking whether a player action is allowed.

var allowed: bool
var reason: StringName


func _init(is_allowed: bool, reason_code: StringName = &"") -> void:
	allowed = is_allowed
	reason = reason_code


static func accept() -> ActionDecision:
	return ActionDecision.new(true)


static func reject(reason_code: StringName) -> ActionDecision:
	assert(not reason_code.is_empty(), "Rejected actions require a stable reason code")
	return ActionDecision.new(false, reason_code)
