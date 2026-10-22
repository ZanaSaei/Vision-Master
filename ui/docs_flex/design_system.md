# Vision Master — Flexible UI Design System

> Core principle: reuse styles and design resources, not rigid UI structures.
> Create any node tree you want in the scene editor. Reuse a shared
> StyleBox / Theme / token when useful. Never inherit a universal UI script.

## 1. Where everything lives (canonical paths)

- Themes: res://resources/themes/vision_master_dark.tres and
  vision_master_light.tres — applied to tree root by ThemeService.
- Shared StyleBoxes: res://resources/styleboxes/*.tres (~90 files:
  button_*, card_*, input_*, modal_*, toggle_*, pill_*, toast_*,
  table_row_*, ...). Assign via theme_override_styles in Inspector.
- New danger treatment: res://ui/styles_flex/danger_dark.tres and
  danger_light.tres — the only 2 new styles (missing red treatment).
- Optional helper: res://ui/ui_theme.gd (class_name UiTheme) — tiny
  static forwarder to Global/tokens. Optional, never required.
- Palette + scales: res://autoload/DesignTokens.gd (PALETTE_DARK /
  PALETTE_LIGHT, RADIUS_*, BORDER_*, SHADOW_*, SPACE_*, FONT_*).
- Typography: res://resources/typography/type_scale.tres (TypeScale).
- Motion: res://resources/motion/*.tres via res://ui/motion/ui_motion.gd.
- Theme engine: res://autoload/theme/theme_service.gd (owned by Global),
  scene_style_walk.gd, header_bar_styler.gd. Mode persists to
  user://settings.json as theme_mode (0 = Dark, 1 = Light).
- Theme toggle UI: scenes/settings/Settings.tscn -> _on_theme_toggled().
- Navigation: res://autoload/BottomNavigation.gd +
  scenes/bottom_navigation/NavigationBar.tscn (persistent layer).
- Transitions: res://autoload/TransitionManager.gd.
- Regenerator: res://tools/generate_design_resources.gd — run ONLY when
  a DesignTokens VALUE changes. It overwrites generated .tres files.

Fonts: res://assets/fonts/ (Vazirmatn for Persian/RTL, PlusJakartaSans,
Nunito, Josefin). Base: 1080x1920 portrait, stretch canvas_items/expand.

## 2. How light / dark themes work

1. Global.theme_mode: 0 = Dark, 1 = Light (Global.ThemeMode enum),
   persisted in user://settings.json.
2. ThemeService._activate_theme() loads the matching .tres Theme, sets it
   on the tree root, pushes palette + mode into the scene walk + header
   styler, and recolors the MenuBackground waves.
3. Global.style_scene(current_scene) runs on every scene change and boot,
   so native controls pick up the base Theme automatically.
4. Global.theme_changed(mode) fires; self-themed scenes subscribed via
   Global.on_theme_changed(_apply_theme) repaint custom bits from
   Global.get_theme_color(role).

Deliberate exceptions that do NOT follow the theme: book-cover artwork,
FlashcardHub gradient cards, game-specific colors, nav-bar icons/shader.

## 3. Reusing a style (Inspector, 30 seconds)

1. Select the control (e.g. a Button).
2. Inspector -> Theme Overrides -> Styles -> e.g. normal -> Load.
3. Pick the shared file. For buttons prefer the script path
   UiTheme.stylebox("button_primary"), which resolves the _dark/_light
   twin automatically at runtime.
4. One-off tweak: assign the shared style, then use Make Unique to get a
   scene-local copy - the shared file stays untouched.

## 4. Changing a shared style (Inspector)

1. Open e.g. res://resources/styleboxes/card_dark.tres in FileSystem dock.
2. Edit Bg Color, Border Color/Width, Corner Radius, Content Margins,
   Shadow Color/Size/Offset. Save (Ctrl+S). Every user updates at once.
3. If you changed a VALUE in DesignTokens.gd instead, re-run the
   generator: godot --headless --path <project> --script
   res://tools/generate_design_resources.gd (it overwrites generated files).

## 5. Creating a completely new element (no universal script)

Example: custom EventCard with image + gradient + icon + labels + animation.

1. Scene -> New Scene, root PanelContainer named EventCard.
2. Build YOUR tree: MarginContainer -> VBoxContainer ->
   [TextureRect Cover, HBoxContainer(Row) ->
   [Label Icon, VBoxContainer(Text) -> [Label Title, Label Sub]],
   Label Chevron], plus a gradient overlay. Any nodes, any order.
