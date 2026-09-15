extends Node

## Persistent, non-positional playback. SettingsServer owns the bus volumes.

const _SFX_VOICES := 16
const _UI_VOICES := 4
const _DEFAULT_PITCH_VARIATION := 0.1
const _MUSIC_TRANSITION_SECONDS := 0.5
const _BACKGROUND_MUSIC_VOLUME := 0.2

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
var _battle_music_started: bool = false
var _music_fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pitch_rng.randomize()
	_base_player.bus = &"Music"
	_battle_player.bus = &"Music"
	# Native loop points are used where available; other stream types repeat here.
	_base_player.finished.connect(_base_player.play)
	_battle_player.finished.connect(_battle_player.play)


func play_base_music() -> AudioStreamPlayer:
	return _play_music(_base_player)


## Restart for a new combat; result screens keep the current playback position.
func play_battle_music(restart: bool = false) -> AudioStreamPlayer:
	_battle_music_started = true
	if restart:
		_battle_player.stop()
	return _play_music(_battle_player)


func stop_music() -> void:
	if _current_music == null:
		return
	_current_music = null
	_fade_music()


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
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	if not is_finite(pitch_variation):
		pitch_variation = _DEFAULT_PITCH_VARIATION
	var variation := clampf(pitch_variation, 0.0, 0.99)
	player.pitch_scale = _pitch_rng.randf_range(1.0 - variation, 1.0 + variation)
	player.play()
	return player


func _play_music(foreground: AudioStreamPlayer) -> AudioStreamPlayer:
	var changed := _ensure_music_player(_base_player, base_music)
	if _battle_music_started:
		changed = _ensure_music_player(_battle_player, battle_music) or changed
	if _current_music != foreground or changed:
		_current_music = foreground
		_fade_music()
	return foreground if foreground.stream != null else null


func _ensure_music_player(player: AudioStreamPlayer, stream: AudioStream) -> bool:
	if stream == null:
		var changed := player.stream != null
		player.stop()
		player.stream = null
		_music_sources.erase(player)
		return changed
	if _music_sources.get(player) == stream and player.playing:
		return false
	player.stop()
	player.stream = _looping_music(stream)
	player.volume_linear = 0.0
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


func _fade_music() -> void:
	if _music_fade != null:
		_music_fade.kill()
	_music_fade = create_tween().set_parallel(true)
	_music_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_fade.set_ignore_time_scale(true)
	for player in [_base_player, _battle_player]:
		var volume := 0.0
		if _current_music != null and player.playing:
			if player == _current_music:
				volume = 1.0
			elif player == _base_player:
				volume = _BACKGROUND_MUSIC_VOLUME
		_music_fade.tween_property(player, "volume_linear", volume, _MUSIC_TRANSITION_SECONDS)
	if _current_music == null:
		_music_fade.chain().tween_callback(_finish_music_stop)


func _finish_music_stop() -> void:
	for player in [_base_player, _battle_player]:
		player.stop()
		player.stream = null
	_music_sources.clear()
	_battle_music_started = false
