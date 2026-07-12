extends Node

## Session owner for persistent run state.
const WIN_DAYS := 10

var troop: TroopData = TroopData.new()
var nursery: NurseryData = NurseryData.new()
var current_day: int = 0


func get_upcoming_day() -> int:
	return current_day + 1


func has_won_run() -> bool:
	return current_day >= WIN_DAYS


func ensure_nursery_seeded() -> void:
	nursery.seed_if_empty()


func reset_run() -> void:
	troop.reset()
	nursery.reset()
	current_day = 0
