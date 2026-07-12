extends Node

## Session owner for persistent run state.
var troop: TroopData = TroopData.new()
var nursery: NurseryData = NurseryData.new()
var current_day: int = 0


func ensure_nursery_seeded() -> void:
	nursery.seed_if_empty()


func reset_run() -> void:
	troop.reset()
	nursery.reset()
	current_day = 0
