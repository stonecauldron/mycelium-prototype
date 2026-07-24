class_name BiomassData
extends Resource

const PER_KILL := 5
const PER_IMAGO_KILL := 7
const COMMON_SPORE_COST := 4
const UNCOMMON_SPORE_COST := 8
const RARE_SPORE_COST := 16
const EPIC_SPORE_COST := 32
const LEGENDARY_SPORE_COST := 64
const SHOP_REROLL_COST := 2
const SCOUT_REROLL_COST := 2
const PLOT_UNLOCK_BASE_COST := 4
## Relative shop weights (= % when sum is 100): common, uncommon, rare, epic, legendary.
const SPORE_SHOP_WEIGHTS: Array[float] = [76.0, 20.0, 4.0, 0.0, 0.0]

@export var amount: int = 0


static func reward_for_kill(is_imago: bool) -> int:
	return PER_IMAGO_KILL if is_imago else PER_KILL


static func sell_value(buy_cost: int) -> int:
	return maxi(1, int(buy_cost / 4.0))


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
