class_name WindowMode
## Applies the fullscreen setting to the main window. Headless builds (tests, CI) have no
## real window, so every call is a safe no-op there.

const HEADLESS := "headless"


static func mode_for(fullscreen: bool) -> DisplayServer.WindowMode:
	return DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED


static func is_supported() -> bool:
	return DisplayServer.get_name() != HEADLESS


static func is_fullscreen() -> bool:
	if not is_supported():
		return false
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## Switches the window only when it is not already in the requested mode.
static func apply(fullscreen: bool) -> void:
	if not is_supported() or is_fullscreen() == fullscreen:
		return
	DisplayServer.window_set_mode(mode_for(fullscreen))
