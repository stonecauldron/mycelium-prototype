extends Node

## Export real character scenes at a fixed idle pose. No gameplay scene is entered.
const PACKAGE := "res://handover/auto-shrooms-website/"
const SIZE := 768
const MARGIN := 48.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE + "presskit-content.json"))
	var output := PACKAGE + "press/characters/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var records: Array[Dictionary] = []
	for entry: Dictionary in data["characters"]:
		var spec: Dictionary = entry["render"]
		var viewport := SubViewport.new()
		viewport.size = Vector2i(SIZE, SIZE)
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.world_2d = World2D.new()
		add_child(viewport)
		var character: Node2D
		assert(spec["kind"] in ["child", "adult"], "Presskit units must be Child or Adult")
		character = UnitAppearance.compose_player(spec["kind"] == "adult")
		viewport.add_child(character)
		var shadow := character.get_node_or_null("GroundShadow") as CanvasItem
		if shadow != null:
			shadow.hide()
		var animation := character.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if animation != null:
			animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			animation.play("idle")
			animation.seek(0.0, true)
		# First render measures actual non-transparent pixels of the weaponless unit.
		character.position = Vector2(SIZE * 0.5, SIZE - 70.0)
		character.scale = Vector2(1.5, 1.5)
		for frame in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var initial := viewport.get_texture().get_image()
		var bounds := initial.get_used_rect()
		assert(bounds.has_area(), "Empty character render: " + str(entry["file"]))
		assert(bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < SIZE and bounds.end.y < SIZE, "Initial render clipped")
		var zoom := (float(SIZE) - MARGIN * 2.0) / maxf(bounds.size.x, bounds.size.y)
		var center := Vector2(bounds.position) + Vector2(bounds.size) * 0.5
		viewport.canvas_transform = Transform2D(Vector2(zoom, 0), Vector2(0, zoom), Vector2(SIZE, SIZE) * 0.5 - center * zoom)
		for frame in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		var final_bounds := rendered.get_used_rect()
		var path := output + str(entry["file"]) + ".png"
		var result := rendered.save_png(path)
		assert(result == OK, "Could not save character render")
		var textures: Array[String] = []
		for node: Node in character.find_children("*", "Sprite2D", true, false):
			var sprite := node as Sprite2D
			if sprite.is_visible_in_tree() and sprite.texture != null:
				var texture_path := sprite.texture.resource_path
				if not texture_path.is_empty() and not textures.has(texture_path):
					textures.append(texture_path.trim_prefix("res://"))
		records.append({"file": str(entry["file"]) + ".png", "source": spec["source"], "textures": textures,
			"size": [SIZE, SIZE], "visible_bounds": [final_bounds.position.x, final_bounds.position.y, final_bounds.size.x, final_bounds.size.y],
			"pose": "idle at 0 seconds", "transparent_background": true, "ground_shadow": false})
		print("CHARACTER EXPORTED: ", entry["file"], " ", final_bounds)
		viewport.queue_free()
		await get_tree().process_frame
	var file := FileAccess.open(PACKAGE + "character-renders.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "  ") + "\n")
	file.close()
	get_tree().quit()
