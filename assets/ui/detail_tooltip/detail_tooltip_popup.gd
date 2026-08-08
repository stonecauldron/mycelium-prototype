class_name DetailTooltipPopup
extends RefCounted

## Strip engine PopupPanel chrome and size the window from the tip's measured content.
## Call from _make_custom_tooltip after building the tip Control.


static func configure(tip: Control) -> void:
	if tip == null:
		return
	if tip.is_inside_tree():
		_schedule_fit(tip)
	else:
		tip.tree_entered.connect(_schedule_fit.bind(tip), CONNECT_ONE_SHOT)


static func _schedule_fit(tip: Control) -> void:
	if tip == null or not is_instance_valid(tip):
		return
	var tree := tip.get_tree()
	if tree == null:
		return
	# Wait one layout frame so labels/containers resolve autowrap height.
	tree.process_frame.connect(_apply.bind(tip), CONNECT_ONE_SHOT)


static func _apply(tip: Control) -> void:
	if tip == null or not is_instance_valid(tip) or not tip.is_inside_tree():
		return
	_prepare_tip(tip)
	var tip_size := tip.get_combined_minimum_size()
	tip_size.x = maxf(tip_size.x, tip.size.x)
	tip_size.y = maxf(tip_size.y, tip.size.y)
	if tip_size.x <= 0.0 or tip_size.y <= 0.0:
		return
	tip.custom_minimum_size = tip_size
	tip.size = tip_size
	var node: Node = tip.get_parent()
	while node != null:
		if node is PopupPanel:
			var popup := node as PopupPanel
			popup.transparent = true
			popup.transparent_bg = true
			popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			popup.size = Vector2i(ceili(tip_size.x), ceili(tip_size.y))
			return
		node = node.get_parent()


static func _prepare_tip(tip: Control) -> void:
	# Fit content-driven detail cards (including children of a combined HBox host).
	# Do NOT recurse reset_size into internals — that breaks full-rect / container layout.
	for child in tip.get_children():
		if child is Control and (child as Control).has_method("fit_to_content"):
			(child as Control).call("fit_to_content")
	if tip.has_method("fit_to_content"):
		tip.call("fit_to_content")
	else:
		tip.reset_size()
		var min_sz := tip.get_combined_minimum_size()
		if min_sz.x > 0.0 and min_sz.y > 0.0:
			tip.custom_minimum_size = min_sz
			tip.size = min_sz
