class_name MutationData
extends Resource

enum Slot { BODY, CAP }

const BIOMASS_COST := BiomassData.MUTATION_COST
const _BODY_SLOT_ICON := preload("res://assets/base/nursery/mutations/body_mutation_icon.png")
const _CAP_SLOT_ICON := preload("res://assets/base/nursery/mutations/cap_mutation_icon.png")
const _SLOT_BADGE_META := &"_mutation_slot_badge"

@export var display_name: String = "Mutation"
@export_multiline var short_description: String = ""
@export var slot: Slot = Slot.BODY
@export var biomass_cost: int = BiomassData.MUTATION_COST
@export var tint: Color = Color.WHITE
## Optional custom body/cap appearance for juvenile stage. Null → Generalist default.
@export var juvenile_appearance: PackedScene
## Optional custom body/cap appearance for imago stage. Null → Generalist default.
@export var imago_appearance: PackedScene
## Legacy: body silhouette scale. Player compose no longer applies this; prefer custom
## body appearance hurtboxes instead.
@export var silhouette_scale: Vector2 = Vector2.ONE
@export var effect: MutationEffect


func is_body() -> bool:
	return slot == Slot.BODY


func is_cap() -> bool:
	return slot == Slot.CAP


func slot_label() -> String:
	return "Body" if is_body() else "Cap"


func title_text() -> String:
	return "%s %s" % [display_name, slot_label()]


func subtitle_text() -> String:
	var authored := short_description.strip_edges()
	if not authored.is_empty():
		return authored
	return "no effect"


func effect_line() -> String:
	return "%s: %s" % [title_text(), subtitle_text()]


func slot_icon() -> Texture2D:
	return _BODY_SLOT_ICON if is_body() else _CAP_SLOT_ICON


## Centered body/cap badge on a mutation icon (shop/stock cards, plot chips).
static func attach_slot_badge(host: Control, mutation: MutationData, badge_size: Vector2) -> void:
	if host == null:
		return
	for child in host.get_children():
		if child is Control and (child as Control).has_meta(_SLOT_BADGE_META):
			host.remove_child(child)
			child.free()
	if mutation == null:
		return
	var badge := TextureRect.new()
	badge.set_meta(_SLOT_BADGE_META, true)
	badge.texture = mutation.slot_icon()
	badge.modulate = Color.WHITE
	badge.self_modulate = Color.WHITE
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.custom_minimum_size = badge_size
	badge.size = badge_size
	badge.set_anchors_preset(Control.PRESET_CENTER)
	badge.offset_left = -badge_size.x * 0.5
	badge.offset_top = -badge_size.y * 0.5
	badge.offset_right = badge_size.x * 0.5
	badge.offset_bottom = badge_size.y * 0.5
	host.add_child(badge)


func appearance_for(is_adult: bool) -> PackedScene:
	if is_adult:
		return imago_appearance
	return juvenile_appearance


func call_effect(method: StringName, args: Array = []) -> void:
	if effect == null or not effect.has_method(method):
		return
	effect.callv(method, args)


func get_stat_chip(roster: Resource) -> Dictionary:
	if effect == null:
		return {}
	return effect.get_stat_chip(roster)
