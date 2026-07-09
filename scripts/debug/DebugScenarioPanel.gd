extends CanvasLayer

signal scenario_requested(player_tier: UnitStats.PowerTier, enemy_tier: UnitStats.PowerTier)

@onready var _weak_vs_avg: Button = %WeakVsAverage
@onready var _avg_vs_avg: Button = %AverageVsAverage
@onready var _strong_vs_avg: Button = %StrongVsAverage


func _ready() -> void:
	_weak_vs_avg.pressed.connect(
		func() -> void: scenario_requested.emit(UnitStats.PowerTier.WEAK, UnitStats.PowerTier.AVERAGE)
	)
	_avg_vs_avg.pressed.connect(
		func() -> void: scenario_requested.emit(UnitStats.PowerTier.AVERAGE, UnitStats.PowerTier.AVERAGE)
	)
	_strong_vs_avg.pressed.connect(
		func() -> void: scenario_requested.emit(UnitStats.PowerTier.STRONG, UnitStats.PowerTier.AVERAGE)
	)
