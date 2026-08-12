class_name SealCatalog
extends RefCounted

const _SEAL_PATHS: Array[String] = [
	"res://assets/base/seals/golden_mould.tres",
	"res://assets/base/seals/rotten_thumb.tres",
	"res://assets/base/seals/phosphorus_mining.tres",
	"res://assets/base/seals/radioactivity.tres",
	"res://assets/base/seals/wooden_sword.tres",
	"res://assets/base/seals/wooden_bow.tres",
	"res://assets/base/seals/wooden_heart.tres",
	"res://assets/base/seals/wooden_clock.tres",
	"res://assets/base/seals/favourite_child.tres",
	"res://assets/base/seals/neotonia.tres",
	"res://assets/base/seals/hybrid_vigor.tres",
	"res://assets/base/seals/fertilizer_spreader.tres",
	"res://assets/base/seals/mad_scientist.tres",
	"res://assets/base/seals/bulwark.tres",
	"res://assets/base/seals/ranger.tres",
	"res://assets/base/seals/greenhouse.tres",
	"res://assets/base/seals/commoners_delight.tres",
]

static var _cache: Array[SealData] = []


static func all_seals() -> Array[SealData]:
	if _cache.is_empty():
		_cache = _load_all()
	return _cache


static func by_id(seal_id: StringName) -> SealData:
	for seal in all_seals():
		if seal.id == seal_id:
			return seal
	return null


## Distinct offers from the eligible pool (excludes owned unique seals).
static func roll_offers(count: int, collection: SealsCollection, rng: RandomNumberGenerator = null) -> Array[SealData]:
	var eligible := eligible_pool(collection)
	if count <= 0 or eligible.is_empty():
		var empty: Array[SealData] = []
		return empty
	var shuffled := eligible.duplicate()
	if rng != null:
		_shuffle_with_rng(shuffled, rng)
	else:
		shuffled.shuffle()
	var result: Array[SealData] = []
	var take := mini(count, shuffled.size())
	for i in take:
		result.append(shuffled[i])
	return result


static func eligible_pool(collection: SealsCollection) -> Array[SealData]:
	var result: Array[SealData] = []
	for seal in all_seals():
		if seal == null:
			continue
		if seal.is_unique and collection != null and collection.owns(seal.id):
			continue
		result.append(seal)
	return result


static func _load_all() -> Array[SealData]:
	var seals: Array[SealData] = []
	for path in _SEAL_PATHS:
		var seal := load(path) as SealData
		if seal != null:
			seals.append(seal)
	return seals


static func _shuffle_with_rng(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
