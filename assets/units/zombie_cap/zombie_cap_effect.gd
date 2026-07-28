class_name ZombieCapEffect
extends StrainEffect

## Combat stage handles respawn after full death; this marks intent on the roster.
func on_death(roster: Resource, context: DeathContext, _combat_unit: Node = null) -> void:
	if context != DeathContext.COMBAT:
		return
	var data := roster as RosterUnitData
	if data == null:
		return
	# Flag is checked by combat_stage after normal death processing.
	data.set_meta("zombie_cap_wants_respawn", not data.has_revived)
