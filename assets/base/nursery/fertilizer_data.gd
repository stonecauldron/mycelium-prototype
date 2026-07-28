class_name FertilizerData
extends Resource

enum Behavior {
	STAT,
	VOLATILE,
	OVERKILL,
	MEIOSIS,
	SLOW_STEADY,
	FUNGICIDE,
	AMOK,
}

@export var display_name: String = "Fertilizer"
@export var biomass_cost: int = 6
@export var tint: Color = Color.WHITE
@export var behavior: Behavior = Behavior.STAT
@export var strength_delta: int = 0
@export var dex_delta: int = 0
@export var con_delta: int = 0
@export var spd_delta: int = 0
## Extra growth days granted when this fertilizer is applied (or when planting onto a prepared plot).
@export var growth_bonus: int = 0


func is_stat_source() -> bool:
	return behavior == Behavior.STAT or behavior == Behavior.SLOW_STEADY


func apply_to(stats: UnitStatsData, scale_factor: int = 1) -> void:
	if stats == null or not is_stat_source():
		return
	var factor := maxi(scale_factor, 1)
	stats.strength = clampi(stats.strength + strength_delta * factor, 1, 99)
	stats.dex = clampi(stats.dex + dex_delta * factor, 1, 99)
	stats.con = clampi(stats.con + con_delta * factor, 1, 99)
	stats.spd = clampi(stats.spd + spd_delta * factor, 1, 99)


func subtitle_text() -> String:
	match behavior:
		Behavior.VOLATILE:
			return "×2 other fert stats (stacks)"
		Behavior.OVERKILL:
			return "+2 highest / -2 lowest"
		Behavior.MEIOSIS:
			return "hatch ×2, half stats"
		Behavior.SLOW_STEADY:
			return "+2 all / ×2 growth time"
		Behavior.FUNGICIDE:
			return "kill plant → next +1/active day"
		Behavior.AMOK:
			return "always charges"
		_:
			pass
	var parts: PackedStringArray = []
	if (
		strength_delta != 0
		and strength_delta == dex_delta
		and strength_delta == con_delta
		and strength_delta == spd_delta
	):
		var all_sign := "+" if strength_delta > 0 else ""
		parts.append("%s%d all" % [all_sign, strength_delta])
	else:
		var bonuses: PackedStringArray = []
		var maluses: PackedStringArray = []
		_append_delta_part(bonuses, maluses, "STR", strength_delta)
		_append_delta_part(bonuses, maluses, "DEX", dex_delta)
		_append_delta_part(bonuses, maluses, "CON", con_delta)
		_append_delta_part(bonuses, maluses, "SPD", spd_delta)
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
