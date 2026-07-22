class_name FertilizerData
extends Resource

@export var display_name: String = "Fertilizer"
@export var biomass_cost: int = 6
@export var tint: Color = Color.WHITE
@export var strength_delta: int = 0
@export var dex_delta: int = 0
@export var con_delta: int = 0
@export var spd_delta: int = 0
## Extra growth days granted when this fertilizer is applied (or when planting onto a prepared plot).
@export var growth_bonus: int = 0


func apply_to(stats: UnitStatsData) -> void:
	if stats == null:
		return
	stats.strength = clampi(stats.strength + strength_delta, 1, 99)
	stats.dex = clampi(stats.dex + dex_delta, 1, 99)
	stats.con = clampi(stats.con + con_delta, 1, 99)
	stats.spd = clampi(stats.spd + spd_delta, 1, 99)


func subtitle_text() -> String:
	var bonuses: PackedStringArray = []
	var maluses: PackedStringArray = []
	_append_delta_part(bonuses, maluses, "STR", strength_delta)
	_append_delta_part(bonuses, maluses, "DEX", dex_delta)
	_append_delta_part(bonuses, maluses, "CON", con_delta)
	_append_delta_part(bonuses, maluses, "SPD", spd_delta)
	var parts: PackedStringArray = []
	parts.append_array(bonuses)
	parts.append_array(maluses)
	if growth_bonus != 0:
		var sign_text := "+" if growth_bonus > 0 else ""
		parts.append("%s%d growth" % [sign_text, growth_bonus])
	if parts.is_empty():
		return "no effect"
	return " / ".join(parts)


func _append_delta_part(
	bonuses: PackedStringArray,
	maluses: PackedStringArray,
	label: String,
	delta: int
) -> void:
	if delta == 0:
		return
	var sign_text := "+" if delta > 0 else ""
	var text := "%s%d %s" % [sign_text, delta, label]
	if delta > 0:
		bonuses.append(text)
	else:
		maluses.append(text)
