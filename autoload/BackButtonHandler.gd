extends Control

# ============================================================
#  BACK BUTTON HANDLER
#  Base script for handling Android back button
#  Extend this script in all scenes that need back button support
# ============================================================

var back_pressed_time: float = 0.0
var double_back_timeout: float = 2.0  # seconds to wait for second back press


func _ready() -> void:
	# Make sure the scene can receive input
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.echo:
			return
		# Android's back button can surface as either keycode or
		# physical_keycode depending on the device/platform — check both.
		if event.pressed and (event.keycode == KEY_BACK or event.physical_keycode == KEY_BACK):
			_on_android_back_pressed()


func _on_android_back_pressed() -> void:
	# Override this in child scenes
	pass


# ══════════════════════════════════════════════════════════════
#  APP-WIDE HEADER BAR
#
#  Every screen carries the same authored HeaderBar block (200 px white
#  surface, back arrow, title). HeaderBarStyler gives it its look; this
#  helper only connects it to the screen:
#    * the back arrow runs the screen's Android-back handler,
#    * the title text can be overridden (for dynamic screens),
#    * the bar is lifted above the page so it paints over scrolling content.
# ══════════════════════════════════════════════════════════════
func wire_header_bar(title: String = "") -> void:
	var header: Control = get_node_or_null("HeaderBar") as Control
	if header == null:
		return

	if not title.is_empty():
		var label: Label = header.get_node_or_null("HeaderContent/HeaderTitle") as Label
		if label != null:
			label.text = title

	var back_button: Button = header.get_node_or_null("HeaderContent/BackButton") as Button
	if back_button != null:
		var handler: Callable = Callable(self, "_on_android_back_pressed")
		if not back_button.pressed.is_connected(handler):
			back_button.pressed.connect(handler)
	# Apply the app-wide canonical look: white 200 px surface, square icon
	# buttons in fixed slots, home removed, centred title ramp.
	Global.style_header(header)

	raise_header_bar()


## Puts the header bar last among the scene's children, so it is drawn — and
## receives mouse input — above the page. A scene that authors the bar last is
## already correct and this is a no-op; screens that build their page in code
## must call it once their content exists (and before adding any modal, which
## is expected to sit on top of the bar).
func raise_header_bar() -> void:
	var header: Control = get_node_or_null("HeaderBar") as Control
	if header == null:
		return
	if header.get_index() != get_child_count() - 1:
		move_child(header, get_child_count() - 1)
