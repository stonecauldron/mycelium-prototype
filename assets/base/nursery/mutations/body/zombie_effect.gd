class_name ZombieCapEffect
extends MutationEffect

const HP_MULTIPLIER := 0.5


static func is_zombie(roster: RosterUnitData) -> bool:
	if roster == null:
		return false
	return roster.body_mutation != null and roster.body_mutation.effect is ZombieCapEffect


static func hp_multiplier(roster: RosterUnitData) -> float:
	return HP_MULTIPLIER if is_zombie(roster) else 1.0


## Combat stage handles respawn after full death; this marks intent on the roster.
func on_death(roster: Resource, context: DeathContext, _combat_unit: Node = null) -> void:
	if context != DeathContext.COMBAT:
		return
	var data := roster as RosterUnitData
	if data == null:
		return
	# Flag is checked by combat_stage after normal death processing.
	data.set_meta("zombie_cap_wants_respawn", not data.has_revived)
