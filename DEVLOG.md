# Devlog

One dated entry per session: what we built, what broke, one interesting decision.
This becomes the Substack draft.

## 2026-10-16
- **Built:** Godot 4.7.2 project with the Compatibility renderer, `Sim` and `EventBus` autoloads, a headless test runner.
- **Broke:** nothing yet.
- **Interesting decision:** every random number in the game comes from one seeded generator in `Sim`, so a seed replays the same starting city.
