class_name SealsCollection
extends RefCounted

var owned: Array[SealData] = []


func reset() -> void:
	owned.clear()


func count(seal_id: StringName) -> int:
	var n := 0
	for seal in owned:
		if seal != null and seal.id == seal_id:
			n += 1
	return n


func owns(seal_id: StringName) -> bool:
	return count(seal_id) > 0


func add(seal: SealData) -> bool:
	if seal == null:
		return false
	if seal.is_unique and owns(seal.id):
		return false
	owned.append(seal)
	return true


func all_owned() -> Array[SealData]:
	var result: Array[SealData] = []
	for seal in owned:
		if seal != null:
			result.append(seal)
	return result
