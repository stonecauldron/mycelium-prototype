class_name CombatBarks
extends Node2D

@export_range(0.0, 1.0) var kill_chance: float = 0.2
@export_range(0.0, 1.0) var mourning_chance: float = 0.5

@onready var _bubble: BarkBubble = $BarkBubble
@onready var _cooldown: Timer = $ReactionCooldown

var _troop: Troop = null
var _opening_pending: bool = false
var _victory_pending: bool = false
var _enabled: bool = true
var _active: bool = false
var _is_reaction: bool = false
var _pending_killers: Array[Unit] = []
var _pending_fallen: Array[String] = []


func _ready() -> void:
	_bubble.dismissed.connect(_on_bubble_dismissed)


func begin_battle(troop: Troop) -> void:
	end_battle()
	_troop = troop
	_active = true
	_opening_pending = _enabled


func set_speed(speed: int) -> void:
	_enabled = speed == 1
	if not _enabled:
		_opening_pending = false
		_victory_pending = false
		_pending_killers.clear()
		_pending_fallen.clear()
		_bubble.dismiss()


func enemy_killed(killer: Unit) -> void:
	if _can_react():
		_pending_killers.append(killer)


func friendly_died(roster: RosterUnitData) -> void:
	if roster != null and _can_react():
		_pending_fallen.append(roster.display_name)


func end_battle() -> void:
	_active = false
	_opening_pending = false
	_victory_pending = false
	_pending_killers.clear()
	_pending_fallen.clear()
	_is_reaction = false
	_bubble.dismiss()
	_cooldown.stop()


func celebrate_victory() -> void:
	end_battle()
	_victory_pending = _enabled


func _process(_delta: float) -> void:
	if _victory_pending:
		_victory_pending = false
		var speaker := _choose_survivor()
		if speaker != null:
			_show_line(BarkData.Kind.VICTORY, speaker)
		return
	if _opening_pending:
		_opening_pending = false
		if _troop.has_flag_bearer():
			_show_line(BarkData.Kind.OPENING, _troop.flag_bearer)
		return
	var killers := _pending_killers.duplicate()
	var fallen_names := _pending_fallen.duplicate()
	_pending_killers.clear()
	_pending_fallen.clear()
	if not _can_react():
		return
	# All synchronous death effects have settled. Mourning takes priority over
	# kills from the same frame; neither becomes a backlog of delayed dialogue.
	if not fallen_names.is_empty():
		for fallen_name: String in fallen_names:
			if GameState.barks.rng.randf() < mourning_chance:
				var speaker := _choose_survivor()
				if speaker != null:
					_show_line(BarkData.Kind.MOURNING, speaker, fallen_name)
				return
		return
	for killer: Unit in killers:
		if is_instance_valid(killer) and _bubble.can_show(killer) and GameState.barks.rng.randf() < kill_chance:
			_show_line(BarkData.Kind.KILL, killer)
			return


func _can_react() -> bool:
	return _active and _enabled and not _opening_pending and not _bubble.visible and _cooldown.is_stopped()


func _choose_survivor() -> Unit:
	var candidates: Array[Unit] = []
	var alternatives: Array[Unit] = []
	for unit in _troop.get_living_units():
		if unit.roster_data == null or not _bubble.can_show(unit):
			continue
		candidates.append(unit)
		if unit.roster_data != GameState.barks.last_reaction_speaker:
			alternatives.append(unit)
	if not alternatives.is_empty():
		candidates = alternatives
	if candidates.is_empty():
		return null
	return candidates[GameState.barks.rng.randi_range(0, candidates.size() - 1)]


func _show_line(kind: BarkData.Kind, speaker: Node2D, fallen_name: String = "") -> bool:
	if not _enabled:
		return false
	var speaker_name := "Flag bearer"
	if speaker is Unit:
		speaker_name = speaker.roster_data.display_name
	var line := GameState.barks.line_for(kind).replace("{fallen_name}", fallen_name)
	var duration := 2.0 if kind == BarkData.Kind.VICTORY else 3.0
	if not _bubble.present(speaker, speaker_name, line, duration):
		return false
	GameState.barks.mark_shown(kind)
	if kind in [BarkData.Kind.MOURNING, BarkData.Kind.VICTORY]:
		GameState.barks.last_reaction_speaker = (speaker as Unit).roster_data
	_is_reaction = kind in [BarkData.Kind.KILL, BarkData.Kind.MOURNING]
	return true


func _on_bubble_dismissed() -> void:
	if _is_reaction:
		_is_reaction = false
		_cooldown.start(3.0)
