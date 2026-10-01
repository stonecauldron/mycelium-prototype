class_name NurseryItemDragPreview
extends Control

const _CURRENT_META := &"nursery_item_drag_preview"
const _SMOKE_SCENE := preload("res://assets/vfx/spore_cloud/spore_cloud.tscn")
const _CURSOR_OFFSET := Vector2(0.0, 28.0)

var _inventory_form: Control
var _shop_form: Control
var _shop_area: Control
var _inventory_icon: TextureRect
var _showing_shop := false
var _viewport: Viewport


static func create(
	inventory_form: Control, shop_form: Control = null, shop_area: Control = null
) -> NurseryItemDragPreview:
	var preview := NurseryItemDragPreview.new()
	preview._inventory_form = inventory_form
	preview._shop_form = shop_form
	preview._shop_area = shop_area
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(inventory_form)
	if shop_form != null:
		preview.add_child(shop_form)
	return preview


static func current(viewport: Viewport) -> NurseryItemDragPreview:
	if not viewport.has_meta(_CURRENT_META):
		return null
	var preview := viewport.get_meta(_CURRENT_META) as NurseryItemDragPreview
	if not is_instance_valid(preview) or preview.is_queued_for_deletion():
		return null
	preview.refresh_form()
	return preview


func _ready() -> void:
	_viewport = get_viewport()
	_viewport.set_meta(_CURRENT_META, self)
	_inventory_icon = _inventory_form.get_node_or_null("%Icon") as TextureRect
	_prepare_form(_inventory_form)
	if _shop_form != null:
		_prepare_form(_shop_form)
	_showing_shop = _pointer_inside_shop()
	_apply_form()


func _prepare_form(form: Control) -> void:
	_ignore_mouse(form)
	form.resized.connect(_center_form.bind(form))
	_center_form(form)


func _center_form(form: Control) -> void:
	form.position = -form.size * 0.5 + _CURSOR_OFFSET


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _process(_delta: float) -> void:
	refresh_form()


## Also called by drop routing, so a boundary crossed on release is current.
func refresh_form() -> void:
	if not is_node_ready():
		return
	var showing_shop := _pointer_inside_shop()
	if showing_shop == _showing_shop:
		return
	_showing_shop = showing_shop
	_apply_form()
	_spawn_smoke()


func _pointer_inside_shop() -> bool:
	if not is_instance_valid(_shop_form) or not is_instance_valid(_shop_area):
		return false
	if not _shop_area.is_visible_in_tree():
		return false
	var point := _shop_area.get_global_transform_with_canvas().affine_inverse() * _viewport.get_mouse_position()
	return Rect2(Vector2.ZERO, _shop_area.size).has_point(point)


func _apply_form() -> void:
	# Keep both forms laid out so a fast boundary-crossing drop has its icon bounds.
	_inventory_form.modulate.a = 0.0 if _showing_shop else 1.0
	if _shop_form != null:
		_shop_form.modulate.a = 1.0 if _showing_shop else 0.0


## Painted inventory icon bounds, excluding the name and compact-card whitespace.
func item_canvas_rect() -> Rect2:
	refresh_form()
	if _showing_shop or not is_instance_valid(_inventory_icon) or _inventory_icon.texture == null:
		return Rect2()
	var texture_size := _inventory_icon.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2()
	var icon_size := _inventory_icon.size
	var ratio := minf(icon_size.x / texture_size.x, icon_size.y / texture_size.y)
	var painted_size := texture_size * ratio
	var painted_rect := Rect2((icon_size - painted_size) * 0.5, painted_size)
	var transform := _inventory_icon.get_global_transform_with_canvas()
	# Native preview positioning may follow hit testing in the same input event.
	transform.origin += _viewport.get_mouse_position() - get_global_transform_with_canvas().origin
	return transform * painted_rect


func _spawn_smoke() -> void:
	Audio.play_ui_cue(Sfx.Cue.ITEM_TRANSFORM)
	var cloud: SporeCloud = _SMOKE_SCENE.instantiate()
	add_child(cloud)
	cloud.top_level = true
	cloud.position = cloud.get_canvas_transform().affine_inverse() * (_viewport.get_mouse_position() + _CURSOR_OFFSET)
	var particles := cloud.get_node("Particles") as CPUParticles2D
	# Smoke uses alpha blending; the shared combat cloud is otherwise additive light.
	particles.material = null
	particles.lifetime = 0.55
	particles.explosiveness = 1.0
	var expansion := Curve.new()
	expansion.add_point(Vector2(0.0, 0.65))
	expansion.add_point(Vector2(1.0, 1.3))
	particles.scale_amount_curve = expansion
	cloud.burst(Color("d5d3bb"), 1.7)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and is_instance_valid(_viewport):
		if _viewport.has_meta(_CURRENT_META) and _viewport.get_meta(_CURRENT_META) == self:
			hide()
			_clear_current()
			_viewport.gui_cancel_drag()


func _exit_tree() -> void:
	_clear_current()


func _clear_current() -> void:
	if is_instance_valid(_viewport) and _viewport.has_meta(_CURRENT_META) and _viewport.get_meta(_CURRENT_META) == self:
		_viewport.remove_meta(_CURRENT_META)
