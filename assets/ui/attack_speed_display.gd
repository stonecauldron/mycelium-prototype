class_name AttackSpeedDisplay
extends RefCounted

## Seconds between attacks: a lower value means a faster weapon.
const ICON := preload("res://assets/ui/attack_speed_icon.png")


static func format_seconds(seconds: float) -> String:
	return _number(seconds) + "s"


static func format_delta(delta: float) -> String:
	var rounded := snappedf(delta, 0.01)
	if is_zero_approx(rounded):
		return ""
	return ("+" if rounded > 0.0 else "−") + _number(absf(rounded)) + "s"


static func for_unit(unit: RosterUnitData) -> float:
	if unit == null or unit.weapon == null:
		return 0.0
	# Match the unit's persistent combat rate; temporary battle statuses are absent here.
	var rate := unit.attack_rate_multiplier * SealModifiers.attack_rate_multiplier()
	return unit.weapon.attack_interval / maxf(rate, 0.01)


static func _number(value: float) -> String:
	var text := "%.2f" % snappedf(value, 0.01)
	return text.trim_suffix("0").trim_suffix("0").trim_suffix(".")
