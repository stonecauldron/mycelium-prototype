class_name StrainEffect
extends Resource

enum DeathContext { COMBAT, AGED_OUT }


## Called once when the unit is created at nursery harvest.
func on_hatch(_roster: Resource) -> void:
	pass


## Called after each post-battle day advance on the roster unit.
func on_day(_roster: Resource) -> void:
	pass


## Called when the unit promotes to imago (after the global +2 bonus).
func on_imago(_roster: Resource) -> void:
	pass


func on_battle_start(_unit: Node, _context: BattleStartContext = null) -> void:
	pass


func on_battle_end(_unit: Node) -> void:
	pass


func on_hit_dealt(_attacker: Node, _target: Node, _damage: int) -> void:
	pass


func on_hit_taken(_unit: Node, _amount: int, _damage_type: int) -> void:
	pass


func on_kill(_killer: Node, _victim: Node) -> void:
	pass


func on_death(_roster: Resource, _context: DeathContext, _combat_unit: Node = null) -> void:
	pass


## Fired for each living unit when any combat death grants biomass (Piñata banking).
func on_combat_biomass_awarded(_unit: Node, _amount: int, _victim: Node) -> void:
	pass


## Optional strain-specific chip for unit cards. Empty Dictionary = no chip.
## Expected keys when present: `icon` (Texture2D), `value` (Variant).
func get_stat_chip(_roster: Resource) -> Dictionary:
	return {}
