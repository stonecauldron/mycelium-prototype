class_name BiomassData
extends Resource

const PER_KILL := 5
const PER_IMAGO_KILL := 7
const COMMON_SPORE_COST := 4
const RARE_SPORE_COST := 8
const SHOP_REROLL_COST := 2
const SCOUT_REROLL_COST := 2
const PLOT_UNLOCK_BASE_COST := 4
const RARE_SPORE_CHANCE := 0.1

@export var amount: int = 0


static func reward_for_kill(is_imago: bool) -> int:
	return PER_IMAGO_KILL if is_imago else PER_KILL


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
