class_name UnitNames
extends RefCounted

## Family names of famous naturalists and biologists for roster units.
const NAMES: Array[String] = [
	"Darwin",
	"Linnaeus",
	"Mendel",
	"Pasteur",
	"Wallace",
	"Hooker",
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
