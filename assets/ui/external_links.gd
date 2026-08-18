class_name ExternalLinks
extends RefCounted

const STEAM_WISHLIST_URL := "https://store.steampowered.com/app/4963670/Auto_Shrooms/"
const FEEDBACK_URL := "https://forms.gle/zWwB86ZGcmRpucoT7"


static func open(url: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open('%s', '_blank');" % url)
	else:
		OS.shell_open(url)
