class_name BarkData
extends RefCounted

enum Kind { OPENING, KILL, MOURNING, VICTORY }

const LINES := {
	Kind.OPENING: [
		"No mercy for the sun worshippers!",
		"Chlorophyll is nothing but deception.",
		"Mycelium will prevail.",
		"Comrades, the shade belongs to us!",
		"Let their roots tremble!",
		"Forward! For the eternal Mycelium!",
	],
	Kind.KILL: [
		"Your sunlight cannot save you.",
		"Compost for the cause!",
		"Photosynthesis has failed you.",
		"One less servant of the sun!",
		"Return to the soil!",
		"Consider yourself pruned.",
	],
	Kind.MOURNING: [
		"Fear not, we will avenge you, comrade {fallen_name}!",
		"Our comrade has joined the Mycelium once again.",
		"Rest beneath the soil, comrade {fallen_name}.",
		"The Mycelium remembers you, {fallen_name}.",
		"Another comrade taken. Another debt to settle.",
		"Back to the Mycelium, {fallen_name}. We fight on.",
	],
	Kind.VICTORY: [
		"The Mycelium endures!",
		"The shade is ours!",
		"Victory, comrades!",
		"The sun has lost!",
		"Let the fallen rest.",
		"A glorious day for decomposition!",
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
