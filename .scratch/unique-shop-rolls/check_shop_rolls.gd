extends Node

var _failed: int = 0
var _assertions: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_initial_rolls()
	_check_rerolls()
	_check_locks()
	_check_purchase_and_history()
	_check_daily_refresh()
	_check_normalization()
	_check_mutation_odds()
	_check_pool_exhaustion()
	print("shop_rolls_check: %d assertions, %d failures" % [_assertions, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check_initial_rolls() -> void:
	seed(6301)
	for sample in 128:
		var nursery := NurseryData.new()
		nursery.seed_if_empty()
		_check_unique_offers(nursery, "initial roll %d" % sample)


func _check_rerolls() -> void:
	seed(6302)
	var nursery := NurseryData.new()
	nursery.seed_if_empty()
	for sample in 128:
		nursery.reroll_unlocked_shop_offers()
		_check_unique_offers(nursery, "reroll %d" % sample)


func _check_locks() -> void:
	seed(6303)
	for locked_slot in 4:
		var nursery := NurseryData.new()
		nursery.ensure_shop_offers()
		var locked_offer := nursery.spore_shop.offers[locked_slot]
		nursery.spore_shop.set_locked(locked_slot, true)
		var matched_lock := false
		for sample in 128:
			nursery.reroll_unlocked_shop_offers()
			_expect(nursery.spore_shop.offers[locked_slot] == locked_offer, "retained locked offer")
			_check_unique_offers(nursery, "partial lock", true)
			for offer in nursery.spore_shop.offers:
				if not offer.locked and offer.item == locked_offer.item:
					matched_lock = true
		_expect(matched_lock, "new offers may match a lock in slot %d" % locked_slot)

	var nursery := NurseryData.new()
	nursery.ensure_shop_offers()
	var fat := load("res://assets/base/nursery/mutations/body/fat.tres") as MutationData
	for i in [2, 3]:
		nursery.spore_shop.offers[i].item = fat
		nursery.spore_shop.set_locked(i, true)
	nursery.reroll_unlocked_shop_offers()
	_expect(nursery.spore_shop.offers[2].item == fat and nursery.spore_shop.offers[3].item == fat, "duplicate locks survive")
	var retained := nursery.spore_shop.offers.duplicate()
	for i in 4:
		nursery.spore_shop.set_locked(i, true)
	nursery.reroll_unlocked_shop_offers()
	_expect(nursery.spore_shop.offers == retained, "fully locked Shop stays unchanged")


func _check_purchase_and_history() -> void:
	var nursery := NurseryData.new()
	seed(6304)
	nursery.ensure_shop_offers()
	var previous := nursery.spore_shop.offers.duplicate()
	_expect(nursery.add_stock_item(previous[0].item), "put purchased item in Stock")
	nursery.replace_shop_slot(0)
	nursery.ensure_shop_offers()
	_expect(nursery.spore_shop.offers[0] == null, "reopening does not refill a purchased slot")
	for i in range(1, 4):
		_expect(nursery.spore_shop.offers[i] == previous[i], "reopening retains existing offers")
	seed(6304)
	nursery.reroll_unlocked_shop_offers()
	for i in 4:
		_expect(nursery.spore_shop.offers[i].item == previous[i].item, "previous roll and Stock do not exclude items")
	_check_unique_offers(nursery, "after purchase")
	nursery.reset()
	nursery.seed_if_empty()
	_check_unique_offers(nursery, "new Run")


func _check_daily_refresh() -> void:
	seed(6305)
	GameState.nursery = NurseryData.new()
	for sample in 128:
		GameState.nursery.advance_shop_reroll_cost()
		GameState.refresh_shops_for_new_day()
		_expect(GameState.nursery.shop_rerolls_today == 0, "daily refresh resets reroll price")
		_check_unique_offers(GameState.nursery, "daily refresh")
	var locked_offer := GameState.nursery.spore_shop.offers[3]
	GameState.nursery.spore_shop.set_locked(3, true)
	GameState.refresh_shops_for_new_day()
	_expect(GameState.nursery.spore_shop.offers[3] == locked_offer, "daily refresh retains locks")
	_check_unique_offers(GameState.nursery, "daily refresh with lock", true)


func _check_normalization() -> void:
	seed(6306)
	var spore := load("res://assets/base/nursery/common_spore.tres") as SporeData
	for sample in 128:
		var nursery := NurseryData.new()
		nursery.ensure_shop_offers()
		for offer in nursery.spore_shop.offers:
			offer.item = spore
		nursery.ensure_shop_offers()
		_check_unique_offers(nursery, "legacy normalization")
		var fertilizer := nursery.spore_shop.offers[0].item
		var mutation := nursery.spore_shop.offers[2].item
		for i in 4:
			nursery.spore_shop.offers[i].item = mutation if i < 2 else fertilizer
		nursery.ensure_shop_offers()
		_check_unique_offers(nursery, "wrong-category normalization")


func _check_mutation_odds() -> void:
	seed(6307)
	var nursery := NurseryData.new()
	var body_count := 0
	var body_pairs := 0
	var cap_pairs := 0
	for sample in 2048:
		nursery.reroll_unlocked_shop_offers()
		var first := nursery.spore_shop.offers[2].item as MutationData
		var second := nursery.spore_shop.offers[3].item as MutationData
		body_count += int(first.is_body()) + int(second.is_body())
		body_pairs += int(first.is_body() and second.is_body())
		cap_pairs += int(first.is_cap() and second.is_cap())
	_expect(body_count > 1900 and body_count < 2200, "Body/Cap odds remain approximately 50/50")
	_expect(body_pairs > 400 and cap_pairs > 400, "two different Bodies or Caps remain possible")


func _check_pool_exhaustion() -> void:
	seed(6308)
	var nursery := NurseryData.new()
	var selected_fertilizers: Array[String] = []
	for i in 15:
		var prior := selected_fertilizers.duplicate()
		var offer := nursery.generate_fertilizer_offer(selected_fertilizers)
		_expect(not prior.has(offer.item.resource_path), "use each available Fertilizer before repeating")
	var exhausted := selected_fertilizers.duplicate()
	var repeated := nursery.generate_fertilizer_offer(selected_fertilizers)
	_expect(repeated != null and not repeated.is_empty(), "exhausted Fertilizer pool still fills slot")
	_expect(exhausted.has(repeated.item.resource_path), "exhausted Fertilizer pool permits a repeat")

	var selected_mutations: Array[String] = []
	var selected_bodies: Array[String] = []
	for sample in 256:
		var offer := nursery.generate_mutation_offer(selected_mutations)
		var mutation := offer.item as MutationData
		if mutation.is_body() and not selected_bodies.has(mutation.resource_path):
			selected_bodies.append(mutation.resource_path)
		if selected_bodies.size() == 4:
			break
	_expect(selected_bodies.size() == 4, "collect the four authored Body items")
	var body_count := 0
	for sample in 512:
		var batch := selected_bodies.duplicate()
		var offer := nursery.generate_mutation_offer(batch)
		var mutation := offer.item as MutationData
		if mutation.is_body():
			body_count += 1
			_expect(selected_bodies.has(mutation.resource_path), "repeat Body despite unused Caps")
	_expect(body_count > 200 and body_count < 310, "exhausting Body pool preserves category odds")


func _check_unique_offers(nursery: NurseryData, label: String, ignore_locks: bool = false) -> void:
	var seen: Array[Resource] = []
	_expect(nursery.spore_shop.offers.size() == 4, "%s: four slots" % label)
	for i in nursery.spore_shop.offers.size():
		var offer := nursery.spore_shop.offers[i]
		_expect(offer != null and not offer.is_empty(), "%s: filled slot %d" % [label, i])
		if offer == null or offer.is_empty():
			continue
		if not (ignore_locks and offer.locked):
			_expect(not seen.has(offer.item), "%s: distinct item in slot %d" % [label, i])
			seen.append(offer.item)
		if i < 2:
			_expect(offer.item is FertilizerData, "%s: Fertilizer row" % label)
		else:
			_expect(offer.item is MutationData, "%s: Mutation row" % label)


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failed += 1
		if _failed <= 10:
			push_error(message)
