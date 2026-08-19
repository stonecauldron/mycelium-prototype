class_name ExternalLinks
extends RefCounted

const STEAM_WISHLIST_URL := "https://store.steampowered.com/app/4963670/Auto_Shrooms/"
const FEEDBACK_URL := "https://forms.gle/zWwB86ZGcmRpucoT7"


## Threaded web: GDScript runs on a worker, so eval/window.open cannot see
## `window`. Arm the button so a capture-phase click on the page (still a user
## gesture) can open a tab; pressed falls back to navigating this frame.
static func arm_web_open(button: BaseButton, url: String) -> void:
	if not OS.has_feature("web"):
		return
	button.mouse_entered.connect(func() -> void: _set_pending(url))
	button.mouse_exited.connect(func() -> void: _set_pending(""))


static func open(url: String) -> void:
	if not OS.has_feature("web"):
		OS.shell_open(url)
		return
	var js_window := _page_window()
	if js_window == null:
		return
	js_window.godotOpenUrl(url)


static func _set_pending(url: String) -> void:
	var js_window := _page_window()
	if js_window == null:
		return
	js_window.godotSetPendingUrl(url)


static func _page_window() -> JavaScriptObject:
	var js_window := JavaScriptBridge.get_interface("window")
	if js_window == null:
		push_warning("ExternalLinks: JavaScript window interface unavailable")
	return js_window
