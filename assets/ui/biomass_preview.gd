class_name BiomassPreview
extends RefCounted

const _DELTA_META := &"biomass_preview_delta"
const _CONTEXT_META := &"biomass_preview_context"


## The callback reads the action's current signed change, or null if inapplicable.
## A null result also blocks a containing action (for example an Offer lock).
static func bind(control: Control, delta: Callable, context: String = "") -> void:
	control.set_meta(_DELTA_META, delta)
	control.set_meta(_CONTEXT_META, context)


static func for_hovered(control: Control) -> Dictionary:
	var node: Node = control
	while is_instance_valid(node):
		if node is Control and (not node.is_visible_in_tree() or node.is_queued_for_deletion()):
			return {}
		if node.has_meta(_DELTA_META):
			var callback: Callable = node.get_meta(_DELTA_META)
			if not callback.is_valid():
				return {}
			var delta: Variant = callback.call()
			if delta == null:
				return {}
			return {"delta": int(delta), "context": str(node.get_meta(_CONTEXT_META, ""))}
		node = node.get_parent()
	return {}
