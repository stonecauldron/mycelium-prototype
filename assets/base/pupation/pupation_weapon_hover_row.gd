class_name PupationWeaponHoverRow
extends HBoxContainer

## Training slots and result icon with a WeaponDetailCard tooltip.

const _WEAPON_DETAIL_CARD_SCENE := preload("res://assets/base/weapon_detail_card/weapon_detail_card.tscn")

var weapon: WeaponData = null

@onready var _equation: TrainingEquation = $TrainingEquation


func _ready() -> void:
	_equation.alignment = BoxContainer.ALIGNMENT_CENTER


func set_unit(unit: RosterUnitData) -> void:
	weapon = unit.weapon if unit != null else null
	_equation.setup(unit)
	# Non-empty text enables the tooltip popup; content comes from _make_custom_tooltip.
	tooltip_text = weapon.display_name if weapon != null else ""


func _make_custom_tooltip(_for_text: String) -> Object:
	if weapon == null:
		return null
	var tip: WeaponDetailCard = _WEAPON_DETAIL_CARD_SCENE.instantiate()
	tip.setup(weapon, false)
	return DetailTooltipPopup.configure(tip)
