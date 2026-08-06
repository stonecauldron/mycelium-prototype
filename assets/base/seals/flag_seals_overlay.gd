class_name FlagSealsOverlay
extends Node2D

## War Chamber only: seal icons on the flag cloth + manual HUD tooltip on hover.
## Built-in Control tooltips fail here (world Control under Camera2D + moving hit targets).

const MAX_DISPLAY := 3
const ICON_SIZE := 52.0
const ICON_GAP := 10.0
## Local offset on Flag sprite — upper cloth face (Flag space, before War Chamber mirror).
const CLOTH_ORIGIN := Vector2(55.0, -310.0)
const TOOLTIP_WIDTH := 280.0
const PANEL_BG := Color(0.92156863, 0.9098039, 0.87058824, 1)
const INK := Color(0.03137255, 0.03529412, 0.02745098, 1)
const DESC := Color(0.2, 0.22, 0.18, 1)
const _HOVER_PAD := 12.0

var _icons: Array[Sprite2D] = []
var _tooltip: Control
var _hovering: bool = false
var _flag_bearer: Node2D


func _ready() -> void:
	z_index = 20
	position = CLOTH_ORIGIN
	_flag_bearer = _find_flag_bearer()
	_build_icons()
	call_deferred("refresh")


func _find_flag_bearer() -> Node2D:
	# Overlay lives at FlagBearer/Shroom/Flag/<this>.
	var flag := get_parent() as Node2D
	if flag == null:
		return null
	var shroom := flag.get_parent() as Node2D
	if shroom == null:
		return null
	return shroom.get_parent() as Node2D


func _build_icons() -> void:
	for child in get_children():
		if child is Sprite2D:
			child.queue_free()
	_icons.clear()
	for i in MAX_DISPLAY:
		var icon := Sprite2D.new()
		icon.centered = true
		icon.visible = false
		icon.position = Vector2(float(i) * (ICON_SIZE + ICON_GAP), 0.0)
		add_child(icon)
		_icons.append(icon)


func _process(_delta: float) -> void:
	if not visible or GameState.seals.all_owned().is_empty():
		_set_hovering(false)
		return
	var mouse := get_viewport().get_mouse_position()
	_set_hovering(_mouse_over_flag_bearer(mouse))
	if _hovering:
		_position_tooltip(mouse)


func _mouse_over_flag_bearer(canvas_mouse: Vector2) -> bool:
	var rect := _flag_bearer_canvas_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	return rect.grow(_HOVER_PAD).has_point(canvas_mouse)


## Union of shroom + flag sprite bounds (whole War Chamber flag bearer).
func _flag_bearer_canvas_rect() -> Rect2:
	if _flag_bearer == null or not is_instance_valid(_flag_bearer):
		_flag_bearer = _find_flag_bearer()
	if _flag_bearer == null:
		return Rect2()
	var shroom := _flag_bearer.get_node_or_null("Shroom") as Sprite2D
	var flag := _flag_bearer.get_node_or_null("Shroom/Flag") as Sprite2D
	var rect := Rect2()
	var has_rect := false
	for sprite in [shroom, flag]:
		if sprite == null:
			continue
		var sprite_rect := _sprite_canvas_rect(sprite)
		if sprite_rect.size.x <= 0.0 or sprite_rect.size.y <= 0.0:
			continue
		if not has_rect:
			rect = sprite_rect
			has_rect = true
		else:
			rect = rect.merge(sprite_rect)
	return rect


func _sprite_canvas_rect(sprite: Sprite2D) -> Rect2:
	var tex_size := sprite.get_rect().size
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Rect2()
	var xf := sprite.get_global_transform_with_canvas()
	var local_rect := sprite.get_rect()
	var corners: Array[Vector2] = [
		xf * local_rect.position,
		xf * Vector2(local_rect.end.x, local_rect.position.y),
		xf * local_rect.end,
		xf * Vector2(local_rect.position.x, local_rect.end.y),
	]
	var min_p := corners[0]
	var max_p := corners[0]
	for i in range(1, corners.size()):
		min_p = min_p.min(corners[i])
		max_p = max_p.max(corners[i])
	return Rect2(min_p, max_p - min_p)


