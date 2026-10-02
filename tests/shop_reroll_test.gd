extends Node


func _ready() -> void:
	Analytics.ga = null
	GameState.is_guided_run = false
	seed(20261002)
	var nursery := NurseryData.new()
	nursery.ensure_shop_offers()
	var shop := nursery.spore_shop
	for roll_index in 300:
		# Exercise ordinary rerolls, locked offers, and purchased empty slots.
		shop.set_locked(0, roll_index % 3 == 1)
		if roll_index % 3 == 2:
			nursery.replace_shop_slot(1)
		var previous_paths: Array[String] = []
		for offer in shop.offers:
			if offer != null and not offer.is_empty():
				previous_paths.append(offer.item.resource_path)
		var locked_offer := shop.offers[0] if shop.is_locked(0) else null
		nursery.reroll_unlocked_shop_offers()
		var current_paths: Array[String] = []
		for slot_index in shop.offers.size():
			var offer := shop.offers[slot_index]
			if offer == null or offer.is_empty():
				_fail("Reroll left an empty slot")
				return
			var path := offer.item.resource_path
			if current_paths.has(path):
				_fail("Reroll duplicated an item")
				return
			current_paths.append(path)
			if slot_index == 0 and locked_offer != null:
				if offer != locked_offer or not offer.locked:
					_fail("Reroll replaced a locked offer")
					return
			elif previous_paths.has(path):
				_fail("Reroll repeated a previous item")
				return
	print("Shop reroll checks: 300 rerolls passed")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
