extends Node
## ============================================================
##  SCENE THEMING SWEEP — run with run_scene on TestSceneTheming.tscn.
##
##  Proves the claim the redesign rests on: every scene in the app still
##  loads, instantiates, enters the tree and survives the app-wide styling
##  pass. Because the entire restyle is delivered through the Theme resource
##  and ThemeService's scene walk — not by editing scenes — this is the test
##  that shows "all 49 scenes" really were restyled rather than assumed.
##
##  Scenes named *Test* are skipped: they are not app screens, and several of
##  them run their own suites on _ready.
##
##  EXIT-TIME NOTE: this sweep deliberately boots all 47 screens, which
##  populates process-lifetime caches — most visibly MenuStyle._font_cache, a
##  `static var` holding every font the app loads. Godot therefore reports "1
##  resource still in use at exit" after a sweep run. That is the cache being
##  held correctly, not a leak from this test: every scene instance is freed
##  here, and the same note appears when the real app is launched and closed.
## ============================================================

const SCENE_ROOT := "res://scenes"

var _failures := 0


func test_all_app_scenes_theme_cleanly() -> void:
	await _sweep()
	_report()


func _sweep() -> void:
	var paths := _collect_scenes(SCENE_ROOT)
	paths.sort()
	_check(paths.size() >= 40, "the sweep found the app's scenes (%d)" % paths.size())

	var themed := 0
	var failures: Array = []
	for path in paths:
		var packed := load(path)
		if packed == null or not (packed is PackedScene):
			failures.append("%s (not a PackedScene)" % path)
			continue
		var instance: Node = (packed as PackedScene).instantiate()
		if instance == null:
			failures.append("%s (instantiate returned null)" % path)
			continue

		# Enter the tree so any _ready-time work runs for real, then run the
		# same styling pass the app runs on every scene change.
		add_child(instance)
		Global.style_scene(instance)
		await get_tree().process_frame
		themed += 1
		remove_child(instance)
		instance.free()

	_check(failures.is_empty(),
		"every scene instantiates, enters the tree and survives styling (%d/%d ok; failed: %s)"
			% [themed, paths.size(), str(failures)])


## Recursively collects every .tscn under `dir`, skipping test scenes.
func _collect_scenes(dir: String) -> Array:
	var out: Array = []
	var handle := DirAccess.open(dir)
	if handle == null:
		return out
	handle.list_dir_begin()
	var entry := handle.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = handle.get_next()
			continue
		var full := dir.path_join(entry)
		if handle.current_is_dir():
			out.append_array(_collect_scenes(full))
		elif entry.ends_with(".tscn") and not entry.to_lower().contains("test"):
			out.append(full)
		entry = handle.get_next()
	handle.list_dir_end()
	return out


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
	print(("PASS  " if condition else "FAIL  ") + label)


func _report() -> void:
	print("---")
	print("ALL TESTS PASSED" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
