extends Node

@onready var root: Window = get_tree().root

const CursorInputSpy = preload("res://.scratch/cursor-drag/input_spy.gd")

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Execute the production cursor script against the embedded-window registry.
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://assets/autoload/mouse_cursor.gd").replace(
		"Input.", "CursorInputSpy."
	).replace("extends Node", 'extends Node\nconst CursorInputSpy = preload("res://.scratch/cursor-drag/input_spy.gd")')
	if script.reload() != OK:
		get_tree().quit(2)
		return
	var cursor: Node = script.new()
	root.add_child(cursor)
	for texture in [cursor.get("_POINT"), cursor.get("_OPEN"), cursor.get("_CLOSED")]:
		if texture.get_size() != Vector2(64, 64):
			push_error("FAIL: cursor SVG must import at 64 x 64 pixels")
			get_tree().quit(1)
			return
	CursorInputSpy.mouse_enter()
	var source: UnitCard = load("res://assets/base/unit_card/unit_card.tscn").instantiate()
	source.setup(source._make_mock_unit())
	root.add_child(source)
	await get_tree().process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(70, 90)
	root.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = motion.position
	press.pressed = true
	root.push_input(press, true)
	motion = InputEventMouseMotion.new()
	motion.position = Vector2(110, 90)
	motion.relative = Vector2(40, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	if not root.gui_is_dragging():
		push_error("FAIL: drag did not start")
		get_tree().quit(1)
		return
	var closed: Texture2D = cursor.get("_CLOSED")
	for shape in [CursorInputSpy.CURSOR_CAN_DROP, CursorInputSpy.CURSOR_FORBIDDEN, CursorInputSpy.default_shape]:
		if CursorInputSpy.displayed_images.get(shape) != closed:
			push_error("FAIL: drag cursor shape %s still displays %s" % [shape, CursorInputSpy.displayed_images.get(shape)])
			root.gui_cancel_drag()
			get_tree().quit(1)
			return
	root.gui_cancel_drag()
	if CursorInputSpy.default_shape != CursorInputSpy.CURSOR_ARROW:
		push_error("FAIL: cancellation did not restore pointing cursor")
		get_tree().quit(1)
		return
	if CursorInputSpy.displayed_images.get(CursorInputSpy.CURSOR_DRAG) != cursor.get("_OPEN"):
		push_error("FAIL: draggable hover did not preserve the open hand")
		get_tree().quit(1)
		return
	print("PASS: embedded window displays closed hand on valid/invalid/empty-space drags; cancellation restores point/open")
	get_tree().quit()