func _set_hovering(active: bool) -> void:
	if active == _hovering:
		return
	_hovering = active
	if _hovering:
		_ensure_tooltip()
		_rebuild_tooltip_content()
		if _tooltip != null:
			_tooltip.visible = true
	elif _tooltip != null:
		_tooltip.visible = false


func _ensure_tooltip() -> void:
	if _tooltip != null and is_instance_valid(_tooltip):
		return
	var hud := _hud_root()
	if hud == null:
		return
	_tooltip = _make_tooltip_panel()
	_tooltip.name = "FlagSealsTooltip"
	_tooltip.z_index = 120
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	hud.add_child(_tooltip)


func _hud_root() -> Control:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("HudLayer/HudRoot") as Control


func _position_tooltip(canvas_mouse: Vector2) -> void:
	if _tooltip == null or not is_instance_valid(_tooltip):
		return
	var hud := _tooltip.get_parent() as Control
	if hud == null:
		return
	_tooltip.reset_size()
	var tip_size := _tooltip.get_combined_minimum_size()
	var local_mouse := hud.get_global_transform_with_canvas().affine_inverse() * canvas_mouse
	var pos := local_mouse + Vector2(18.0, 18.0)
	var hud_size := hud.size
	if pos.x + tip_size.x > hud_size.x:
		pos.x = local_mouse.x - tip_size.x - 12.0
	if pos.y + tip_size.y > hud_size.y:
		pos.y = local_mouse.y - tip_size.y - 12.0
	_tooltip.position = pos
	_tooltip.size = tip_size


func _rebuild_tooltip_content() -> void:
	if _tooltip == null or not is_instance_valid(_tooltip):
		return
	for child in _tooltip.get_children():
		child.queue_free()
	_tooltip.add_child(_build_tooltip_body())


func _make_tooltip_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = Color(0, 0, 0, 1)
	style.set_border_width_all(5)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14.0
	style.content_margin_top = 12.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(_build_tooltip_body())
	return panel


func _build_tooltip_body() -> Control:
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)

	var header := Label.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.text = "Seals"
	header.add_theme_color_override("font_color", INK)
	header.add_theme_font_size_override("font_size", 28)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	vbox.add_child(header)

	var owned := GameState.seals.all_owned()
	if owned.is_empty():
		var empty := Label.new()
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.text = "None yet"
		empty.add_theme_color_override("font_color", DESC)
		empty.add_theme_font_size_override("font_size", 20)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty)
	else:
		for seal in owned:
			vbox.add_child(_make_seal_block(seal))
	return vbox


func _make_seal_block(seal: SealData) -> Control:
	var block := VBoxContainer.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_theme_constant_override("separation", 2)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = seal.display_name if seal != null else "?"
	name_label.add_theme_color_override("font_color", INK)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	block.add_child(name_label)

	var desc := Label.new()
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.text = seal.description if seal != null else ""
	desc.add_theme_color_override("font_color", DESC)
	desc.add_theme_font_size_override("font_size", 18)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	block.add_child(desc)
	return block


func refresh() -> void:
	var owned := GameState.seals.all_owned()
	visible = not owned.is_empty()
	for i in _icons.size():
		var icon := _icons[i]
		if i < owned.size() and i < MAX_DISPLAY:
			icon.texture = owned[i].icon
			icon.visible = true
			_fit_sprite(icon)
		else:
			icon.texture = null
			icon.visible = false
	if _tooltip != null and is_instance_valid(_tooltip):
		_rebuild_tooltip_content()
	if owned.is_empty():
		_set_hovering(false)


func _fit_sprite(icon: Sprite2D) -> void:
	if icon.texture == null:
		return
	var tex_size := icon.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	# Counter parent Flag/Shroom scale so on-screen size stays ~ICON_SIZE.
	var parent_scale := global_scale
	var target := ICON_SIZE / maxf(absf(parent_scale.x), 0.001)
	var scale_factor := target / maxf(tex_size.x, tex_size.y)
	icon.scale = Vector2(scale_factor, scale_factor)


func _exit_tree() -> void:
	_set_hovering(false)
	if _tooltip != null and is_instance_valid(_tooltip):
		_tooltip.queue_free()
	_tooltip = null
