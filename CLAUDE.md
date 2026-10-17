# Emergent Chaos Simulator: rules for Claude Code

A top-down 2D "god view" city sim in **Godot 4.7.2 + GDScript**, shipped as a single-threaded **Web export on itch.io** (desktop Chrome and Firefox). 40 citizens and 20 cars live in a small district; the player drops criminals (Car Thief, Road Rager) and watches unscripted chain reactions. Launch target **Mon Nov 16 2026**, hard cutoff **Wed Nov 18**. Spec: `docs/chaos-simulator-spec.md` (v2). Plan: `PLAN.md`.

## Start of every session
1. Read `PLAN.md` → **Progress log** (bottom) → find the first unchecked task. Read only that task (use Read with an offset; the plan is long).
2. Tell the human in one line which task you're starting.

## Ground rules
- Follow `PLAN.md` exactly. Don't change the design, add features, or add libraries or plugins that aren't in the plan. If something in the plan seems wrong, stop and explain it to the human.
- One task at a time. Tick each step's checkbox when it's done. Commit after each task using the message from the plan. Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Stop at every 🧑 HUMAN task and wait for the human's reply. Never assume a visual, browser, account or physical step worked.
- If a step fails, check the task's "If it fails" notes. After 2 failed fix attempts, stop and explain the problem to the human in plain words, with options.
- Never put secrets in tracked files. This project has none: no API keys, no live AI, no `.env`.
- Only touch files listed in the current task, unless the human agrees.
- [P] tasks may go to subagents in parallel only if they share no files. (This plan marks none; Godot's import step and shared scripts make parallel work risky.)
- At the end of each task, add a row to the Progress log. At the end of each phase, append a dated entry to `DEVLOG.md` (what we built, what broke, one interesting decision; it becomes the Substack draft) and suggest the human start a fresh session.

## Architecture rules (keep them)
- **GDScript with static typing.** Folders: `scenes/ scripts/ data/ art/ tests/`. Nodes are mostly built in code from `class_name` scripts. `.tscn` files exist only for the main scene and the test runner.
- **`Sim` autoload** owns the only seeded `RandomNumberGenerator` (`Sim.rng`), the clock, `Sim.city` (`CityMap`), `Sim.nav` (`Nav`) and the traffic-light board. Never call global `randi()`, `randf()`, `randomize()` or `Array.shuffle()`. A seed must rebuild the same starting city (Reset reuses the seed, New Seed changes it).
- **Clock:** 1 real second = 2 sim minutes, the day starts at 06:00, a full day is 12 real minutes. Speed = `Engine.time_scale` (0, 1, 3).
- **`EventBus` autoload** has one signal: `danger(position: Vector2, radius: float, kind: StringName)`. Kinds: `crash`, `explosion`, `theft`, `ragdoll`, `water`, `panic`, `test`. Agents and objects never hold references to each other. They emit danger and react to danger by their own rules. **Allowed exceptions:** (1) direct calls between two bodies that are physically touching, inside a collision or overlap callback (`take_hit`, `set_slippery`, `steal`); (2) a citizen controlling its own car. Chain reactions must emerge, never be scripted end to end.
- **Movement:** agents follow `AStarGrid2D` paths as `CharacterBody2D` (FLOATING motion mode). Hard impacts swap them for an `ImpactBody` (`RigidBody2D`, no gravity, damped, bouncy, max 5 at once, force-settled after 4 s), and they take back over when it settles.
- **Collision layers** (`Sim` constants): `L_CARS` 1, `L_CITIZENS` 2, `L_OBJECTS` 4, `L_RAGDOLLS` 8, `L_WALLS` 16.
- **Web constraints:** Compatibility renderer only, Thread Support OFF, steady frame rate at 60 agents. Fallback: 30 citizens + 15 cars (`Sim.CITIZEN_COUNT`, `Sim.CAR_COUNT`).
- **Art:** Kenney CC0 sprites in `art/sprites/`; raw packs live in `art/kenney/` (has `.gdignore`). Violence stays cartoonish: tumbles and dazed stars, no blood.

## Safety (hard rules)
- **S1:** No "GTA", "Grand Theft Auto", "Vice City", "Los Santos", "Liberty City", Rockstar logos or look-alike art anywhere in the game, its title, the README or the itch page. (Mentioning GTA 6 inside the Substack posts is fine.)
- **S2:** The bios are about fictional people only; the human skims them before launch (T028).
- **S3:** No API keys, tokens or live AI calls in the build. Anything in a web build can be read by players.
- **S4:** The itch.io page must be marked as containing cartoon violence.
- Out of scope for v1: a playable driving character, 3D, multiplayer, jointed ragdolls, mobile support (phones only get the "best on desktop" banner), the Arsonist.

## Project facts
- Computer: Windows 11 · Shell: PowerShell 7 · Project folder: `C:\Users\phill\Desktop\ChaosSimulator`
- Engine: Godot **4.7.2-stable** standard, at `C:\Godot\`. `godot` = `C:\Godot\godot.cmd`, which runs the console build so output reaches the terminal. Web templates: 4.7.2.stable (`web_nothreads_release.zip`).
- Run every `godot`, `git` and `python` command in this file with the **PowerShell** tool. Git Bash can't find `godot.cmd` by the bare name `godot`.
- Repo: public GitHub `chaos-simulator` (personal account, via `gh`). Branch `main`.
- Commands:
  - Test: `godot --headless --path . --import; godot --headless --path . res://tests/run_tests.tscn` → last line `N checks, 0 failed`
  - Smoke: `godot --headless --path . --quit-after 600` → no `SCRIPT ERROR` / `ERROR` lines
  - Run: `godot --path .` · Editor: `godot --path . -e`
  - Web export: `New-Item -ItemType Directory -Force build\web | Out-Null; godot --headless --path . --export-release "Web" build/web/index.html`
  - Serve locally: `python -m http.server -d build/web 8000`, then http://localhost:8000 in Chrome and Firefox
  - itch zip: `Compress-Archive -Path build\web\* -DestinationPath build\chaos-web.zip -Force`
- Gotchas learned while testing the plan:
  - A new `class_name` script is unknown until `--import` runs. Without it, the test run can fail or hang.
  - Tests must run as a scene; with `-s` the autoloads don't exist.
  - Write regex patterns as raw strings (`r"\b..."`).
  - Add physics bodies with `call_deferred` inside physics callbacks.

## Talking to the human
They're a comfortable coder who has done one Godot tutorial. Use plain words, explain any Godot term in one line the first time it comes up, give exact commands to copy, and say exactly what they should see on screen. When you finish a task, tell them in one or two sentences what changed and what's next.
