class_name DetailCardFit
extends RefCounted

## Shared content-fit for detail tip cards: CardPanel is the size-driving container
## (top-left, not full-rect stretch). Root Control matches the panel's measured size.


static func apply(root: Control, card_panel: PanelContainer, width: float) -> void:
	if root == null or card_panel == null or width <= 0.0:
		return
	root.clip_contents = false
	card_panel.clip_contents = false

	card_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	card_panel.anchor_right = card_panel.anchor_left
	card_panel.anchor_bottom = card_panel.anchor_top
	card_panel.offset_left = 0.0
	card_panel.offset_top = 0.0
	card_panel.custom_minimum_size = Vector2(width, 0.0)
	card_panel.offset_right = width
	card_panel.offset_bottom = 0.0
	card_panel.reset_size()
	var fitted := card_panel.get_combined_minimum_size()
	fitted.x = width
	fitted.y = maxf(fitted.y, 1.0)
	card_panel.custom_minimum_size = fitted
	card_panel.offset_right = fitted.x
	card_panel.offset_bottom = fitted.y
	card_panel.size = fitted

	root.custom_minimum_size = fitted
	root.size = fitted
	root.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# HBox/VBox dual tips own the root rect. Pinning top-left anchors here
	# takes the card out of container flow and stacks both cards at (0, 0).
	if root.get_parent() is Container:
		return
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	root.anchor_right = root.anchor_left
	root.anchor_bottom = root.anchor_top
	root.offset_left = 0.0
	root.offset_top = 0.0
	root.offset_right = fitted.x
	root.offset_bottom = fitted.y
