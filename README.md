# Emergent Chaos Simulator

A top-down "god view" sim of a tiny city district. Forty citizens with jobs,
needs and bios go about their day while twenty cars (mostly) obey the lights.
Drop a Car Thief or a Road Rager and watch unscripted chain reactions:
stolen cars, pile-ups, burst hydrants, exploding fuel barrels and citizens
sent tumbling across the street.

Built with Godot 4.7 (GDScript) and Claude Code. Free to play in a desktop
browser on itch.io.

## Controls

| Input | What it does |
|---|---|
| Drag (left or middle mouse) | Pan the map |
| Mouse wheel | Zoom |
| Click a citizen | Inspector card (name, job, goal, needs, bio) |
| Bottom bar, then click the map | Drop a Car Thief or a Road Rager |
| Pause / 1x / 3x | Sim speed |
| Reset | Rebuild the city from the same seed |
| New Seed | A brand new city |
| Right-click | Test danger (people scatter) |
| F | Debug: launch a speeding car at the nearest object |
| F2 | Show FPS and agent count |
| F3 | Show every citizen's current goal |

## How it works (short version)

- `Sim` (autoload) owns the only random number generator, the clock
  (1 real second = 2 sim minutes, a day lasts 12 real minutes) and the map.
- `EventBus` (autoload) has one signal: `danger(position, radius, kind)`.
  Agents never call each other; they announce danger and react to danger by
  their own rules. Chain reactions come from that, not from a script.
- Cars and citizens follow `AStarGrid2D` paths. A hard hit swaps them for a
  `RigidBody2D` (`ImpactBody`) that tumbles or spins out, then hands control back.
- Citizens choose goals by utility scoring (`CitizenBrain`): work, home,
  cafe, bank, shop, park, deliveries.

## Run it

```powershell
godot --path .                                                     # play
godot --headless --path . --import; godot --headless --path . res://tests/run_tests.tscn   # tests
godot --headless --path . --export-release "Web" build/web/index.html                       # web build
```

## Credits

- Art: [Kenney](https://kenney.nl) (CC0): Racing Pack, Top-down Shooter, Roguelike Modern City.
- Engine: [Godot](https://godotengine.org) (MIT).
