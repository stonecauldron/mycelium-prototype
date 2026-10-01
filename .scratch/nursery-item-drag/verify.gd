extends Node

const FERTILIZER := preload("res://assets/base/nursery/fertilizers/finesse.tres")
const MUTATION := preload("res://assets/base/nursery/mutations/body/thorny.tres")

var _base: Node
var _nursery: NurseryScreen
var _zone: ShopDropZone
var _biomass: BiomassChip
var _checks := 0
var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(90.0).timeout.connect(func() -> void: get_tree().quit(99))
	call_deferred("_run")


func _run() -> void:
	Analytics.ga = null
	GameState.reset_run()
	GameState.current_day = 2
	GameState.pending_seal_choice = false
	GameState.troop.seed_if_empty(StarterPackages.build_units(&"great_sword_spear"))
	GameState.show_plot_plant_hint = false
	GameState.show_start_combat_hint = false
	_base = preload("res://assets/base/base.tscn").instantiate()
	get_tree().root.add_child(_base)
	get_tree().current_scene = _base
	_nursery = _base.get_node("%NurseryScreen") as NurseryScreen
	_zone = _nursery.get_node("%ShopDropZone") as ShopDropZone
	_biomass = _base.get_node("%BiomassChip") as BiomassChip
	_base._select_tab(_base.TabId.NURSERY, true)
	await _wait(1.3)
	await _move(Vector2(4, 4))
	for kind in ["fertilizer", "mutation"]:
		await _boundary_purchase_and_sale(kind)
		await _shop_direct_plot(kind)
		await _stock_pointer_plot_and_cancel(kind)
		await _stock_pointer_sale(kind)
	await _adjacent_plot()
	await _same_event_boundary_drop()
	await _cancel_presentations()
	print("NURSERY_ITEM_DRAG_CHECKS checks=", _checks, " failures=", _failures)
	DetailTooltipPopup.dismiss_current()
	_base.queue_free()
	await _wait(0.2)
	get_tree().quit(_failures)


func _reset(kind: String, owned: bool = false) -> Resource:
	var item: Resource = FERTILIZER if kind == "fertilizer" else MUTATION
	GameState.nursery.stock.clear()
	GameState.biomass.amount = 100
	GameState.nursery.unlocked_plot_count = 2
	for i in range(2):
		GameState.nursery.plots[i] = NurseryPlotData.new()
	var offer := ShopOffer.new()
	offer.item = item
	offer.cost = item.biomass_cost
	GameState.nursery.spore_shop.offers[0 if kind == "fertilizer" else 2] = offer
	if owned:
		GameState.nursery.stock.set_at(0, item)
	_nursery._build_plot_tiles()
	_nursery._rebuild_shop_cards()
	_nursery._refresh()
	GameState.base_undo.clear()
	await _move(Vector2(4, 4))
	return item


