# Vision Master — Architecture

This document records the project's structural conventions and the
decomposition decisions made during the refactor, so future work lands in the
right place instead of recreating a god-object.

## Directory layout

```
res://
├── assets/                  # raw content (audio, fonts, images, exam media)
│   ├── audio/
│   ├── fonts/
│   └── images/
│       ├── brand/           # logo / splash art (was main_icons/)
│       ├── lessons/         # v*_l*_*.png lesson illustrations
│       └── ui/              # UI icons (was images/)
├── autoload/                # singletons + their collaborators
│   ├── Global.gd            # app-wide state facade (nav, theme, words, progress)
│   ├── DesignTokens.gd      # single source of truth for the visual language
│   └── theme/               # the decomposed theme engine
│       ├── theme_service.gd        # palette + mode + Theme resource life-cycle
│       ├── scene_style_walk.gd     # generic Dark/Light scene walk
│       └── header_bar_styler.gd    # unified header bar engine
├── data/                    # lesson / exam JSON content
├── resources/               # EDITABLE design-system resources (see below)
├── scenes/                  # all .tscn + their scripts, grouped by feature
├── scripts/resources/       # custom Resource classes (UiMotionProfile, TypeScale)
├── ui/                      # reusable UI layer
│   ├── theme/menu_theme.gd  # fonts + palette access + accented styles
│   ├── theme/menu_style.gd  # MenuStyle facade (public API kept stable)
│   ├── motion/ui_motion.gd  # interaction choreography (profile-driven)
│   └── widgets/menu_widgets.gd  # component factory
├── tests/
└── tools/                   # content/generation utilities
```

Naming: `snake_case` for files/folders, `PascalCase` for classes/nodes.

## The design system is now RESOURCES

The visual language used to exist only as GDScript (`DesignTokens` factories +
a `Theme` built in code each launch). It is now authored as `.tres` resources
that the editor Inspector can open and edit:

| Folder | Contents |
|---|---|
| `resources/themes/` | `vision_master_dark.tres` / `_light.tres` — the two base Themes (assigned to the tree root by `ThemeService`) |
| `resources/styleboxes/` | one file per component state (button primary/hover/pressed/…, card, card_lifted, inset, input_focus, toast, modal header/body, toggle on/off, table rows, nav buttons, separator, …) |
| `resources/textures/` | generated slider grabber discs |
| `resources/motion/` | `UiMotionProfile` recipes (`pop_in`, `shake`, `pop`, `pulse`, `slide_in`, `transition_*`, `press_*`, …) |
| `resources/typography/` | `TypeScale` — every font size the UI reads |

`DesignTokens.gd` remains the single source of truth for the *values*. When a
token changes, regenerate the `.tres` files:

```
godot --headless --path . --script res://tools/generate_design_resources.gd
```

> Hand-edits to generated files are overwritten — that is intentional. To tune
> a value, edit either the resource (if you want a one-off) or the token (if
> you want it everywhere).

## Decomposition rules

`Global.gd` and the theme engine used to be god-objects. The pattern applied
everywhere is the same:

1. **Signal up, call down.** A child reports state through signals; a parent
   commands a child through methods. (`WordleScreen` no longer reaches into its
   host's header node — it emits `card_available_changed` and exposes
   `show_card()`.)
2. **A singleton facade forwards to focused collaborators.** `Global` owns a
   `ThemeService`; `ThemeService` owns a `HeaderBarStyler` + `ThemeSceneStyler`;
   `MenuStyle` forwards to `MenuTheme` / `MenuWidgets` / `UiMotion`. Call sites
   keep working while the responsibility shrinks.
3. **Static screen chrome lives in the scene; factories build only dynamic
   content.** JSON-driven lists, toasts and modals are legitimately built in
   code. Anything static belongs in the `.tscn` with `@export` tunables.

### Theme engine

- `theme_service.gd` — loads the mode's Theme resource, pushes the palette
  context into the collaborators, applies to the root and the MenuBackground.
- `scene_style_walk.gd` — the generic walk; skips scenes in `SELF_THEMED_SCRIPTS`.
- `header_bar_styler.gd` — the header geometry + item layout engine. It is a
  pure function of its context (no autoload), so it can be tested in isolation.

### Menu design language

- `MenuTheme` — fonts, palette access, accented stylebox builders.
- `MenuWidgets` — `make_card/make_button/make_toast/make_modal/…`.
- `UiMotion` — `pop_in/shake/pop/pulse/slide_in/wire_microinteractions`, all
  reading `UiMotionProfile` resources (no hardcoded durations/easings).
- `MenuStyle` — the stable facade; prefer the module you need in new code.

## Inspector-first conventions

- Every tunable number/colour/geometry is `@export` (see `WordleScreen` and
  `WordOfDay` headers for the pattern), grouped with `@export_group`.
- No `get_node("../…")` across scene boundaries. Use exported `NodePath`, a
  signal, or move ownership to the host.

## Known remaining work (documented, not yet done)

- `autoload/Global.gd` (~1000 lines) still owns several data concerns that
  could move into `autoload/services/` following the ThemeService pattern:
  lesson-data loading (`load_vocabulary/load_reading/load_category` + the JSON
  caches), the saved/review word + SRS store (`saved_words`, `review_words`,
  `get_due_words`, `_compute_srs_result`, …), progress persistence
  (`grammar_xp`, snapshots) and settings. The SRS logic has 19 passing tests in
  `tests/test_srs_leitner.gd` to guard an extraction.
- `scenes/shared/exercise_engine/exercise_engine_builders.gd` (~2900 lines) is
  the largest remaining monolith. It is already an inheritance chain
  (core → widgets → builders → grading); the builders layer should be split
  per exercise family (choice / text / table / media), extending the same
  chain, exactly as the existing `build()` virtual-dispatch already permits.
- `scenes/reading/reading.gd` (~900 lines) builds three data-driven pages; the
  page builders are candidates for child scenes under `scenes/reading/pages/`.
