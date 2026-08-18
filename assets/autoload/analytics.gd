extends Node

## GameAnalytics wrapper. Event names are the ADR-0009 dashboard contract.
## Sessions (app open/close, retention) are automatic after init. Editor builds
## never init. Manual events are dropped while debug cheats are active.

const GAME_KEY := "dfd8028a3c14a8354ddc1bc19f09bdc9"
const SECRET_KEY := "62e546a11c4f887ded9f5ee69e3441c0531d7b19"
const CURRENCY := "Biomass"
const _ITEM_TYPES: Array[String] = [
	"Start",
	"Battle",
	"Shop",
	"Nursery",
	"Scout",
	"Seal",
	"Training",
	"Compost",
	"Stock",
]

var ga: Object = null

var _day_started: int = -1
var _hit_biomass: int = 0


func _ready() -> void:
	if OS.has_feature("editor"):
		return
	if not Engine.has_singleton("GameAnalytics"):
		push_warning("GameAnalytics plugin is not enabled")
		return
	ga = Engine.get_singleton("GameAnalytics")
	ga.configureBuild("0.1.0")
	ga.configureAvailableResourceCurrencies([CURRENCY])
	ga.configureAvailableResourceItemTypes(_ITEM_TYPES)
	ga.configureAvailableCustomDimensions01(["web", "desktop"])
	ga.init(GAME_KEY, SECRET_KEY)
	ga.setCustomDimension01("web" if OS.has_feature("web") else "desktop")


func on_run_started() -> void:
	_day_started = -1
	_hit_biomass = 0
	_progression("start", "run", "", "", -1)
	biomass_source("Start", "Grant", BiomassData.STARTING_AMOUNT)


func maybe_start_day() -> void:
	if not GameState.run_started:
		return
	if not GameState.troop.is_seeded():
		return
	if GameState.has_won_run():
		return
	var day := clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	if day == _day_started:
		return
	_day_started = day
	_progression("start", "day", str(day), _day_band(day), -1)


func day_complete() -> void:
	_end_day("complete")


func day_fail() -> void:
	_end_day("fail")


func run_complete() -> void:
	_progression("complete", "run", "", "", GameState.current_day)


func run_fail() -> void:
	_progression("fail", "run", "", "", GameState.current_day)


func note_hit_biomass(amount: int) -> void:
	if amount <= 0:
		return
	_hit_biomass += amount


func flush_hit_biomass() -> void:
	var amount := _hit_biomass
	_hit_biomass = 0
	biomass_source("Battle", "Hit", amount)


func biomass_source(item_type: String, item_id: String, amount: int) -> void:
	_resource("source", item_type, item_id, amount)


func biomass_sink(item_type: String, item_id: String, amount: int) -> void:
	_resource("sink", item_type, item_id, amount)


func intent(kind: String, scene: String) -> void:
	if not _can_send():
		return
	ga.addDesignEvent("intent:%s:%s" % [slug(kind), slug(scene)])


func intent_scene() -> String:
	var path := ""
	var scene := get_tree().current_scene if get_tree() != null else null
	if scene != null:
		path = scene.scene_file_path
	if path.ends_with("title.tscn"):
		return "title"
	if path.ends_with("victory.tscn"):
		return "victory"
	if path.ends_with("game_over.tscn"):
		return "gameover"
	if path.ends_with("combat_stage.tscn"):
		return "combat"
	# Day summary and Base are both between-Days; contract only has `base`.
	return "base"


## Authored catalog slug. Never uses display names (those can be Unit names).
func resource_slug(resource: Resource) -> String:
	if resource == null:
		return ""
	if resource.resource_path != "":
		return slug(resource.resource_path.get_file().get_basename())
	var seal := resource as SealData
	if seal != null and seal.id != &"":
		return slug(str(seal.id))
	var mutation := resource as MutationData
	if mutation != null and mutation.effect != null:
		var effect_script := mutation.effect.get_script() as Script
		if effect_script != null and effect_script.resource_path != "":
			var stem := effect_script.resource_path.get_file().get_basename()
			if stem.ends_with("_effect"):
				stem = stem.substr(0, stem.length() - "_effect".length())
			return slug(stem)
	var fertilizer := resource as FertilizerData
	if fertilizer != null:
		var key: Variant = FertilizerData.Behavior.find_key(fertilizer.behavior)
		if key != null:
			return slug(str(key).to_lower())
	return ""


func slug(text: String) -> String:
	var out := ""
	for i in text.length():
		var ch := text.substr(i, 1)
		if ch == " ":
			continue
		var code := ch.unicode_at(0)
		var letter := (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var digit := code >= 48 and code <= 57
		if letter or digit or ch == "-" or ch == "_" or ch == ".":
			out += ch
	return out


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		intent("quit", intent_scene())


func _can_send() -> bool:
	if ga == null:
		return false
	if GameState.debug_mode_active:
		return false
	return true


func _day_band(day: int) -> String:
	return "elite" if GameState.is_elite_day(day) else "normal"


func _end_day(status: String) -> void:
	var day := clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	_progression(status, "day", str(day), _day_band(day), GameState.biomass.amount)


func _progression(
	status: String,
	progression01: String,
	progression02: String,
	progression03: String,
	score: int
) -> void:
	if not _can_send():
		return
	if score < 0:
		ga.addProgressionEvent(status, progression01, progression02, progression03, {})
		return
	ga.addProgressionEventWithScore(status, progression01, progression02, progression03, score)


func _resource(flow: String, item_type: String, item_id: String, amount: int) -> void:
	if amount <= 0 or not _can_send():
		return
	var id := slug(item_id)
	if id.is_empty():
		return
	ga.addResourceEvent(flow, CURRENCY, float(amount), item_type, id, {})