func _boundary_purchase_and_sale(kind: String) -> void:
	var item := await _reset(kind)
	var source := _offer(kind)
	var cost := source.cost
	var reroll_y := _rect(_nursery._reroll_button).position.y
	await _begin(source)
	var original: Dictionary = get_viewport().gui_get_drag_data()
	var preview := NurseryItemDragPreview.current(get_viewport())
	_check(preview != null and preview._showing_shop and preview.item_canvas_rect() == Rect2(), kind + " begins as offer without enlarged hit footprint")
	await _shot(kind + "-offer")
	var inside := _rect(source).get_center()
	var outside := Vector2(500, 580)
	for crossing in range(2):
		await _move(outside, true, 0.1)
		preview = NurseryItemDragPreview.current(get_viewport())
		_check(preview != null and not preview._showing_shop and preview.item_canvas_rect().has_area(), kind + " outside Shop becomes inventory form")
		_check((preview._inventory_form is FertilizerCard) if kind == "fertilizer" else (preview._inventory_form is MutationCard), kind + " uses actual inventory card")
		_check(get_viewport().gui_get_drag_data() == original and GameState.biomass.amount == 100, kind + " transition preserves original payload and balance")
		if crossing == 0:
			_check(_has_smoke(preview), kind + " boundary change emits smoke")
			await _shot(kind + "-inventory-puff")
		await _move(inside, true, 0.1)
		_check(preview._showing_shop and not preview.item_canvas_rect().has_area(), kind + " reentry restores offer")
	_check(is_equal_approx(_rect(_nursery._reroll_button).position.y, reroll_y), kind + " conversion keeps Shop layout stable")
	await _move(_rect(_nursery._stock_slots[0]).get_center(), true)
	_expect_delta(-cost, kind + " Stock purchase preview")
	await _release()
	_check(GameState.nursery.stock.get_at(0) == item and GameState.biomass.amount == 100 - cost, kind + " Stock purchase commits once")
	_check(_offer(kind) == null and NurseryItemDragPreview.current(get_viewport()) == null, kind + " purchased offer and preview cleaned up")

	var stock_card := _nursery._stock_slots[0]._card_host.get_child(0) as Control
	await _begin(stock_card)
	_check(_zone._sell_overlay != null and _zone._sell_overlay.visible, kind + " owned item exposes Sell badge")
	var badge := _zone._sell_overlay._badge
	# First leave the pointer over another offer: the whole Shop must not accept sales.
	await _move(_rect(_zone).position + Vector2(20, 20), true)
	_expect_delta(null, kind + " offer area has no sale preview")
	_check(not _zone._drop_highlight_active, kind + " offer area has no sale highlight")
	var untouched_balance := GameState.biomass.amount
	await _release()
	_check(GameState.nursery.stock.get_at(0) == item and GameState.biomass.amount == untouched_balance, kind + " drop outside Sell paper leaves item untouched")
	await _begin(stock_card)
	var overlap := _icon_only_point(_rect(badge))
	await _move(overlap, true)
	_check_icon_only(_rect(badge), kind + " Sell")
	var gain := BiomassData.sell_value(item.biomass_cost)
	_expect_delta(gain, kind + " icon-only Sell preview")
	_check(_zone._drop_highlight_active and badge.modulate != Color.WHITE, kind + " icon-only Sell highlights actual badge")
	await _shot(kind + "-sell-icon-only")
	var balance := GameState.biomass.amount
	await _release()
	_check(GameState.nursery.stock.get_at(0) == null and GameState.biomass.amount == balance + gain, kind + " icon-only Sell commits exactly once")


func _shop_direct_plot(kind: String) -> void:
	var item := await _reset(kind)
	var source := _offer(kind)
	var cost := source.cost
	await _begin(source)
	# A Shop item is still unowned even after the visible form changes.
	await _move(Vector2(500, 580), true)
	await _move(_rect(_zone).get_center(), true)
	_check(_zone._sell_overlay == null or not _zone._sell_overlay.visible, kind + " unowned Shop item cannot expose Sell")
	_expect_delta(null, kind + " unowned Shop item has no sale gain")
	await _release()
	_check(GameState.biomass.amount == 100 and _offer(kind) == source and is_equal_approx(source.modulate.a, 1.0), kind + " invalid Shop-area drop preserves and restores offer")
	await _begin(source)
	await _move(Vector2(500, 580), true)
	var tile := _nursery._tiles[0]
	await _move(_icon_only_point(_rect(tile)), true)
	_check_icon_only(_rect(tile), kind + " direct Plot")
	_expect_delta(-cost, kind + " icon-only direct Plot cost")
	_check(tile.modulate == PlotTile._DROP_HIGHLIGHT, kind + " direct Plot highlighted")
	await _shot(kind + "-plot-icon-only")
	await _release()
	_check(_applied(0, item) and not _applied(1, item) and GameState.biomass.amount == 100 - cost, kind + " direct Plot purchase applies once")
	_check(GameState.nursery.stock.get_at(0) == null and _offer(kind) == null, kind + " direct Plot bypasses Stock")


