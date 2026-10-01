extends "res://.scratch/shared-usability/elite_preview_checks.gd"

class BlankTooltipTarget extends Button:
	func _make_custom_tooltip(_for_text: String) -> Object:
		return DetailTooltipPopup.configure(null)


func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Analytics.ga = null
	GameState.reset_run()
	GameState.current_day = 2
	GameState.pending_seal_choice = false
	GameState.troop.seed_if_empty(StarterPackages.build_units(&"great_sword_spear"))
	GameState.biomass.amount = 100
	base = preload("res://assets/base/base.tscn").instantiate()
	get_tree().root.add_child(base)
	get_tree().current_scene = base
	colony = base.get_node("%ColonyScreen") as TroopSelectionScreen
	scout = colony.get_node("ScoutBubble") as ScoutBubble
	track = colony.get_node("HeaderBlock/CombatProgressTrack") as CombatProgressTrack
	await _settle()
	await _move(Vector2(4, 4))
	var undo := base.get_node("%UndoButton") as Button
	_check(undo.disabled, "initial Undo is disabled")
	await _hover(undo)
	_check_plain(undo.tooltip_text, "disabled Undo")
	await _snapshot("default-disabled-undo")

	var nursery := base.get_node("%NurseryScreen") as NurseryScreen
	base._select_tab(base.TabId.NURSERY, true)
	await _settle()
	nursery._shop_cards[0].lock_toggled.emit(nursery._shop_cards[0])
	await _move(Vector2(4, 4))
	await _hover(undo)
	_check(not undo.disabled and "Lock Offer" in undo.tooltip_text, "real reversible action enables Undo")
	_check_plain(undo.tooltip_text, "enabled Undo")
	await _snapshot("default-enabled-undo")
	await _hover(nursery._shop_cards[0]._lock_icon)
	_check_plain("Unlock", "short unlock")
	await _snapshot("default-unlock")

	var menu := base.get_node("RunMenu") as RunMenu
	menu.open_menu()
	(menu.get_node("%SettingsButton") as Button).pressed.emit()
	await _settle()
	var slider := menu.get_node("%SFXVolume") as HSlider
	await _hover(slider)
	_check(get_tree().paused, "settings tooltip is exercised while paused")
	_check_plain(slider.tooltip_text, "paused slider")
	await _snapshot("default-paused-slider")
	menu.close_menu()
	base._select_tab(base.TabId.COLONY, true)
	await _move(Vector2(4, 4))

	await _hover(track.get_node("Node4") as Control)
	_check_rich("Day")
	await _snapshot("default-rich-day")
	await _move(Vector2(4, 4))
	_check(DetailTooltipPopup._instance._tip == null and _visible_popups().is_empty(), "rich Day tooltip and native wrapper dismiss together")
	var enemy := scout.get_node("%ScoutRow").get_child(0) as ScoutEnemyEntry
	await _hover(enemy.get_node("%PortraitHost") as Control)
	_check_rich("Scout")
	await _snapshot("default-rich-scout")
	await _move(Vector2(4, 4))
	_check(DetailTooltipPopup._instance._tip == null and _visible_popups().is_empty(), "rich Scout tooltip dismisses normally")
	await _blank_placeholder()
	print("DEFAULT_TOOLTIP_CHECKS failures=", failures)
	get_tree().quit(failures)


func _check_plain(text: String, context: String) -> void:
	var matched := false
	for popup in _visible_popups():
		for node in popup.find_children("*", "Label", true, false):
			var label := node as Label
			if label.text != text:
				continue
			matched = true
			var style := popup.get_theme_stylebox("panel") as StyleBoxTexture
			_check(style != null and style.resource_path == "res://assets/themes/paper/paper_text_tooltip.tres", context + " uses shared native paper style")
			_check(label.get_theme_font_size("font_size") == 22
				and label.get_theme_color("font_color").is_equal_approx(Color(0.18, 0.16, 0.14)), context + " uses readable native text style")
			_check(label.position.x >= 23 and label.position.y >= 17
				and popup.size.x - label.position.x - label.size.x >= 39
				and popup.size.y - label.position.y - label.size.y >= 13, context + " text respects paper padding")
			print("NATIVE_TOOLTIP ", context, " popup=", popup.position, "/", popup.size,
				" label=", label.position, "/", label.size, " text=", label.text)
	_check(matched, context + " actually creates visible native tooltip text")


func _check_rich(context: String) -> void:
	var overlay := DetailTooltipPopup._instance
	_check(is_instance_valid(overlay) and is_instance_valid(overlay._tip)
		and overlay._tip.is_visible_in_tree() and overlay._tip.modulate.a > 0.9, context + " rich paper card is visible")
	var popups := _visible_popups()
	_check(popups.size() == 1, context + " has one native hover wrapper")
	for popup in popups:
		_check(popup.get_theme_stylebox("panel") is StyleBoxEmpty, context + " engine wrapper is transparent, not duplicate paper")


func _blank_placeholder() -> void:
	var hud := base.get_node("HudLayer/HudRoot") as Control
	var target := BlankTooltipTarget.new()
	target.position = Vector2(700, 850)
	target.size = Vector2(120, 50)
	target.text = "Placeholder"
	target.tooltip_text = "Blank"
	hud.add_child(target)
	# Independent overlay ownership survives the null native placeholder's lifetime.
	var card := PanelContainer.new()
	PaperStyles.apply_tooltip(card)
	var label := Label.new()
	label.text = "Existing overlay"
	card.add_child(label)
	var owner_lease := DetailTooltipPopup.configure(card)
	hud.add_child(owner_lease)
	await _hover(target)
	_check(DetailTooltipPopup._instance._tip == card, "configure(null) preserves an existing rich overlay")
	var popups := _visible_popups()
	_check(popups.size() == 1, "null placeholder uses the real native tooltip wrapper")
	for popup in popups:
		_check(popup.get_theme_stylebox("panel") is StyleBoxEmpty, "null placeholder has no paper background")
	await _move(Vector2(4, 4))
	_check(DetailTooltipPopup._instance._tip == card, "null placeholder exit cannot dismiss another lease's overlay")
	owner_lease.queue_free()
	target.queue_free()
	await _settle()
	_check(DetailTooltipPopup._instance._tip == null, "original lease still owns overlay dismissal")


func _visible_popups() -> Array[PopupPanel]:
	var popups: Array[PopupPanel] = []
	_collect_popups(get_tree().root, popups)
	return popups


func _collect_popups(node: Node, popups: Array[PopupPanel]) -> void:
	if node is PopupPanel and (node as PopupPanel).visible:
		popups.append(node as PopupPanel)
	for child in node.get_children(true):
		_collect_popups(child, popups)
