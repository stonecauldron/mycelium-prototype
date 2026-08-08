class_name BiomassData
extends Resource

const PER_KILL := 4
const PER_IMAGO_KILL := 6
const COMPOST_CHILD := 2
const COMPOST_ADULT := 3
const COMMON_SPORE_COST := 4
const UNCOMMON_SPORE_COST := 8
const RARE_SPORE_COST := 16
const EPIC_SPORE_COST := 32
const LEGENDARY_SPORE_COST := 64
const MUTATION_COST := 3
const SHOP_REROLL_COST := 1
const SCOUT_REROLL_COST := 2
const PLOT_UNLOCK_BASE_COST := 4
const STARTING_AMOUNT := 3

@export var amount: int = STARTING_AMOUNT


static func reward_for_kill(is_imago: bool) -> int:
	return PER_IMAGO_KILL if is_imago else PER_KILL


static func reward_for_compost(is_adult: bool) -> int:
	return COMPOST_ADULT if is_adult else COMPOST_CHILD


static func sell_value(buy_cost: int) -> int:
	return maxi(1, int(buy_cost / 2.0))


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
	amount = STARTING_AMOUNT
