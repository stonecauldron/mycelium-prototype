extends Node2D

## Control bounds include font/icon padding; tuck that padding into the cap edge.
const HEAD_GAP := -16.0


## Fit the visible content above its spawn anchor, including the initial scale and tilt.
func _layout_content(content: Control, above_anchor: bool = true) -> void:
	content.size = content.get_combined_minimum_size()
	content.position = -content.size * 0.5
	if not above_anchor:
		return
	var anchor_y := global_position.y
	var bounds := content.get_global_transform() * Rect2(Vector2.ZERO, content.size)
	global_position.y += anchor_y - HEAD_GAP - bounds.end.y
