extends Node

## Persistent, non-positional playback. SettingsServer owns the bus volumes.

const _SFX_VOICES := 16
const _UI_VOICES := 4
const _CROSSFADE_SECONDS := 0.5

@export var base_music: AudioStream
@export var battle_music: AudioStream

@onready var _music_a: AudioStreamPlayer = %MusicA
@onready var _music_b: AudioStreamPlayer = %MusicB

var _gameplay_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _gameplay_scene: Node
var _current_music: AudioStreamPlayer
var _current_track: AudioStream
var _music_fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Native loop points are used where available; other stream types repeat here.
	_music_a.finished.connect(_music_a.play)
	_music_b.finished.connect(_music_b.play)


func play_base_music() -> AudioStreamPlayer:
	return _play_music(base_music)


func play_battle_music() -> AudioStreamPlayer:
	return _play_music(battle_music)


func stop_music() -> void:
	_current_music = null
	_current_track = null
	_fade_music()


## Returned players are pooled; do not retain them across later playback calls.
func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> AudioStreamPlayer:
	if stream == null or get_tree().paused:
		return null
	var scene := get_tree().current_scene
	if scene != null and _gameplay_scene != scene:
		_gameplay_scene = scene
		scene.tree_exiting.connect(stop_gameplay_sfx, CONNECT_ONE_SHOT)
	return _play_effect(stream, volume_db, _gameplay_players, _SFX_VOICES, Node.PROCESS_MODE_PAUSABLE)


func play_ui_sfx(stream: AudioStream, volume_db: float = 0.0) -> AudioStreamPlayer:
	return _play_effect(stream, volume_db, _ui_players, _UI_VOICES, Node.PROCESS_MODE_ALWAYS)


func stop_gameplay_sfx() -> void:
	for player in _gameplay_players:
		player.stop()
		player.stream = null


func _play_effect(
	stream: AudioStream,
	volume_db: float,
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
	player.play()
	return player


func _play_music(stream: AudioStream) -> AudioStreamPlayer:
	if stream == null:
		stop_music()
		return null
	if _current_track == stream and _current_music != null and _current_music.playing:
		return _current_music
	var incoming := _music_b if _current_music == _music_a else _music_a
	incoming.stop()
	incoming.stream = _looping_music(stream)
	incoming.volume_linear = 0.0
	incoming.play()
	_current_music = incoming
	_current_track = stream
	_fade_music()
	return incoming


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
	for player in [_music_a, _music_b]:
		_music_fade.tween_property(player, "volume_linear", 1.0 if player == _current_music else 0.0, _CROSSFADE_SECONDS)
	_music_fade.chain().tween_callback(_finish_music_fade)


func _finish_music_fade() -> void:
	for player in [_music_a, _music_b]:
		if player != _current_music:
			player.stop()
			player.stream = null
