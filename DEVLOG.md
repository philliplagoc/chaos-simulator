# Devlog

One dated entry per session: what we built, what broke, one interesting decision.
This becomes the Substack draft.

## 2026-10-16
- **Built:** Godot 4.7.2 project with the Compatibility renderer, `Sim` and `EventBus` autoloads, a headless test runner.
- **Broke:** nothing yet.
- **Interesting decision:** every random number in the game comes from one seeded generator in `Sim`, so a seed replays the same starting city.

## 2026-10-17
- **Built:** finished Phase 0. Godot is on PATH, the Web export templates are installed, the code is on GitHub (https://github.com/philliplagoc/chaos-simulator), and the Kenney CC0 art packs are stored in `art/kenney/`.
- **Broke:** `godot` isn't found from Claude Code's `!` prompt, because that runs Git Bash, which can't find `godot.cmd` by name. Running Godot from PowerShell works. Closing the editor before the template download finished meant installing the templates twice.
- **Interesting decision:** the raw art packs sit behind a `.gdignore` file, so Godot doesn't import 2,000+ images we won't use. Only the dozen sprites picked in Phase 10 get copied into `art/sprites/`.
