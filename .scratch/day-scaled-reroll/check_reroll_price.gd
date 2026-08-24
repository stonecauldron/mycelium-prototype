extends SceneTree


func _initialize() -> void:
	var failed := 0
	# Literals from the agreed Day table (upcoming battle day, 1-based nth).
	failed += _expect(BiomassData.reroll_increase(1) == 1, "day1 increase 1")
	failed += _expect(BiomassData.reroll_increase(3) == 1, "day3 increase 1")
	failed += _expect(BiomassData.reroll_increase(5) == 2, "day5 increase 2")
	failed += _expect(BiomassData.reroll_increase(8) == 3, "day8 increase 3")
	failed += _expect(BiomassData.reroll_increase(10) == 4, "day10 increase 4")

	failed += _expect(BiomassData.reroll_price(1, 1) == 1, "day1 first 1")
	failed += _expect(BiomassData.reroll_price(1, 2) == 2, "day1 second 2")
	failed += _expect(BiomassData.reroll_price(1, 3) == 3, "day1 third 3")
	failed += _expect(BiomassData.reroll_price(2, 1) == 2, "day2 first 2")
	failed += _expect(BiomassData.reroll_price(3, 1) == 3, "day3 first 3")
	failed += _expect(BiomassData.reroll_price(5, 1) == 5, "day5 first 5")
	failed += _expect(BiomassData.reroll_price(5, 2) == 7, "day5 second 7")
	failed += _expect(BiomassData.reroll_price(6, 1) == 6, "day6 first 6")
	failed += _expect(BiomassData.reroll_price(9, 1) == 9, "day9 first 9")
	failed += _expect(BiomassData.reroll_price(10, 1) == 11, "day10 first 11")
	failed += _expect(BiomassData.reroll_price(10, 3) == 19, "day10 third 19")

	failed += _expect(BiomassData.seal_reroll_price(1, 1) == 15, "seal day1 first 15")
	failed += _expect(BiomassData.seal_reroll_price(3, 1) == 17, "seal day3 first 17")
	failed += _expect(BiomassData.seal_reroll_price(3, 2) == 18, "seal day3 second 18")
	failed += _expect(BiomassData.seal_reroll_price(6, 1) == 20, "seal day6 first 20")
	failed += _expect(BiomassData.seal_reroll_price(6, 2) == 22, "seal day6 second 22")
	failed += _expect(BiomassData.seal_reroll_price(9, 1) == 23, "seal day9 first 23")
	failed += _expect(BiomassData.seal_reroll_price(9, 3) == 29, "seal day9 third 29")

	if failed > 0:
		push_error("reroll_price_check failed: %d assertion(s)" % failed)
		quit(1)
	else:
		print("reroll_price_check OK")
		quit(0)


func _expect(cond: bool, label: String) -> int:
	if cond:
		return 0
	push_error("FAIL: %s" % label)
	return 1
