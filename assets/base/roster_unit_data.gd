class_name RosterUnitData
extends Resource

const _DEFAULT_STRAIN := preload("res://assets/units/capling/capling_strain.tres")

@export var display_name: String = "Unit"
@export var stats: UnitStatsData
@export var weapon: WeaponData
@export var strain: UnitStrain


func get_range_class() -> WeaponData.WeaponRange:
	if weapon == null:
		return WeaponData.WeaponRange.MELEE
	return weapon.range_class


func mount_portrait(host: Control, portrait_scale: float = 0.55) -> UnitAppearance:
	if host == null or strain == null:
		return null
	var appearance := strain.instantiate_appearance()
	if appearance == null:
		return null
	host.add_child(appearance)
	appearance.scale = Vector2(portrait_scale, portrait_scale)
	_ensure_portrait_host_sync(host)
	_sync_portrait_in_host(host)
	appearance.mount_weapon_appearance(weapon)
	appearance.play_idle(true)
	return appearance


static func _ensure_portrait_host_sync(host: Control) -> void:
	if host.has_meta("_portrait_sync"):
		return
	var sync := func() -> void:
		_sync_portrait_in_host(host)
	host.set_meta("_portrait_sync", sync)
	host.resized.connect(sync)


static func _sync_portrait_in_host(host: Control) -> void:
	if not is_instance_valid(host):
		return
	for child in host.get_children():
		if child is UnitAppearance:
			(child as UnitAppearance).position = Vector2(
				host.size.x * 0.5,
				host.size.y - 4.0
			)


static func create(
	unit_name: String,
	unit_stats: UnitStatsData,
	unit_weapon: WeaponData,
	unit_strain: UnitStrain = null
) -> RosterUnitData:
	var data := RosterUnitData.new()
	data.display_name = unit_name
	data.stats = unit_stats
	data.weapon = unit_weapon
	data.strain = unit_strain if unit_strain != null else _DEFAULT_STRAIN
	return data
