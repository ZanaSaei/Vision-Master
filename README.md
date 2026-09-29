# Vision Master

Interactive English-learning app for the Iranian *Vision* textbook series,
built with **Godot 4.7** targeting Android (portrait, 1080×1920).

## Project layout

| Path | Purpose |
| --- | --- |
| `scenes/` | All screens, grouped by feature (`main_menu/`, `book_menu/`, `grammar/`, `exam/`, `word_game/`, …). Each folder holds its `.tscn` scenes and the matching `.gd` scripts. |
| `scenes/shared/` | Reusable UI and logic shared across screens (`app_router.gd`, `PageView`, `AudioPanel`, the `exercise_engine/`). |
| `autoload/` | Global singletons registered in `project.godot` (see below). |
| `data/` | Game content as JSON, loaded at runtime. `data/grammar/` and `data/final_exams/` hold per-book / per-exam files. |
| `assets/` | Heavy media (audio, lesson images, fonts, exam images). **Not tracked in Git** — see "Media" below. |
| `images/`, `main_icons/`, `buttons_styles/` | Small, tracked UI art: icons, app/boot icons, and StyleBox `.tres` files. |
| `tests/` | Dev/tooling tests. Run a test scene with Godot's `run_scene`. |
| `tools/` | One-off Python data-migration / translation scripts. |
| `server/` | Node.js backend (auth, content manifest, progress sync). |

## Autoloads

| Name | Script | Role |
| --- | --- | --- |
| `Global` | `autoload/Global.gd` | Core app state: current book/lesson, settings, saved words, SRS progress, dictionary. |
| `TransitionManager` | `autoload/TransitionManager.gd` | Scene transitions (slide / fade). |
| `MenuBackground` | `autoload/MenuBackground.gd` | Shared animated background. |
| `Sfx` | `autoload/Sfx.gd` | Sound effects. |
| `API` | `autoload/ApiClient.gd` | Backend client + auth token handling (`user://auth.json`). |
| `Content` | `autoload/ContentManager.gd` | Resolves/downloads off-bundle media to `user://content/`. |
| `Sync` | `autoload/SyncManager.gd` | Progress sync. |

`back_button_handler.gd`, `DesignTokens.gd`, and `ThemeService.gd` are also in
`autoload/` but are used as base classes / theme helpers rather than singletons.

## Media (`assets/` is git-ignored)

The repo deliberately excludes large media. `assets/` (audio, lesson images,
fonts, exam images) exists locally but is **not** committed, and its
per-lesson audio/images are excluded from the APK
(`export_presets.cfg` → `exclude_filter`). At runtime `ContentManager`
(`Content`) fetches missing media from the server into `user://content/` and
falls back gracefully (e.g. TTS) when offline.

Small UI art that **must** ship in the APK lives outside `assets/` in
`images/`, `main_icons/`, and `buttons_styles/`.

## Content data (`data/`)

Most screens load JSON through `Global.load_category("<name>", book, lesson)`,
which reads `res://data/<name>.json`. A few load specific files directly
(e.g. `data/v_dictionary.json`, `data/extracted_words.json`,
`data/v%d_vocabularies.json`, and the exam files under `data/final_exams/`).

## Running tests

Open a test scene from `tests/` and run it (or use `run_scene`). Tests are
self-contained `assert`-style scripts; the ones that touch save files park the
real `user://` files first and restore them afterwards.