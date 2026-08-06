class_name SealCatalog
extends RefCounted

const ICON_PATH := "res://assets/base/seals/seal.png"

const ID_GOLDEN_MOULD := &"golden_mould"
const ID_ROTTEN_THUMB := &"rotten_thumb"
const ID_WOODEN_SWORD := &"wooden_sword"
const ID_WOODEN_BOW := &"wooden_bow"
const ID_WOODEN_HEART := &"wooden_heart"
const ID_FAVOURITE_CHILD := &"favourite_child"
const ID_NEOTONIA := &"neotonia"
const ID_FERTILIZER_SPREADER := &"fertilizer_spreader"
const ID_BULWARK := &"bulwark"
const ID_RANGER := &"ranger"
const ID_GREENHOUSE := &"greenhouse"
const ID_COMMONERS_DELIGHT := &"commoners_delight"

static var _cache: Array[SealData] = []
static var _icon: Texture2D


static func all_seals() -> Array[SealData]:
	if _cache.is_empty():
		_cache = _build_all()
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


static func _build_all() -> Array[SealData]:
	var icon := _shared_icon()
	var seals: Array[SealData] = [
		_make(ID_GOLDEN_MOULD, "Golden Mould", "At the start of each day, gain 6 biomass", icon),
		_make(ID_ROTTEN_THUMB, "Rotten Thumb", "Spores cost 2 biomass less (capped at 1)", icon),
		_make(ID_WOODEN_SWORD, "Wooden Sword", "Your sporelings deal +2 melee dmg", icon),
		_make(ID_WOODEN_BOW, "Wooden Bow", "Your sporelings deal +2 ranged dmg", icon),
		_make(ID_WOODEN_HEART, "Wooden Heart", "Your sporelings have +8 HP", icon),
		_make(
			ID_FAVOURITE_CHILD,
			"Favourite Child",
			"First hatch of the day has permanent 1.5x ATK, 1.5x HP",
			icon
		),
		_make(ID_NEOTONIA, "Neotonia", "Child units have 1.5x ATK, 1.5x HP", icon),
		_make(
			ID_FERTILIZER_SPREADER,
			"Fertilizer Spreader",
			"Increase the number of fertilisers you can stack by 1",
			icon
		),
		_make(ID_BULWARK, "Bulwark", "The frontmost unit gains 2x HP", icon),
		_make(ID_RANGER, "Ranger", "The rearmost unit gains 2x ATK", icon),
		_make(ID_GREENHOUSE, "Greenhouse", "Spores take 1 day less to hatch", icon),
		_make(
			ID_COMMONERS_DELIGHT,
			"Commoners' Delight",
			"Units with no training have 2x ATK, 2x HP",
			icon
		),
	]
	return seals


static func _make(
	seal_id: StringName,
	display_name: String,
	description: String,
	icon: Texture2D
) -> SealData:
	var seal := SealData.new()
	seal.id = seal_id
	seal.display_name = display_name
	seal.description = description
	seal.icon = icon
	seal.is_unique = false
	return seal


static func _shared_icon() -> Texture2D:
	if _icon == null:
		_icon = load(ICON_PATH) as Texture2D
	return _icon


static func _shuffle_with_rng(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
