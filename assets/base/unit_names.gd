class_name UnitNames
extends RefCounted

## Family names of famous naturalists and biologists for roster units.
const NAMES: Array[String] = [
	"Darwin",
	"Linnaeus",
	"Mendel",
	"Pasteur",
	"Wallace",
	"Huxley",
	"Lamarck",
	"Cuvier",
	"Humboldt",
	"Audubon",
	"Carson",
	"Goodall",
	"Fossey",
	"Lorenz",
	"Mayr",
	"Haeckel",
	"Buffon",
	"Jenner",
	"Koch",
	"Fleming",
	"Franklin",
	"McClintock",
	"Muir",
	"Agassiz",
	"Banks",
	"Cousteau",
	"Attenborough",
	"Leakey",
	"Margulis",
	"Wilson",
	"Bartram",
	"Ray",
	"Malpighi",
	"Crick",
	"Watson",
	"Dobzhansky",
	"Theophrastus",
	"Vesalius",
	"Harvey",
	"Dawkins",
]


static func pick() -> String:
	if NAMES.is_empty():
		return "Unit"
	return NAMES[randi() % NAMES.size()]


static func pick_unique(count: int) -> Array[String]:
	var result: Array[String] = []
	if count <= 0:
		return result
	var pool: Array[String] = NAMES.duplicate()
	pool.shuffle()
	for i in count:
		if pool.is_empty():
			result.append(pick())
		else:
			result.append(pool.pop_back())
	return result


## Generation 1 has no suffix; generation 2+ is "Name II", "Name III", …
static func format_unit_name(lineage_name: String, generation: int) -> String:
	var base := lineage_name.strip_edges()
	if base.is_empty():
		base = "Unit"
	if generation <= 1:
		return base
	return "%s %s" % [base, roman_numeral(generation)]


static func roman_numeral(value: int) -> String:
	if value <= 0:
		return ""
	var n := value
	var result := ""
	var amounts: Array[int] = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var glyphs: Array[String] = [
		"M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I",
	]
	for i in amounts.size():
		var amount := amounts[i]
		var glyph := glyphs[i]
		while n >= amount:
			result += glyph
			n -= amount
	return result
