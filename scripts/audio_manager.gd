extends Node
## Centralized SFX playback. Replace files in SFX_PATHS with your final audio assets.

const SFX_PATHS := {
	"ui_select": "res://assets/audio/sfx/ui_select.wav",
	"ui_confirm": "res://assets/audio/sfx/ui_confirm.wav",
	"ui_back": "res://assets/audio/sfx/ui_back.wav",
	"player_attack": "res://assets/audio/sfx/player_attack.wav",
	"enemy_hit": "res://assets/audio/sfx/enemy_hit.wav",
	"player_hurt": "res://assets/audio/sfx/player_hurt.wav",
	"player_death": "res://assets/audio/sfx/player_death.wav",
	"skill_cast": "res://assets/audio/sfx/skill_cast.wav",
	"level_up": "res://assets/audio/sfx/level_up.wav",
	"pickup_xp": "res://assets/audio/sfx/pickup_xp.wav",
	"pickup_gold": "res://assets/audio/sfx/pickup_gold.wav",
	"pinball_launch": "res://assets/audio/sfx/pinball_launch.wav",
	"pinball_bounce": "res://assets/audio/sfx/pinball_bounce.wav",
	"reward": "res://assets/audio/sfx/reward.wav",
}

const VOLUME_DB := {
	"ui_select": -10.0,
	"ui_confirm": -8.0,
	"ui_back": -10.0,
	"player_attack": -12.0,
	"enemy_hit": -13.0,
	"player_hurt": -8.0,
	"player_death": -6.0,
	"skill_cast": -8.0,
	"level_up": -7.0,
	"pickup_xp": -16.0,
	"pickup_gold": -11.0,
	"pinball_launch": -8.0,
	"pinball_bounce": -17.0,
	"reward": -7.0,
}

const MIN_INTERVAL_SEC := {
	"player_attack": 0.08,
	"enemy_hit": 0.035,
	"level_up": 0.12,
	"pickup_xp": 0.045,
	"pinball_bounce": 0.025,
	"reward": 0.12,
}

const POOL_SIZE := 16

var sfx_enabled: bool = true
var master_volume_db: float = 0.0

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _last_played: Dictionary = {}
var _missing_warned: Dictionary = {}
var _next_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for _i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)


func play_sfx(id: String, pitch_variation: float = 0.04, volume_offset_db: float = 0.0) -> void:
	if not sfx_enabled:
		return
	if not SFX_PATHS.has(id):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var min_interval: float = float(MIN_INTERVAL_SEC.get(id, 0.0))
	if now - float(_last_played.get(id, -999.0)) < min_interval:
		return
	var stream: AudioStream = _stream_for(id)
	if stream == null:
		return
	_last_played[id] = now
	var player: AudioStreamPlayer = _next_player()
	player.stop()
	player.stream = stream
	player.volume_db = float(VOLUME_DB.get(id, -10.0)) + master_volume_db + volume_offset_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func replacement_paths() -> Dictionary:
	return SFX_PATHS.duplicate()


func _stream_for(id: String) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var path: String = String(SFX_PATHS[id])
	if not ResourceLoader.exists(path):
		if not _missing_warned.has(id):
			push_warning("[AudioManager] Missing SFX: %s -> %s" % [id, path])
			_missing_warned[id] = true
		return null
	var stream: AudioStream = load(path)
	if stream != null:
		_cache[id] = stream
	return stream


func _next_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	var player: AudioStreamPlayer = _players[_next_index]
	_next_index = (_next_index + 1) % _players.size()
	return player
