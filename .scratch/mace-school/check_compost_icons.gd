extends Node

const _BIN := preload("res://assets/base/composting_bin/composting_bin.png")
var _failures := 0
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(label)


func _run() -> void:
	GameState.reset_run()
	GameState.clear_pending_seal_choice()
	var units := StarterPackages.build_units(&"great_hammer")
	GameState.troop.seed_if_empty(units)
	var child: RosterUnitData = units[1]
	var mould: RosterUnitData = units[0]
	mould.cap_mutation = load("res://assets/base/nursery/mutations/cap/mould.tres") as MutationData
	mould.mould_compost_stacks = 7
	var info := mould.get_identity_stat_chip()
	_check(info.get("icon") == _BIN, "Mould counter uses compost bin")
	_check(info.get("value") == 7, "Mould compost count preserved")
	_check(child.get_identity_stat_chip().is_empty(), "No counter on unmutated unit")
	var card := load("res://assets/base/unit_card/unit_card.tscn").instantiate() as UnitCard
	card.setup(mould)
	add_child(card)
	card.position = Vector2(200, 350)
	_check(card._mutation_chip.icon == _BIN, "Unit card renders compost icon")
	_check(card._mutation_chip.get_node("%Value").text == "7", "Unit card renders compost count")
	var dialog := load("res://assets/base/pupation/compost_confirm_dialog.tscn").instantiate() as CompostConfirmDialog
	_check(dialog.get_node("%HeaderIcon").texture == _BIN, "Dialog editor preview uses compost bin")
	dialog.setup(child)
	add_child(dialog)
	_check(dialog.get_node("%HeaderIcon").texture == _BIN, "Live dialog uses compost bin")
	_check(dialog.get_node("%OutcomeBiomass").text == "+2 kg biomass", "Compost reward unchanged")
	if "--screenshot" in OS.get_cmdline_user_args():
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.scratch/mace-school/compost-icons.png")
	print("COMPOST ICONS: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
