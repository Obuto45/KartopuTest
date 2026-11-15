extends SceneTree
## godot --headless --path . -s res://tests/version_test.gd
func _init() -> void:
	var U = preload("res://updater.gd")
	assert(U.is_newer("v0.3", "0.2"))
	assert(U.is_newer("v0.10", "0.9"))
	assert(U.is_newer("v1.0", "0.9.9"))
	assert(U.is_newer("v0.3.1", "0.3"))
	assert(not U.is_newer("v0.3", "0.3"))
	assert(not U.is_newer("v0.2", "0.3"))
	assert(not U.is_newer("", "0.3"))
	print("VERSION_TEST OK, surum=", U.version())
	quit()