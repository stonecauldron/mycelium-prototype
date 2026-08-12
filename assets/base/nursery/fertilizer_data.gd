class_name FertilizerData
extends Resource

enum Behavior {
	STAT,
	MEIOSIS,
	SLOW_STEADY,
	FUNGICIDE,
	AMOK,
	FAST_METABOLISM,
	SLOW_METABOLISM,
	TRIPLOID,
	TRAINING_AMNESIA,
	COCOONING,
	STIMULANTS,
	LATE_BLOOMER,
	NORMIFIER,
}

@export var display_name: String = "Fertilizer"
@export_multiline var short_description: String = ""
@export var biomass_cost: int = 2
@export var tint: Color = Color.WHITE
@export var behavior: Behavior = Behavior.STAT
@export var strength_delta: int = 0
@export var dex_delta: int = 0
@export var con_delta: int = 0
@export var spd_delta: int = 0
## Extra growth days granted when this fertilizer is applied (or when planting onto a prepared plot).
@export var growth_bonus: int = 0
## When true, snap the plot to READY after apply / plant.
@export var force_ready: bool = false


func is_stat_source() -> bool:
	return (
		behavior == Behavior.STAT
		or behavior == Behavior.SLOW_STEADY
		or behavior == Behavior.AMOK
		or behavior == Behavior.STIMULANTS
		or behavior == Behavior.LATE_BLOOMER
	)


func apply_to(stats: UnitStatsData, scale_factor: int = 1) -> void:
	if stats == null or not is_stat_source():
		return
	var factor := maxi(scale_factor, 1)
	stats.strength = clampi(stats.strength + strength_delta * factor, 1, 99)
	stats.dex = clampi(stats.dex + dex_delta * factor, 1, 99)
	stats.con = clampi(stats.con + con_delta * factor, 1, 99)
	stats.spd = clampi(stats.spd + spd_delta * factor, 1, 99)


func subtitle_text() -> String:
	var authored := short_description.strip_edges()
	if not authored.is_empty():
		return authored
	return "no effect"
