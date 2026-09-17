class_name BarkData
extends RefCounted

enum Kind { OPENING, KILL, MOURNING, VICTORY }

const LINES := {
	Kind.OPENING: [
		"No mercy for the Sun worshippers!",
		"Chlorophyll only serves deception.",
		"The Hallowed Mycelium will prevail.",
		"Onward, Comrades!",
		"May their roots tremble in fear!",
		"Forward! Let the Hallowed Mycelium bless us!",
		"Let those heathens taste the fury of rot!",
		"The Holy Pruning shall commence!",
		"Fungus vult!",
	],
	Kind.KILL: [
		"Your corpse will nourish our children.",
		"The Sun cannot save you.",
		"Compost for the cause!",
		"Photosynthesis has failed you.",
		"One less servant of the Sun!",
		"Return to the soil!",
		"Consider yourself pruned.",
	],
	Kind.MOURNING: [
		"Fear not, we will avenge you, comrade {fallen_name}!",
		"Comrade {fallen_name}, the Hallowed Mycelium will take you in.",
		"Rest beneath the soil, comrade {fallen_name}.",
		"The Hallowed Mycelium remembers you, {fallen_name}.",
		"Another Comrade taken. Trust the wrath of our vengeance, {fallen_name}.",
		"Back to the Hallowed Mycelium, {fallen_name}.",
	],
	Kind.VICTORY: [
		"Praise the Hallowed Mycelium!",
		"The Holy Pruning will carry on!",
		"With each triumph, the Hallowed Mycelium expands its reach!",
		"Rejoice in our victory, comrades!",
		"Rot and decomposition!",
		"Let the fallen rest.",
		"A glorious day for the Holy Pruning!",
		"Fungus vult!",
	],
}

## Cosmetic randomness must never advance the global gameplay generator.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var last_reaction_speaker: RosterUnitData = null
var _remaining: Dictionary = {}
var _last_lines: Dictionary = {}


func reset() -> void:
	_remaining.clear()
	_last_lines.clear()
	last_reaction_speaker = null
	rng.randomize()


## Preview without consuming: offscreen or suppressed dialogue is never used up.
func line_for(kind: Kind) -> String:
	if not _remaining.has(kind) or (_remaining[kind] as Array).is_empty():
		var pool: Array = LINES[kind].duplicate()
		for i in range(pool.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap: String = pool[i]
			pool[i] = pool[j]
			pool[j] = swap
		if pool.back() == _last_lines.get(kind, ""):
			var swap: String = pool[0]
			pool[0] = pool.back()
			pool[pool.size() - 1] = swap
		_remaining[kind] = pool
	return (_remaining[kind] as Array).back()


func mark_shown(kind: Kind) -> void:
	_last_lines[kind] = (_remaining[kind] as Array).pop_back()
