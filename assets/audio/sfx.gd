class_name Sfx
extends RefCounted

## Authored cue gain and real-time spacing keep crowded battles readable.

enum Cue {
	UI_HOVER,
	UI_CLICK,
	UI_TOGGLE,
	UI_TICK,
	UI_OPEN,
	UI_CLOSE,
	UI_ERROR,
	SELECT,
	MOVE,
	PURCHASE,
	SELL,
	REROLL,
	LOCK,
	UNLOCK,
	PLANT,
	FERTILIZE,
	MUTATE,
	HARVEST,
	TRAIN,
	COMPOST,
	SEAL,
	SLASH,
	HEAVY_SWING,
	BOW,
	THROW,
	HORN,
	CHARGE,
	HIT_SLASH,
	HIT_BLUNT,
	BLOCK,
	DEATH,
	GROUND,
	EXPLOSION,
	SPORE,
	REVIVE,
	ACID_RAIN,
	BATTLE_START,
	BATTLE_WIN,
	RUN_WIN,
	RUN_LOSS,
	# Append only: projectile scenes serialize the existing cue IDs.
	GREAT_SLASH,
	GREAT_SWING,
	GREAT_BOW,
	GREAT_THROW,
	GREAT_HIT_SLASH,
	GREAT_HIT_BLUNT,
	GREAT_BLOCK,
}

