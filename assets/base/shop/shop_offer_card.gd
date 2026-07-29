class_name ShopOfferCard
extends Control

signal offer_clicked(card: ShopOfferCard)
signal lock_toggled(card: ShopOfferCard)

const CARD_SIZE := Vector2(192, 280)
const REROLL_PREVIEW_SCALE := 1.06
const REROLL_PREVIEW_IN_SEC := 0.14
const REROLL_PREVIEW_OUT_SEC := 0.1
const REROLL_SHAKE_DEG := 5.0
const REROLL_SHAKE_STEP_SEC := 0.045
const _SHOP_OFFER_CARD_SCENE := preload("res://assets/base/shop/shop_offer_card.tscn")
const _WEAPON_DETAIL_CARD_SCENE := preload("res://assets/base/weapon_detail_card/weapon_detail_card.tscn")
const _SPORE_DETAIL_CARD_SCENE := preload("res://assets/base/spore_detail_card/spore_detail_card.tscn")
const _FLOATING_ARROW_SCENE := preload("res://assets/ui/floating_arrow/floating_arrow.tscn")

var cost: int = 0
var payload: Dictionary = {}
var slot_index: int = -1
var is_locked: bool = false
var _can_afford: bool = true
var _pressing: bool = false
var _did_drag: bool = false
var _item_tint: Color = Color.WHITE
var _title: String = ""
var _subtitle: String = ""
var _description: String = ""
var _icon_texture: Texture2D = null
var _reroll_preview_tween: Tween = null
var _buy_hint_arrow: FloatingArrow = null

@onready var _content: Control = $CardPanel
@onready var _icon: TextureRect = %Icon
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _price_label: Label = %PriceLabel
@onready var _tier_tag: TagChip = %TierTag
@onready var _footer_row: HBoxContainer = %FooterRow
@onready var _lock_button: Button = %LockButton
@onready var _hover_punch: HoverPunch = %HoverPunch


func setup(
	title: String,
	subtitle: String,
	offer_cost: int,
	offer_payload: Dictionary,
	icon: Texture2D = null,
	offer_slot_index: int = -1,
	locked: bool = false,
	item_tint: Color = Color.WHITE,
	description: String = ""
) -> void:
	cost = offer_cost
	payload = offer_payload.duplicate(true)
	slot_index = offer_slot_index
	is_locked = locked
	_item_tint = item_tint
	_title = title
	_subtitle = subtitle
	_description = description
	_icon_texture = icon
	if is_node_ready():
		_apply_content(title, subtitle, description, icon)
		set_locked(is_locked)
		set_affordable(_can_afford)
	else:
		ready.connect(
			func() -> void:
				_apply_content(title, subtitle, description, icon)
				set_locked(is_locked)
				set_affordable(_can_afford),
			CONNECT_ONE_SHOT
		)


func set_affordable(affordable: bool) -> void:
	_can_afford = affordable
	if not is_node_ready():
		return
	if _content != null:
		_content.modulate = Color.WHITE if affordable else Color(1, 1, 1, 0.45)
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if affordable else Control.CURSOR_ARROW
	)


func set_locked(locked: bool) -> void:
	is_locked = locked
	if not is_node_ready():
		return
	_lock_button.visible = locked
	_lock_button.modulate = Color.WHITE
	_lock_button.tooltip_text = "Unlock" if locked else "Lock"


## Tutorial arrow above this offer (e.g. Common Generalist until first buy).
func set_buy_hint_visible(should_show: bool) -> void:
	if should_show:
		_ensure_buy_hint_arrow()
		# Arrow sits above the card; clipping would hide it.
		clip_contents = false
		_buy_hint_arrow.show_arrow()
	elif _buy_hint_arrow != null:
		_buy_hint_arrow.hide_arrow()