func _stock_pointer_plot_and_cancel(kind: String) -> void:
	var item := await _reset(kind, true)
	var source := _nursery._stock_slots[0]._card_host.get_child(0) as Control
	await _begin(source)
	await _move(Vector2(4, 4), true)
	await _release()
	_check(GameState.nursery.stock.get_at(0) == item and GameState.biomass.amount == 100 and source.visible, kind + " invalid drop restores Stock without spending")
	_check(NurseryItemDragPreview.current(get_viewport()) == null, kind + " cancelled preview cleaned up")
	await _begin(source)
	var tile := _nursery._tiles[0]
	var bounds := _rect(tile)
	var pointer_only := bounds.get_center()
	await _move(pointer_only, true)
	var icon := NurseryItemDragPreview.current(get_viewport()).item_canvas_rect()
	_check(bounds.has_point(_pointer()) and icon.has_area(), kind + " ordinary pointer is inside Plot")
	_check(tile.modulate == PlotTile._DROP_HIGHLIGHT, kind + " pointer-over Plot highlighted")
	_expect_delta(null, kind + " owned Plot application is free")
	await _release()
	_check(_applied(0, item) and GameState.nursery.stock.get_at(0) == null and GameState.biomass.amount == 100, kind + " pointer-over application succeeds")


func _stock_pointer_sale(kind: String) -> void:
	var item := await _reset(kind, true)
	await _begin(_nursery._stock_slots[0]._card_host.get_child(0) as Control)
	await _move(_rect(_zone._sell_overlay._badge).get_center(), true)
	var gain := BiomassData.sell_value(item.biomass_cost)
	_expect_delta(gain, kind + " ordinary pointer Sell preview")
	_check(_zone._drop_highlight_active, kind + " ordinary pointer Sell highlights badge")
	await _release()
	_check(GameState.nursery.stock.get_at(0) == null and GameState.biomass.amount == 100 + gain, kind + " ordinary pointer Sell commits once")


func _adjacent_plot() -> void:
	var item := await _reset("fertilizer", true)
	await _begin(_nursery._stock_slots[0]._card_host.get_child(0) as Control)
	var left := _rect(_nursery._tiles[0])
	var right := _rect(_nursery._tiles[1])
	var icon := NurseryItemDragPreview.current(get_viewport()).item_canvas_rect()
	var offset := icon.get_center() - _pointer()
	var position := Vector2((left.end.x + right.position.x) * 0.5, left.position.y + 12.0) - offset
	await _move(position, true)
	icon = NurseryItemDragPreview.current(get_viewport()).item_canvas_rect()
	_check(not left.has_point(_pointer()) and not right.has_point(_pointer()) and icon.intersects(left) and icon.intersects(right), "adjacent test overlaps both Plots with pointer outside")
	var first_area := left.intersection(icon).get_area()
	var second_area := right.intersection(icon).get_area()
	var expected := 0 if first_area >= second_area else 1
	_check(_nursery._tiles[expected].modulate == PlotTile._DROP_HIGHLIGHT and _nursery._tiles[1 - expected].modulate != PlotTile._DROP_HIGHLIGHT, "only largest-overlap or first tied Plot highlights")
	await _release()
	_check(_applied(expected, item) and not _applied(1 - expected, item), "adjacent overlap commits to highlighted Plot only")


func _same_event_boundary_drop() -> void:
	var item := await _reset("fertilizer")
	var source := _offer("fertilizer")
	var cost := source.cost
	await _begin(source)
	var target := _rect(_nursery._tiles[0])
	# Previously measured compact icon reaches below the pointer by about50px.
	# Cross the Shop boundary and release before yielding a process frame.
	_send_motion(Vector2(target.get_center().x, target.position.y - 36.0), true)
	await _button(false)
	await _wait(0.2)
	_check(_applied(0, item) and GameState.biomass.amount == 100 - cost, "same-event boundary crossing uses inventory footprint on release")