const SOUNDS: Dictionary = {
	Cue.UI_HOVER: {
		"stream": preload("res://assets/audio/sfx/ui_hover.wav"),
		"gain_db": -24.0, "cooldown_ms": 80, "pitch_variation": 0.1,
	},
	Cue.UI_CLICK: {
		"stream": preload("res://assets/audio/sfx/ui_click.wav"),
		"gain_db": -15.0, "cooldown_ms": 50, "pitch_variation": 0.1,
	},
	Cue.UI_TOGGLE: {
		"stream": preload("res://assets/audio/sfx/ui_toggle.wav"),
		"gain_db": -15.0, "cooldown_ms": 70, "pitch_variation": 0.1,
	},
	Cue.UI_TICK: {
		"stream": preload("res://assets/audio/sfx/ui_tick.wav"),
		"gain_db": -23.0, "cooldown_ms": 70, "pitch_variation": 0.1,
	},
	Cue.UI_OPEN: {
		"stream": preload("res://assets/audio/sfx/ui_open.wav"),
		"gain_db": -13.0, "cooldown_ms": 100, "pitch_variation": 0.1,
	},
	Cue.UI_CLOSE: {
		"stream": preload("res://assets/audio/sfx/ui_close.wav"),
		"gain_db": -13.0, "cooldown_ms": 100, "pitch_variation": 0.1,
	},
	Cue.UI_ERROR: {
		"stream": preload("res://assets/audio/sfx/ui_error.wav"),
		"gain_db": -10.0, "cooldown_ms": 250, "pitch_variation": 0.1,
	},
	Cue.SELECT: {
		"stream": preload("res://assets/audio/sfx/select.wav"),
		"gain_db": -12.0, "cooldown_ms": 100, "pitch_variation": 0.1,
	},
	Cue.MOVE: {
		"stream": preload("res://assets/audio/sfx/move.wav"),
		"gain_db": -12.0, "cooldown_ms": 100, "pitch_variation": 0.1,
	},
	Cue.PURCHASE: {
		"stream": preload("res://assets/audio/sfx/purchase.wav"),
		"gain_db": -8.0, "cooldown_ms": 100, "pitch_variation": 0.0,
	},
	Cue.SELL: {
		"stream": preload("res://assets/audio/sfx/sell.wav"),
		"gain_db": -8.0, "cooldown_ms": 100, "pitch_variation": 0.0,
	},
	Cue.REROLL: {
		"stream": preload("res://assets/audio/sfx/reroll.wav"),
		"gain_db": -8.0, "cooldown_ms": 100, "pitch_variation": 0.1,
	},
	Cue.LOCK: {
		"stream": preload("res://assets/audio/sfx/lock.wav"),
		"gain_db": -8.0, "cooldown_ms": 100, "pitch_variation": 0.1,
	},
	Cue.UNLOCK: {
		"stream": preload("res://assets/audio/sfx/unlock.wav"),
		"gain_db": -8.0, "cooldown_ms": 100, "pitch_variation": 0.1,
	},
	Cue.PLANT: {
		"stream": preload("res://assets/audio/sfx/plant.wav"),
		"gain_db": -8.0, "cooldown_ms": 100, "pitch_variation": 0.1,
	},
	Cue.FERTILIZE: {
		"stream": preload("res://assets/audio/sfx/fertilize.wav"),
		"gain_db": -8.0, "cooldown_ms": 100, "pitch_variation": 0.1,
	},
	Cue.MUTATE: {
		"stream": preload("res://assets/audio/sfx/mutate.wav"),
		"gain_db": -8.0, "cooldown_ms": 100, "pitch_variation": 0.1,
	},
	Cue.HARVEST: {
		"stream": preload("res://assets/audio/sfx/harvest.wav"),
		"gain_db": -8.0, "cooldown_ms": 100, "pitch_variation": 0.0,
	},
	Cue.TRAIN: {
		"stream": preload("res://assets/audio/sfx/train.wav"),
		"gain_db": -8.0, "cooldown_ms": 100, "pitch_variation": 0.1,
	},
	Cue.COMPOST: {
		"stream": preload("res://assets/audio/sfx/compost.wav"),
		"gain_db": -8.0, "cooldown_ms": 100, "pitch_variation": 0.1,
	},
	Cue.SEAL: {
		"stream": preload("res://assets/audio/sfx/seal.wav"),
		"gain_db": -8.0, "cooldown_ms": 100, "pitch_variation": 0.0,
	},
	Cue.SLASH: {
		"stream": preload("res://assets/audio/sfx/slash.wav"),
		"gain_db": -16.0, "cooldown_ms": 90, "pitch_variation": 0.1,
	},
	Cue.HEAVY_SWING: {
		"stream": preload("res://assets/audio/sfx/heavy_swing.wav"),
		"gain_db": -12.0, "cooldown_ms": 110, "pitch_variation": 0.1,
	},
	Cue.BOW: {
		"stream": preload("res://assets/audio/sfx/bow.wav"),
		"gain_db": -13.0, "cooldown_ms": 100, "pitch_variation": 0.1,
	},
	Cue.THROW: {
		"stream": preload("res://assets/audio/sfx/throw.wav"),
		"gain_db": -16.0, "cooldown_ms": 100, "pitch_variation": 0.1,
	},
	Cue.HORN: {
		"stream": preload("res://assets/audio/sfx/horn.wav"),
		"gain_db": -12.0, "cooldown_ms": 180, "pitch_variation": 0.1,
	},
	Cue.CHARGE: {
		"stream": preload("res://assets/audio/sfx/charge.wav"),
		"gain_db": -13.0, "cooldown_ms": 150, "pitch_variation": 0.1,
	},
	Cue.HIT_SLASH: {
		"stream": preload("res://assets/audio/sfx/hit_slash.wav"),
		"gain_db": -11.0, "cooldown_ms": 80, "pitch_variation": 0.1,
	},
	Cue.HIT_BLUNT: {
		"stream": preload("res://assets/audio/sfx/hit_blunt.wav"),
		"gain_db": -9.0, "cooldown_ms": 80, "pitch_variation": 0.1,
	},
	Cue.BLOCK: {
		"stream": preload("res://assets/audio/sfx/block.wav"),
		"gain_db": -12.0, "cooldown_ms": 120, "pitch_variation": 0.1,
	},
	Cue.DEATH: {
		"stream": preload("res://assets/audio/sfx/death.wav"),
		"gain_db": -12.0, "cooldown_ms": 120, "pitch_variation": 0.1,
	},
	Cue.GROUND: {
		"stream": preload("res://assets/audio/sfx/ground.wav"),
		"gain_db": -19.0, "cooldown_ms": 140, "pitch_variation": 0.1,
	},
	Cue.EXPLOSION: {
		"stream": preload("res://assets/audio/sfx/explosion.wav"),
		"gain_db": -4.0, "cooldown_ms": 120, "pitch_variation": 0.1,
	},
	Cue.SPORE: {
		"stream": preload("res://assets/audio/sfx/spore.wav"),
		"gain_db": -16.0, "cooldown_ms": 180, "pitch_variation": 0.1,
	},
	Cue.REVIVE: {
		"stream": preload("res://assets/audio/sfx/revive.wav"),
		"gain_db": -8.0, "cooldown_ms": 200, "pitch_variation": 0.0,
	},
	Cue.ACID_RAIN: {
		"stream": preload("res://assets/audio/sfx/acid_rain.wav"),
		"gain_db": -11.0, "cooldown_ms": 100, "pitch_variation": 0.1,
	},
	Cue.BATTLE_START: {
		"stream": preload("res://assets/audio/sfx/battle_start.wav"),
		"gain_db": -5.0, "cooldown_ms": 100, "pitch_variation": 0.0,
	},
	Cue.BATTLE_WIN: {
		"stream": preload("res://assets/audio/sfx/battle_win.wav"),
		"gain_db": -5.0, "cooldown_ms": 100, "pitch_variation": 0.0,
	},
	Cue.RUN_WIN: {
		"stream": preload("res://assets/audio/sfx/run_win.wav"),
		"gain_db": -5.0, "cooldown_ms": 100, "pitch_variation": 0.0,
	},
	Cue.RUN_LOSS: {
		"stream": preload("res://assets/audio/sfx/run_loss.wav"),
		"gain_db": -5.0, "cooldown_ms": 100, "pitch_variation": 0.0,
	},
	Cue.GREAT_SLASH: {
		"stream": preload("res://assets/audio/sfx/great_slash.wav"),
		"gain_db": -13.0, "cooldown_ms": 110, "pitch_variation": 0.08,
	},
	Cue.GREAT_SWING: {
		"stream": preload("res://assets/audio/sfx/great_swing.wav"),
		"gain_db": -9.0, "cooldown_ms": 130, "pitch_variation": 0.08,
	},
	Cue.GREAT_BOW: {
		"stream": preload("res://assets/audio/sfx/great_bow.wav"),
		"gain_db": -10.0, "cooldown_ms": 120, "pitch_variation": 0.08,
	},
	Cue.GREAT_THROW: {
		"stream": preload("res://assets/audio/sfx/great_throw.wav"),
		"gain_db": -13.0, "cooldown_ms": 120, "pitch_variation": 0.08,
	},
	Cue.GREAT_HIT_SLASH: {
		"stream": preload("res://assets/audio/sfx/great_hit_slash.wav"),
		"gain_db": -8.0, "cooldown_ms": 100, "pitch_variation": 0.08,
	},
	Cue.GREAT_HIT_BLUNT: {
		"stream": preload("res://assets/audio/sfx/great_hit_blunt.wav"),
		"gain_db": -8.0, "cooldown_ms": 100, "pitch_variation": 0.08,
	},
	Cue.GREAT_BLOCK: {
		"stream": preload("res://assets/audio/sfx/great_block.wav"),
		"gain_db": -9.0, "cooldown_ms": 140, "pitch_variation": 0.08,
	},
}


static func great_variant(cue: Cue) -> Cue:
	match cue:
		Cue.SLASH: return Cue.GREAT_SLASH
		Cue.HEAVY_SWING: return Cue.GREAT_SWING
		Cue.BOW: return Cue.GREAT_BOW
		Cue.THROW: return Cue.GREAT_THROW
		_: return cue
