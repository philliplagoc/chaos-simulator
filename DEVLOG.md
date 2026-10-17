# Devlog

One dated entry per session: what we built, what broke, one interesting decision.
This becomes the Substack draft.

## 2026-10-16
- **Built:** Godot 4.7.2 project with the Compatibility renderer, `Sim` and `EventBus` autoloads, a headless test runner.
- **Broke:** nothing yet.
- **Interesting decision:** every random number in the game comes from one seeded generator in `Sim`, so a seed replays the same starting city.

## 2026-10-17
- **Built:** finished Phase 0. Godot is on PATH, the Web export templates are installed, the code is on GitHub (https://github.com/philliplagoc/chaos-simulator), and the Kenney CC0 art packs are stored in `art/kenney/`.
- **Broke:** `godot` isn't found from Claude Code's `!` prompt, because that runs Git Bash, which can't find `godot.cmd` by name. Running Godot from PowerShell works. The first editor session ended without the templates installed, so we opened the editor a second time.
- **Interesting decision:** the raw art packs sit behind a `.gdignore` file, so Godot doesn't import 2,000+ images we won't use. Only the dozen sprites picked in Phase 10 get copied into `art/sprites/`.

## 2026-10-17 (Phase 1)
- **Built:** a throwaway performance spike: dots finding paths on a street grid with `AStarGrid2D`, exported as a single-threaded web build and uploaded as a draft on itch.io.
- **Broke:** nothing. Chrome held 60 FPS at 60, 120 and 240 dots locally, and 60 FPS on itch. Firefox wasn't tested (not installed); it still needs a check before launch.
- **Interesting decision:** we tested the scariest unknown, browser frame rate, before building any of the game. With 4x headroom at 240 dots, the full 40 citizens + 20 cars stay in, and the 30 + 15 fallback isn't needed.
