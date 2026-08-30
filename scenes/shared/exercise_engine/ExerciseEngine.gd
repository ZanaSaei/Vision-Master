# ============================================================
# Universal interactive exercise renderer for Godot 4.7
# ============================================================
# This is the PUBLIC face of the split ExerciseEngine module.
# The implementation lives in sibling files in this folder,
# arranged as an inheritance chain (each extends the previous):
#
#   exercise_engine_core.gd      ExerciseEngineCore     state, lifecycle,
#                                                     gestures, keyboard,
#                                                     persistence
#   exercise_engine_widgets.gd   ExerciseEngineWidgets  text helpers, widget
#                                                     factory, audio button
#   exercise_engine_builders.gd  ExerciseEngineBuilders build() dispatcher +
#                                                     all _build_* types
#   exercise_engine_grading.gd   ExerciseEngineGrading  answer checking,
#                                                     scoring, retry, save
#   ExerciseEngine.gd            this file (leaf)       class_name + aliases
#
# Support classes used by the chain:
#   exercise_theme.gd            ExerciseTheme          palette + live colors
#   exercise_strings.gd          ExerciseStrings        UI chrome strings
#   Dropdown.gd                  ExerciseDropdown       custom popup button
#   HotspotOverlay.gd            ExerciseHotspotOverlay image hotspot layer
# ============================================================

class_name ExerciseEngine
extends "res://scenes/shared/exercise_engine/exercise_engine_grading.gd"

# Compatibility aliases: existing call sites may reference the old
# inner classes via ExerciseEngine.Dropdown / ExerciseEngine.HotspotOverlay.
const Dropdown = preload("res://scenes/shared/exercise_engine/Dropdown.gd")
const HotspotOverlay = preload("res://scenes/shared/exercise_engine/HotspotOverlay.gd")