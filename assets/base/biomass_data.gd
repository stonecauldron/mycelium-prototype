class_name BiomassData
extends Resource

const PER_KILL := 5
const COMMON_SPORE_COST := 10

@export var amount: int = 0


func add(value: int) -> void:
	if value <= 0:
		return
	amount += value


func can_afford(cost: int) -> bool:
	return cost >= 0 and amount >= cost


func try_spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	amount -= cost
	return true


func reset() -> void:
	amount = 0
