class_name BiomassData
extends Resource

## Battle reward base for day 1; each later day adds BATTLE_REWARD_PER_DAY.
const BATTLE_REWARD_DAY_1 := 10
const BATTLE_REWARD_PER_DAY := 5
## ± swing applied from easiest→hardest army for that day (0.1 → 0.9…1.1).
const BATTLE_REWARD_DIFFICULTY_SWING := 0.1
const COMPOST_CHILD := 2
const COMPOST_ADULT := 3
const COMMON_SPORE_COST := 4
const UNCOMMON_SPORE_COST := 8
const RARE_SPORE_COST := 16
const EPIC_SPORE_COST := 32
const LEGENDARY_SPORE_COST := 64
const MUTATION_COST := 4
const SHOP_REROLL_COST := 3
const SCOUT_REROLL_COST := 3
const SEAL_REROLL_COST := 15
const PLOT_UNLOCK_BASE_COST := 4
const SQUAD_SLOT_UNLOCK_COST := 8
const STARTING_AMOUNT := 3

@export var amount: int = STARTING_AMOUNT


## Day-scaled Battle reward before difficulty (upcoming battle day, 1-based).
static func base_battle_reward(day: int) -> int:
	var d := maxi(day, 1)
	return BATTLE_REWARD_DAY_1 + BATTLE_REWARD_PER_DAY * (d - 1)


## Full Battle reward: base × lerp(0.9, 1.1, difficulty_t), nearest int.
## `difficulty_t` is 0 (easiest that day) … 1 (hardest that day).
static func battle_reward(day: int, difficulty_t: float) -> int:
	var t := clampf(difficulty_t, 0.0, 1.0)
	var lo := 1.0 - BATTLE_REWARD_DIFFICULTY_SWING
	var hi := 1.0 + BATTLE_REWARD_DIFFICULTY_SWING
	var mult := lerpf(lo, hi, t)
	return maxi(roundi(float(base_battle_reward(day)) * mult), 0)


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
