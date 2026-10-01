extends Node

## Persistent, non-positional playback. SettingsServer owns the bus volumes.

const _SFX_VOICES := 16
const _UI_VOICES := 4
const _DEFAULT_PITCH_VARIATION := 0.1
const _MUSIC_FADE_SECONDS := 0.5
const _BATTLE_CROSSFADE_SECONDS := 2.0
const _BASE_CROSSFADE_SECONDS := 8.0
const _BATTLE_VOLUME_DB := -7.0
const _REVEAL_MUSIC_GAIN := 0.07
const _REVEAL_DUCK_SECONDS := 0.18
const _REVEAL_RECOVER_SECONDS := 0.26

@export var base_music: AudioStream
@export var battle_music: AudioStream

@onready var _base_player: AudioStreamPlayer = %MusicA
@onready var _battle_player: AudioStreamPlayer = %MusicB

var _gameplay_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _gameplay_scene: Node
var _pitch_rng := RandomNumberGenerator.new()
var _current_music: AudioStreamPlayer
var _music_sources: Dictionary[AudioStreamPlayer, AudioStream] = {}
var _music_fade: Tween
var _music_levels: Dictionary[AudioStreamPlayer, float] = {}
var _reveal_music_gain: float = 1.0
var _reveal_music_fade: Tween
var _reveal_audio_leases: int = 0
var _last_gameplay_cues: Dictionary[Sfx.Cue, int] = {}
var _last_ui_cues: Dictionary[Sfx.Cue, int] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pitch_rng.randomize()
	_base_player.bus = &"Music"
	_battle_player.bus = &"Music"
	# Native loop points are used where available; other stream types repeat here.
	_base_player.finished.connect(_base_player.play)
	_battle_player.finished.connect(_battle_player.play)
	get_tree().node_added.connect(_wire_ui_control)
	for control in get_tree().root.find_children("*", "Control", true, false):
		_wire_ui_control(control)


func play_cue(cue: Sfx.Cue) -> AudioStreamPlayer:
	if get_tree().paused or not _allow_cue(cue, _last_gameplay_cues):
		return null
	var sound: Dictionary = Sfx.SOUNDS[cue]
	return play_sfx(sound.stream, sound.gain_db, sound.pitch_variation)


func play_ui_cue(cue: Sfx.Cue) -> AudioStreamPlayer:
	if not _allow_cue(cue, _last_ui_cues):
		return null
	var sound: Dictionary = Sfx.SOUNDS[cue]
	return play_ui_sfx(sound.stream, sound.gain_db, sound.pitch_variation)


## Dedicated playback: freeing the owner or returned player cancels only this cue.
func play_owned_ui_cue(owner_node: Node, cue: Sfx.Cue) -> AudioStreamPlayer:
	if not is_instance_valid(owner_node) or not owner_node.is_inside_tree():
		return null
	if not _allow_cue(cue, _last_ui_cues):
		return null
	var sound: Dictionary = Sfx.SOUNDS[cue]
	var player := AudioStreamPlayer.new()
	player.bus = &"SFX"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	owner_node.add_child(player)
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	_start_effect(player, sound.stream, sound.gain_db, sound.pitch_variation)
	return player


## Acquire 0.18s before release; free 0.24s after it for the reference mix timing.
## Owner exit also releases the duck. Settings and track crossfades stay independent.
func acquire_reveal_audio(owner_node: Node) -> Node:
	if not is_instance_valid(owner_node) or not owner_node.is_inside_tree():
		return null
	var lease := Node.new()
	lease.name = "RevealAudioLease"
	lease.tree_exiting.connect(_release_reveal_audio, CONNECT_ONE_SHOT)
	owner_node.add_child(lease)
	_reveal_audio_leases += 1
	if _reveal_audio_leases == 1:
		_fade_reveal_music(_REVEAL_MUSIC_GAIN, _REVEAL_DUCK_SECONDS)
	return lease


func _release_reveal_audio() -> void:
	_reveal_audio_leases -= 1
	if _reveal_audio_leases == 0:
		_fade_reveal_music(1.0, _REVEAL_RECOVER_SECONDS)


