class_name ShopOfferCard
extends Control

signal offer_clicked(card: ShopOfferCard)
signal lock_toggled(card: ShopOfferCard)

const CARD_SIZE := Vector2(148, 176)

var cost: int = 0
var payload: Dictionary = {}
var slot_index: int = -1
var is_locked: bool = false
var _can_afford: bool = true
var _pressing: bool = false
var _did_drag: bool = false
var _item_tint: Color = Color.WHITE

@onready var _content: Control = $CardPanel
@onready var _icon: TextureRect = %Icon
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _price_label: Label = %PriceLabel
@onready var _lock_button: Button = %LockButton


func setup(
	title: String,
	subtitle: String,
	offer_cost: int,
	offer_payload: Dictionary,
	icon: Texture2D = null,
	offer_slot_index: int = -1,
	locked: bool = false,
	item_tint: Color = Color.WHITE
) -> void:
	cost = offer_cost
	payload = offer_payload.duplicate(true)
	slot_index = offer_slot_index
	is_locked = locked
	_item_tint = item_tint
	if is_node_ready():
		_apply_content(title, subtitle, icon)
		set_locked(is_locked)
		set_affordable(_can_afford)
	else:
		ready.connect(
			func() -> void:
				_apply_content(title, subtitle, icon)
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
	# Same padlock art; full opacity when locked, faded when unlocked.
	_lock_button.modulate = Color.WHITE if locked else Color(1, 1, 1, 0.4)
	_lock_button.tooltip_text = "Unlock" if locked else "Lock"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = CARD_SIZE
	_set_children_mouse_filter_ignore(_content)
	_lock_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_lock_button.pressed.connect(_on_lock_pressed)


func _apply_content(title: String, subtitle: String, icon: Texture2D) -> void:
	_title_label.text = title
	_subtitle_label.text = subtitle
	_price_label.text = "%d" % cost
	if icon != null and _icon != null:
		_icon.texture = icon
	if _icon != null:
		_icon.modulate = _item_tint


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
	# Avoid clip_contents — it cuts off the StyleBox bottom border on the preview.
	var preview_size := size if size.x > 0.0 and size.y > 0.0 else CARD_SIZE
	var host := Control.new()
	host.custom_minimum_size = preview_size
	host.size = preview_size
	host.clip_contents = false
	var preview := duplicate() as ShopOfferCard
	preview.modulate = Color(1, 1, 1, 0.85)
	preview.clip_contents = false
	preview.custom_minimum_size = preview_size
	preview.size = preview_size
	host.add_child(preview)
	set_drag_preview(host)
	return payload.duplicate(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_did_drag = false
		_pressing = false
