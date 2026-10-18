extends CanvasLayer
############################################################
# BOTTOM NAVIGATION (autoload "BottomNavigation")
# One persistent bottom navigation bar shared by every scene
# that needs it. It lives on its own canvas layer above the
# scene content, so it never slides, never re-initialises and
# never flickers when change_scene_to_file() swaps the screens.
#
# When the current scene changes it tells the bar which scene is
# now showing: the bar shows/hides itself and glides its selector
# to the tab that owns that scene.
############################################################

const NAVIGATION_BAR_SCENE: PackedScene = preload(
	"res://scenes/bottom_navigation/NavigationBar.tscn"
)

# Above scene content (layer 0) but below the transition overlay.
const BAR_LAYER: int = 1

var bar: VisionNavigationBar


func _ready() -> void:
	layer = BAR_LAYER
	bar = NAVIGATION_BAR_SCENE.instantiate() as VisionNavigationBar
	add_child(bar)

	# Keep the bar in sync with the active scene, on launch and on every swap.
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_on_scene_changed")


func _on_scene_changed() -> void:
	if bar == null or not is_instance_valid(bar):
		return
	var current: Node = get_tree().current_scene
	bar.apply_scene_path("" if current == null else current.scene_file_path)
