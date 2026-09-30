extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Analytics.ga = null
	GameState.reset_run()
	GameState.current_day = 1
	GameState.pending_seal_choice = false
	GameState.troop.seed_if_empty(StarterPackages.build_units(StarterPackages.PACKAGE_IDS[0]))
	var base := preload("res://assets/base/base.tscn").instantiate()
	get_tree().root.add_child(base)
	get_tree().current_scene = base
	await get_tree().process_frame
	var colony: TroopSelectionScreen = base.get_node("%ColonyScreen")
	colony._move_unit(GameState.troop.squad[0], "squad", 0, "bench", 0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/base-undo-preview.png")
	base.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