func _fade_reveal_music(gain: float, seconds: float) -> void:
	if _reveal_music_fade != null:
		_reveal_music_fade.kill()
	if not is_inside_tree():
		_set_reveal_music_gain(gain)
		return
	_reveal_music_fade = create_tween()
	_reveal_music_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_reveal_music_fade.set_ignore_time_scale(true)
	_reveal_music_fade.tween_method(_set_reveal_music_gain, _reveal_music_gain, gain, seconds)


func _set_reveal_music_gain(gain: float) -> void:
	_reveal_music_gain = gain
	for player in _music_levels:
		if is_instance_valid(player):
			player.volume_linear = _music_levels[player] * gain


func _set_music_level(level: float, player: AudioStreamPlayer) -> void:
	_music_levels[player] = level
	player.volume_linear = level * _reveal_music_gain


func _allow_cue(cue: Sfx.Cue, last_played: Dictionary[Sfx.Cue, int]) -> bool:
	if not Sfx.SOUNDS.has(cue):
		return false
	var now := Time.get_ticks_msec()
	var spacing: int = Sfx.SOUNDS[cue].cooldown_ms
	if now - last_played.get(cue, -spacing) < spacing:
		return false
	last_played[cue] = now
	return true


func _wire_ui_control(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		var on_pressed := _on_button_pressed.bind(button)
		if button.pressed.is_connected(on_pressed):
			return
		button.pressed.connect(on_pressed)
		button.mouse_entered.connect(_on_button_hovered.bind(button))
		button.focus_entered.connect(_on_button_hovered.bind(button))
	elif node is Slider:
		var slider := node as Slider
		var on_changed := _on_slider_changed.bind(slider)
		if not slider.value_changed.is_connected(on_changed):
			slider.value_changed.connect(on_changed)


func _on_button_pressed(button: BaseButton) -> void:
	if bool(button.get_meta("silent_press_sfx", false)):
		return
	if button.is_visible_in_tree() and button.can_process() and not button.disabled:
		play_ui_cue(Sfx.Cue.UI_TOGGLE if button.toggle_mode else Sfx.Cue.UI_CLICK)


func _on_button_hovered(button: BaseButton) -> void:
	if button.is_visible_in_tree() and button.can_process() and not button.disabled:
		play_ui_cue(Sfx.Cue.UI_HOVER)


func _on_slider_changed(_value: float, slider: Slider) -> void:
	if slider.is_visible_in_tree() and slider.can_process() and slider.has_focus():
		play_ui_cue(Sfx.Cue.UI_TICK)


## New Runs restart with a short fade-in; returning to Base resumes with a crossfade.
func play_base_music(restart: bool = false) -> AudioStreamPlayer:
	var seconds := _MUSIC_FADE_SECONDS if restart else _BASE_CROSSFADE_SECONDS
	return _play_music(_base_player, base_music, seconds, restart)


## Restart for a new combat, including rematches in the same scene.
func play_battle_music(restart: bool = false) -> AudioStreamPlayer:
	return _play_music(_battle_player, battle_music, _BATTLE_CROSSFADE_SECONDS, restart)


func stop_music() -> void:
	if _current_music == null:
		return
	_current_music = null
	_fade_music(_MUSIC_FADE_SECONDS)


## Returned players are pooled; do not retain them across later playback calls.
## Pitch variation is a fraction of normal pitch; zero disables randomization.
func play_sfx(
	stream: AudioStream,
	volume_db: float = 0.0,
	pitch_variation: float = _DEFAULT_PITCH_VARIATION
) -> AudioStreamPlayer:
	if stream == null or get_tree().paused:
		return null
	var scene := get_tree().current_scene
	if scene != null and _gameplay_scene != scene:
		_gameplay_scene = scene
		scene.tree_exiting.connect(stop_gameplay_sfx, CONNECT_ONE_SHOT)
	return _play_effect(stream, volume_db, pitch_variation, _gameplay_players, _SFX_VOICES, Node.PROCESS_MODE_PAUSABLE)


func play_ui_sfx(
	stream: AudioStream,
	volume_db: float = 0.0,
	pitch_variation: float = _DEFAULT_PITCH_VARIATION
) -> AudioStreamPlayer:
	return _play_effect(stream, volume_db, pitch_variation, _ui_players, _UI_VOICES, Node.PROCESS_MODE_ALWAYS)


func stop_gameplay_sfx() -> void:
	_last_gameplay_cues.clear()
	for player in _gameplay_players:
		player.stop()
		player.stream = null


func _play_effect(
	stream: AudioStream,
	volume_db: float,
	pitch_variation: float,
	players: Array[AudioStreamPlayer],
	limit: int,
	mode: ProcessMode
) -> AudioStreamPlayer:
	if stream == null:
		return null
	var player: AudioStreamPlayer
	for candidate in players:
		if not candidate.has_stream_playback():
			player = candidate
			players.erase(candidate)
			break
	if player == null:
		if players.size() < limit:
			player = AudioStreamPlayer.new()
			player.bus = &"SFX"
			player.process_mode = mode
			add_child(player)
		else:
			# Recycle the oldest voice when a burst fills this pool.
			player = players.pop_front()
	players.append(player)
	_start_effect(player, stream, volume_db, pitch_variation)
	return player


func _start_effect(player: AudioStreamPlayer, stream: AudioStream, volume_db: float, pitch_variation: float) -> void:
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	if not is_finite(pitch_variation):
		pitch_variation = _DEFAULT_PITCH_VARIATION
	var variation := clampf(pitch_variation, 0.0, 0.99)
	player.pitch_scale = _pitch_rng.randf_range(1.0 - variation, 1.0 + variation)
	player.play()


func _play_music(
	player: AudioStreamPlayer,
	stream: AudioStream,
	seconds: float,
	restart: bool = false
) -> AudioStreamPlayer:
	var initial := not _base_player.has_stream_playback() and not _battle_player.has_stream_playback()
	if restart:
		player.stop()
	var changed := _ensure_music_player(player, stream)
	if _current_music != player or changed:
		_current_music = player
		_fade_music(_MUSIC_FADE_SECONDS if initial else seconds)
	return player if player.stream != null else null


func _ensure_music_player(player: AudioStreamPlayer, stream: AudioStream) -> bool:
	if stream == null:
		var changed := player.stream != null
		player.stop()
		player.stream = null
		_music_sources.erase(player)
		return changed
	if _music_sources.get(player) == stream and player.has_stream_playback():
		var was_paused := player.stream_paused
		player.stream_paused = false
		return was_paused
	player.stop()
	player.stream = _looping_music(stream)
	_set_music_level(0.0, player)
	player.stream_paused = false
	player.play()
	_music_sources[player] = stream
	return true


func _looping_music(stream: AudioStream) -> AudioStream:
	# Preserve shared SFX resources and any authored loop offsets.
	var looped := stream.duplicate() as AudioStream
	if looped is AudioStreamOggVorbis:
		(looped as AudioStreamOggVorbis).loop = true
	elif looped is AudioStreamMP3:
		(looped as AudioStreamMP3).loop = true
	elif looped is AudioStreamWAV:
		var wav := looped as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = roundi(wav.get_length() * wav.mix_rate)
	return looped


func _fade_music(seconds: float) -> void:
	if _music_fade != null:
		_music_fade.kill()
	_music_fade = create_tween().set_parallel(true)
	_music_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_fade.set_ignore_time_scale(true)
	for player in [_base_player, _battle_player]:
		var volume := 0.0
		if player == _current_music and player.has_stream_playback():
			volume = db_to_linear(_BATTLE_VOLUME_DB) if player == _battle_player else 1.0
		_music_fade.tween_method(_set_music_level.bind(player),
			_music_levels.get(player, player.volume_linear), volume, seconds)
	if _current_music == null:
		_music_fade.chain().tween_callback(_finish_music_stop)
	else:
		_music_fade.chain().tween_callback(_pause_outgoing_music)


func _pause_outgoing_music() -> void:
	for player in [_base_player, _battle_player]:
		if player != _current_music:
			player.stream_paused = true


func _finish_music_stop() -> void:
	for player in [_base_player, _battle_player]:
		player.stop()
		player.stream = null
	_music_sources.clear()
