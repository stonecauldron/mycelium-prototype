class_name FertilizerData
extends Resource

enum Behavior {
	STAT,
	MEIOSIS,
	SLOW_STEADY,
	FUNGICIDE,
	AMOK,
	TRIPLOID,
	TRAINING_AMNESIA,
	COCOONING,
	STIMULANTS,
	LATE_BLOOMER,
	NORMIFIER,
	VOLATILE,
}

const AMOK_ATTACK_RATE := 2.0

@export var display_name: String = "Fertilizer"
@export_multiline var short_description: String = ""
@export var biomass_cost: int = 2
@export var tint: Color = Color.WHITE
@export var behavior: Behavior = Behavior.STAT
@export var strength_delta: int = 0
@export var dex_delta: int = 0
@export var con_delta: int = 0
## Days subtracted from Remaining Time when applied (or when planting onto a prepared plot).
@export var growth_bonus: int = 0
## When true, set Remaining Time to 0 after apply / plant.
@export var force_ready: bool = false


func is_stat_source() -> bool:
	return (
		behavior == Behavior.STAT
		or behavior == Behavior.SLOW_STEADY
		or behavior == Behavior.AMOK
		or behavior == Behavior.STIMULANTS
		or behavior == Behavior.LATE_BLOOMER
		or behavior == Behavior.VOLATILE
	)


func apply_to(stats: UnitStatsData, scale_factor: int = 1) -> void:
	if stats == null or not is_stat_source():
		return
	var factor := maxi(scale_factor, 1)
	stats.strength = clampi(stats.strength + strength_delta * factor, 1, 99)
	stats.dex = clampi(stats.dex + dex_delta * factor, 1, 99)
	stats.con = clampi(stats.con + con_delta * factor, 1, 99)


func subtitle_text() -> String:
	var authored := short_description.strip_edges()
	if not authored.is_empty():
		return authored
	return "no effect"
