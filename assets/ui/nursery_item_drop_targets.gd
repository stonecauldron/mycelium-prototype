class_name NurseryItemDropTargets
extends RefCounted

## Native GUI hit-testing includes the carried icon, but still chooses one target.
const GROUP := &"nursery_item_drop_targets"
const _ITEM_TYPES := ["fertilizer", "mutation", "shop_fertilizer", "shop_mutation"]


static func contains(target: Control, canvas_position: Vector2) -> bool:
	if not target.is_visible_in_tree() or target.is_queued_for_deletion():
		return false
	var viewport := target.get_viewport()
	var bounds: Rect2 = target.drag_target_canvas_rect()
	if not viewport.gui_is_dragging():
		return bounds.has_point(canvas_position)
	var data: Variant = viewport.gui_get_drag_data()
	if not data is Dictionary or str(data.get("type", "")) not in _ITEM_TYPES:
		return bounds.has_point(canvas_position)
	var preview := NurseryItemDragPreview.current(viewport)
	if preview == null:
		return bounds.has_point(canvas_position)
	var item_bounds := preview.item_canvas_rect()
	if not item_bounds.has_area():
		return bounds.has_point(canvas_position)
	return _target_at(viewport, canvas_position, item_bounds) == target


static func _target_at(viewport: Viewport, pointer: Vector2, item_bounds: Rect2) -> Control:
	var best: Control = null
	var best_overlap := 0.0
	var best_distance := INF
	for node in viewport.get_tree().get_nodes_in_group(GROUP):
		var candidate := node as Control
		if (
			candidate == null or candidate.get_viewport() != viewport
			or not candidate.is_visible_in_tree() or candidate.is_queued_for_deletion()
		):
			continue
		var bounds: Rect2 = candidate.drag_target_canvas_rect()
		if bounds.has_point(pointer):
			return candidate
		var overlap := bounds.intersection(item_bounds).get_area()
		if overlap <= 0.0:
			continue
		var distance := bounds.get_center().distance_squared_to(pointer)
		if overlap > best_overlap or (is_equal_approx(overlap, best_overlap) and distance < best_distance):
			best = candidate
			best_overlap = overlap
			best_distance = distance
	return best
