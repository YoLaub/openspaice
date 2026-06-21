---
name: openspaice-dev-env
description: How to build/run/test the OpenSpAIce Godot project (engine path, git, naming gotchas)
metadata:
  type: project
---

OpenSpAIce is a Godot **4.6.3-stable** game. The Godot project lives in `open_space/` (created in Story 1.1); planning/impl artifacts live under `_bmad-output/`.

**Engine executable (not on PATH):** `C:\Users\cdax30\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe` (use the `_console` variant for CLI stdout).
- Import/compile-check: `godot --headless --path open_space --import`
- Run headless test runner: `godot --headless --path open_space --script res://tests/unit/test_camera_math.gd` (exit 0 = pass)
- FPS check: `godot --path open_space --measure-fps` (windowed; prints `FPS_MEASUREMENT=`). Note: an unfocused/background window throttles FPS (~33) — measure with vsync off for true capability.

**`git` is NOT installed** on this machine → no repo; story `baseline_commit=NO_VCS`.

**Naming gotchas (apply to all future stories):**
- `Logger` is a **native class in Godot 4.6** — the logger autoload is named **`Log`** (call `Log.info/warn/error/debug`). File is still `logger.gd`.
- Autoload scripts have **no `class_name`** (avoids autoload↔global-class collision); access via singleton name (`EventBus`, `SimClock`, `GameManager`, `ConfigService`).
- Pure/testable logic goes in dependency-free scripts (e.g. `CameraMath` in `camera_math.gd`) because `--script` mode does NOT load autoloads, so anything referencing `Log` won't compile in tests.

GUT addon is not installed (no offline fetch); tests currently use a self-contained headless `SceneTree` runner under `tests/unit/`. See [[openspaice-sprint]].