3. Style by reuse: PanelContainer -> Theme Overrides -> Styles -> panel
   -> Load -> res://resources/styleboxes/card_dark.tres. Fonts:
   Vazirmatn for Persian, sizes from TypeScale (title 62, label 38,
   body 34). Colors: semantic roles, avoid hardcoded hex.
4. Behavior (optional, local script only, TAB indentation, typed GDScript):
   extends PanelContainer; @onready var _title: Label = $Margin/Text/Title;
   func set_event(title: String) -> void: _title.text = title.
   No base class, no universal Card.gd.
5. Theme response (only if it uses theme colors): in _ready connect
   UiTheme.watch(_apply_theme); in _exit_tree call UiTheme.unwatch.
   In _apply_theme repaint from UiTheme.color("text") etc.
   If the card is a deliberate exception (artwork), skip this entirely.

## 6. Adding a new style

1. Duplicate the closest .tres (e.g. card_dark.tres -> card_glow_dark.tres,
   plus the _light twin) or create under res://UI/Styles/ for new ideas.
2. Rename descriptively (<element>_<variant>_<mode>.tres), configure.
3. Reuse via Inspector Load or UiTheme.stylebox("card_glow").
4. Do NOT create dozens of near-identical files - prefer Make Unique.

## 7. Adding or changing a color

1. Colors live in DesignTokens.PALETTE_DARK / PALETTE_LIGHT - both must
   define the same PALETTE_ROLES.
2. Add the role to BOTH palettes + PALETTE_ROLES.
3. Run tests/test_design_system.gd (palette guard) + the generator if a
   .tres must carry it.
4. Scenes read it via Global.get_theme_color("info") - no scene sweep.

## 8. Switching themes (and testing both)

- Runtime: Settings toggle -> Global.set_theme_mode(DARK/LIGHT) ->
  root Theme swaps + theme_changed fires -> scenes repaint.
- Editor spot-check: open Settings or VocabFlashcards, swap a panel or
  button stylebox to the _light twin, verify contrast, restore (scripts
  resolve the mode at runtime).
- Verify states: normal, hover (desktop), pressed, disabled, focus.
  FlashcardHub gradient cards stay identical in both themes by design.

## 9. Troubleshooting
- Inspector edits overwritten at runtime: ThemeSceneStyler.INSPECTOR_FIRST
  is true by default (res://autoload/theme/scene_style_walk.gd), so the
  global walk no longer repaints scenes. WordGameHub is also exempt via
  SELF_THEMED_SCRIPTS ("wordgamehub.gd"). If your scene still gets
  repainted, its own script is doing add_theme_*_override — remove those
  lines (keep Exercise Engine files untouched).

- Style missing: right override slot (normal vs panel)? Correct twin?
  Valid path (no move without fix-up)?
- Custom element ignores switch: connected via on_theme_changed or
  UiTheme.watch? Does _apply_theme re-read get_theme_color (not cached)?
- Whole switch fails: Global._theme alive? user://settings.json writable?
  Theme .tres present (else empty-Theme fallback + warning)?
- Unreadable text: hardcoded color? Replace with UiTheme.color(role)
  or per-theme branches like Settings does.
- Scene styled twice: add its script filename to
  ThemeSceneStyler.SELF_THEMED_SCRIPTS so the generic walk skips it.
## 10. WordGameHub — style it manually in the Inspector
- Code styling removed from res://scenes/word_game/WordGameHub.gd: no
  add_theme_* calls, no MenuStyle/UiTheme/DesignTokens. The script only
  connects signals, fetches the leaderboard, and builds plain rows
  (PanelContainer named "Row"/"SelfRow" + Labels).
- Tab buttons (DailyBoardButton/LifetimeButton) have toggle_mode = true.
  The script only sets button_pressed; YOU style normal vs pressed in
  the Inspector (Theme Overrides -> Styles -> normal / pressed).
- Mode buttons (LearningButton/DailyButton): style normal/hover/pressed/
  focus + font colors directly in WordGameHub.tscn. Nothing overwrites them:
  the global walk is Inspector-first and WordGameHub is exempt.
- Leaderboard rows are runtime PanelContainers ("Row"/"SelfRow"). Give
  them visuals via the project Theme: assign Panel styles for those
  names, or add a tiny scene-local theme. Do NOT add code styling back.
- Exercise Engine files (res://scenes/shared/exercise_engine/*) untouched.