func _cancel_presentations() -> void:
	for action in ["pause", "tab"]:
		await _reset("fertilizer")
		var source := _offer("fertilizer")
		await _begin(source)
		await _move(Vector2(500, 580), true, 0.1)
		var preview := NurseryItemDragPreview.current(get_viewport())
		var preview_ref: WeakRef = weakref(preview)
		if action == "pause":
			(_base.get_node("RunMenu") as RunMenu).open_menu()
		else:
			_base._select_tab(_base.TabId.COLONY, true)
		await _wait(0.2)
		_check(not get_viewport().gui_is_dragging() and NurseryItemDragPreview.current(get_viewport()) == null and preview_ref.get_ref() == null, action + " cancels owned preview and smoke")
		_check(GameState.biomass.amount == 100 and _offer("fertilizer") == source and is_equal_approx(source.modulate.a, 1.0), action + " restores offer without spending")
		if action == "pause":
			(_base.get_node("RunMenu") as RunMenu).close_menu()
		else:
			_base._select_tab(_base.TabId.NURSERY, true)
		await _wait(0.2)


func _offer(kind: String) -> ShopOfferCard:
	for card: ShopOfferCard in _nursery._shop_cards:
		if card.slot_index == (0 if kind == "fertilizer" else 2):
			return card
	return null


func _applied(index: int, item: Resource) -> bool:
	var plot: NurseryPlotData = GameState.nursery.plots[index]
	if item is FertilizerData:
		return plot.applied_fertilizers.count(item) == 1
	return plot.filled_mutation() == item


func _icon_only_point(target: Rect2) -> Vector2:
	var icon := NurseryItemDragPreview.current(get_viewport()).item_canvas_rect()
	var pointer := _pointer()
	return Vector2(target.get_center().x - (icon.get_center().x - pointer.x), target.position.y + 8.0 - (icon.end.y - pointer.y))


func _check_icon_only(target: Rect2, label: String) -> void:
	var icon := NurseryItemDragPreview.current(get_viewport()).item_canvas_rect()
	_check(not target.has_point(_pointer()) and target.intersects(icon), label + " pointer outside but painted icon overlaps")
	print("ICON_ONLY ", label, " pointer=", _pointer(), " icon=", icon, " target=", target)


func _has_smoke(preview: Control) -> bool:
	for child in preview.get_children():
		if child is SporeCloud:
			return true
	return false


func _expect_delta(expected: Variant, label: String) -> void:
	var actual: Variant = _biomass._last_preview.get("delta")
	_check(actual == expected, label + " expected=" + str(expected) + " actual=" + str(actual))


func _begin(source: Control) -> void:
	await _move(_rect(source).get_center())
	await _button(true)
	await _move(_pointer() + Vector2(48, 0), true)
	_check(get_viewport().gui_is_dragging(), "native pointer begins drag")


func _release() -> void:
	await _button(false)
	await _wait(0.2)


func _button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = get_viewport().get_final_transform() * _pointer()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	await get_tree().process_frame


func _move(point: Vector2, dragging: bool = false, seconds: float = 0.2) -> void:
	_send_motion(point, dragging)
	await _wait(seconds)


func _send_motion(point: Vector2, dragging: bool) -> void:
	get_viewport().warp_mouse(point)
	var event := InputEventMouseMotion.new()
	event.position = get_viewport().get_final_transform() * point
	event.global_position = event.position
	event.relative = Vector2(48, 0)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if dragging else 0
	Input.parse_input_event(event)


func _pointer() -> Vector2:
	return get_viewport().get_mouse_position()


func _rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--visual"):
		return
	await RenderingServer.frame_post_draw
	var path := "/tmp/nursery-item-drag-%s.png" % label
	get_viewport().get_texture().get_image().save_png(path)
	print("NURSERY_DRAG_SCREENSHOT ", path)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("PASS " if ok else "FAIL ", label)
