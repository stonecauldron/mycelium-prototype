# Setup: download the SDK from github.com/GameAnalytics/GA-SDK-GODOT,
# copy example/addons/GameAnalytics into your project's addons/
# , enable it in Project → Project Settings → Plugins,
# then add this file as an autoload named Analytics. Needs Godot 4.5+.
# Supported platforms are Windows, macOS, Linux, Android, iOS and Web.


# The five event types GameAnalytics offers, in order of how often you'll use them:

# Type            What it's for
# Design          Anything custom — your own events
# Progression     Level / run attempts(start → complete or fail)
# Error           Bugs and exceptions
# Resource    Virtual currency earned and spent

# Event names: max 5 :-separated parts, 64 chars each,
# only a-zA-Z0-9 -_.,:()!?. An illegal character drops the whole event silently.
# Keep names low-cardinality — no player names or IDs in them.
# Main thread only.

# Sessions, playtime, retention, and crashes are collected automatically once initialized; you don't need code for those.



# Analytics.run_start("survival", "forest")
# Analytics.crumb("entered_cave")

# Analytics.start_timer("load:level")
# Analytics.stop_timer("load:level")          # sends the seconds it took

# Analytics.event("enemy:killed:goblin")
# Analytics.event("damage:taken", 35.0)       # with a number to average

# Analytics.currency("sink", "gold", 100, "shop", "fire_sword")
# Analytics.run_end(true, 1420)



extends Node

# Add this file as an Autoload (Project > Project Settings > Autoload) named "Analytics".
# Then any script can call Analytics.event("something").

const GAME_KEY := "dfd8028a3c14a8354ddc1bc19f09bdc9"
const SECRET_KEY := "62e546a11c4f887ded9f5ee69e3441c0531d7b19"

var ga  # the GameAnalytics singleton, null if the plugin is not enabled

var _timers: Dictionary = {}  # timer name -> start time in milliseconds
var _crumbs: Array[String] = []  # last few things the player did
var _mode := ""
var _map := ""


func _ready() -> void:
	if not Engine.has_singleton("GameAnalytics"):
		push_warning("GameAnalytics plugin is not enabled")
		return
	ga = Engine.get_singleton("GameAnalytics")

	# Everything below must be configured BEFORE init().
	ga.configureBuild("0.1.0")

	# Whitelists: values not listed here are silently thrown away later.
	ga.configureAvailableResourceCurrencies(["gold"])
	ga.configureAvailableResourceItemTypes(["shop", "quest"])
	ga.configureAvailableCustomDimensions01(["pc", "mobile"])

	# Starts the session. Playtime, sessions, retention and crashes now come in for free.
	ga.init(GAME_KEY, SECRET_KEY)

	# Custom dimension = a label stuck on every event, so you can filter on the website.
	ga.setCustomDimension01("pc")

	# One-shot smoke event to verify the pipeline shows up on the GA dashboard.
	event("test:integration")


# ---------- 1. DESIGN EVENTS: your own custom events ----------

# The name has 1 to 5 parts separated by ':', which becomes a folder tree on the dashboard.
# Keep names generic ("enemy:killed:goblin"), never put player names or ids in them.
func event(event_id: String, value: float = 0.0) -> void:
	if ga == null:
		return
	ga.addDesignEventWithValue(event_id, value)  # the number is optional but lets you chart an average


# ---------- 2. TIMERS: how long did something take ----------

func start_timer(timer_id: String) -> void:
	_timers[timer_id] = Time.get_ticks_msec()


# Sends the elapsed seconds as the event value.
func stop_timer(timer_id: String) -> float:
	if not _timers.has(timer_id):
		return 0.0
	var seconds: float = (Time.get_ticks_msec() - int(_timers[timer_id])) / 1000.0
	_timers.erase(timer_id)
	event(timer_id, seconds)
	return seconds


# ---------- 3. PROGRESSION EVENTS: a run / level attempt ----------

# Always "start" first, then exactly one "complete" or "fail".
# GA uses these pairs to show where players get stuck or give up.
func run_start(mode: String, map: String) -> void:
	_mode = mode
	_map = map
	crumb("run_start")
	start_timer("run:" + map)
	if ga:
		ga.addProgressionEvent("start", mode, map, "", {})  # 3rd level is optional, leave it empty


func run_end(won: bool, score: int) -> void:
	crumb("run_end")
	stop_timer("run:" + _map)
	if ga:
		var status := "complete" if won else "fail"
		ga.addProgressionEventWithScore(status, _mode, _map, "", score)


# ---------- 4. RESOURCE EVENTS: in-game currency in and out ----------

# "source" = the player gained it, "sink" = the player spent it.
# Don't call this per coin picked up, add them up and send once at the end of the level.
func currency(flow: String, currency_name: String, amount: float, item_type: String, item_id: String) -> void:
	if ga:
		ga.addResourceEvent(flow, currency_name, amount, item_type, item_id, {})


# ---------- 5. ERROR EVENTS: something went wrong ----------

# Severity: "debug", "info", "warning", "error" or "critical".
func error(message: String) -> void:
	if ga:
		ga.addErrorEvent("error", message + " | " + " > ".join(_crumbs), {})


# ---------- breadcrumbs: a local trail, only sent when there is an error ----------

func crumb(where: String) -> void:
	_crumbs.append(where)
	if _crumbs.size() > 20:
		_crumbs.pop_front()  # keep only the newest 20


# Godot sends this when the player closes the window.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		event("quit:" + (_map if _map != "" else "menu"))  # tells you where players give up