func _ensure_buy_hint_arrow() -> void:
	if _buy_hint_arrow != null:
		return
	_buy_hint_arrow = _FLOATING_ARROW_SCENE.instantiate() as FloatingArrow
	add_child(_buy_hint_arrow)
	_buy_hint_arrow.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_buy_hint_arrow.offset_left = -FloatingArrow.ARROW_SIZE.x * 0.5
	_buy_hint_arrow.offset_right = FloatingArrow.ARROW_SIZE.x * 0.5
	_buy_hint_arrow.offset_top = -FloatingArrow.ARROW_SIZE.y - 4.0
	_buy_hint_arrow.offset_bottom = -4.0


## Soft scale used while the shop reroll button is hovered.
func set_reroll_preview(active: bool) -> void:
	if _reroll_preview_tween != null:
		_reroll_preview_tween.kill()
		_reroll_preview_tween = null
	pivot_offset = size * 0.5
	var target := Vector2(REROLL_PREVIEW_SCALE, REROLL_PREVIEW_SCALE) if active else Vector2.ONE
	var duration := REROLL_PREVIEW_IN_SEC if active else REROLL_PREVIEW_OUT_SEC
	_reroll_preview_tween = create_tween()
	_reroll_preview_tween.tween_property(self, "scale", target, duration)\
		.set_trans(Tween.TRANS_BACK if active else Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


func clear_reroll_preview() -> void:
	if _reroll_preview_tween != null:
		_reroll_preview_tween.kill()
		_reroll_preview_tween = null
	scale = Vector2.ONE
	rotation = 0.0


## Brief rotation shake after a shop reroll.
func play_reroll_shake(delay_sec: float = 0.0) -> void:
	if _reroll_preview_tween != null:
		_reroll_preview_tween.kill()
		_reroll_preview_tween = null
	pivot_offset = size * 0.5
	rotation = 0.0
	var dir := 1.0 if randf() < 0.5 else -1.0
	var shake := deg_to_rad(REROLL_SHAKE_DEG * randf_range(0.8, 1.2)) * dir
	var step := REROLL_SHAKE_STEP_SEC * randf_range(0.85, 1.15)
	_reroll_preview_tween = create_tween()
	if delay_sec > 0.0:
		_reroll_preview_tween.tween_interval(delay_sec)
	_reroll_preview_tween.tween_property(self, "rotation", shake, step)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_reroll_preview_tween.tween_property(self, "rotation", -shake, step * 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_reroll_preview_tween.tween_property(self, "rotation", shake * 0.4, step)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_reroll_preview_tween.tween_property(self, "rotation", 0.0, step)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func reset_compact_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	anchor_right = anchor_left
	anchor_bottom = anchor_top
	offset_left = 0.0
	offset_top = 0.0
	offset_right = CARD_SIZE.x
	offset_bottom = CARD_SIZE.y
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size = CARD_SIZE
	_set_children_mouse_filter_ignore(_content)
	_lock_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_lock_button.pressed.connect(_on_lock_pressed)
	reset_compact_layout()


func _apply_content(title: String, subtitle: String, description: String, icon: Texture2D) -> void:
	_title_label.text = title
	_subtitle_label.text = subtitle
	_description_label.text = description
	_description_label.visible = not description.is_empty()
	_price_label.text = "%d" % cost
	if icon != null and _icon != null:
		_icon.texture = icon
	if _icon != null:
		_icon.modulate = _item_tint
	_refresh_rarity_chip()
	# Weapon/spore offers get a rich detail tooltip; other shop items leave this empty.
	if payload.get("weapon") is WeaponData or payload.get("spore") is SporeData:
		tooltip_text = title
	else:
		tooltip_text = ""


func _refresh_rarity_chip() -> void:
	if _tier_tag == null:
		return
	if _footer_row != null:
		_footer_row.visible = true
	var tier := UnitStatsData.PowerTier.COMMON
	var spore := payload.get("spore") as SporeData
	if spore != null:
		tier = spore.power_tier
	_tier_tag.visible = true
	_tier_tag.set_text(UnitStatsData.label_for_tier(tier))
	_tier_tag.set_fill_color(UnitStatsData.tint_for_tier(tier))


func _make_custom_tooltip(_for_text: String) -> Object:
	var weapon := payload.get("weapon") as WeaponData
	if weapon != null:
		var weapon_tip: WeaponDetailCard = _WEAPON_DETAIL_CARD_SCENE.instantiate()
		weapon_tip.setup(weapon, false)
		var weapon_tip_size := weapon_tip.card_size()
		weapon_tip.custom_minimum_size = weapon_tip_size
		weapon_tip.size = weapon_tip_size
		weapon_tip.tree_entered.connect(
			_configure_detail_tooltip_popup.bind(weapon_tip), CONNECT_ONE_SHOT
		)
		return weapon_tip
	var spore := payload.get("spore") as SporeData
	if spore == null:
		return null
	var tip: SporeDetailCard = _SPORE_DETAIL_CARD_SCENE.instantiate()
	tip.setup(spore, false)
	var tip_size := tip.card_size()
	tip.custom_minimum_size = tip_size
	tip.size = tip_size
	tip.tree_entered.connect(_configure_detail_tooltip_popup.bind(tip), CONNECT_ONE_SHOT)
	return tip


func _configure_detail_tooltip_popup(tip: Control) -> void:
	var tip_size := Vector2.ZERO
	if tip.has_method("card_size"):
		tip_size = tip.call("card_size") as Vector2
	else:
		tip_size = tip.size
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


func _set_children_mouse_filter_ignore(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)


func _on_lock_pressed() -> void:
	lock_toggled.emit(self)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_RIGHT:
			if mouse.pressed:
				lock_toggled.emit(self)
				accept_event()
			return
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_pressing = true
			_did_drag = false
			return
		if _pressing:
			_pressing = false
			if _can_afford and not _did_drag:
				offer_clicked.emit(self)
			accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _can_afford or payload.is_empty():
		return null
	_did_drag = true
	if _hover_punch != null:
		_hover_punch.reset()
	# Chess-piece pickup: leave the pad empty while dragging.
	visible = false
	# Instantiate fresh — duplicate() keeps @onready refs to this card.
	var preview: ShopOfferCard = _SHOP_OFFER_CARD_SCENE.instantiate()
	preview.setup(
		_title,
		_subtitle,
		cost,
		payload,
		_icon_texture,
		slot_index,
		is_locked,
		_item_tint,
		_description
	)
	preview.set_affordable(true)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.clip_contents = false
	set_drag_preview(_centered_drag_preview(preview, CARD_SIZE))
	return payload.duplicate(true)


func _centered_drag_preview(preview: Control, preview_size: Vector2) -> Control:
	# Viewport pins the preview root origin to the cursor. Offset the child so the
	# card center sits there. Must run after preview.ready — _ready may reset layout.
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := func() -> void:
		# Slight downward bias so the offer hangs under the cursor.
		preview.position = Vector2(-preview_size.x * 0.5, -preview_size.y * 0.5 + 28.0)
	if preview.is_node_ready():
		center.call()
	else:
		preview.ready.connect(center, CONNECT_ONE_SHOT)
	host.add_child(preview)
	return host



func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_did_drag = false
		_pressing = false
		if _hover_punch != null:
			_hover_punch.reset()
			_hover_punch.suppress_enter()
		# Restore if the drag was cancelled; successful drops rebuild the card.
		if is_inside_tree():
			visible = true
		if _hover_punch != null:
			_hover_punch.call_deferred("arm_enter_unless_hovered")


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var zone := _find_host_shop_zone()
	if zone != null:
		return zone._can_drop_data(at_position, data)
	return false


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var zone := _find_host_shop_zone()
	if zone != null:
		zone._drop_data(at_position, data)


func _find_host_shop_zone() -> ShopDropZone:
	var node: Node = get_parent()
	while node != null:
		if node is ShopDropZone:
			return node as ShopDropZone
		node = node.get_parent()
	return null
