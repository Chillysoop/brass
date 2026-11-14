# Brass & Aether

The first playable milestone is an arena sandbox for Windows, built with Godot 4.7.2 and GDScript. Open `project.godot` in Godot and press F6 from `arena.tscn` or F5 from the project.

## Playtest

1. Start with **Two heroes**. The preset schedules Hexwright's **Pull · Farthest** at beat 4 and Warden's **Bash · Nearest** at beat 6. Start the battle and watch the tether bring the distant clockwork within striking distance.
2. **Reset fight**, change Pull's rule to **Nearest**, and compare the target and follow-up. Each tile previews its target in setup and chooses again when it fires.
3. Drag from the tile palette to an empty starting beat, or select a tile and then a beat. Select an equipped tile to move or remove it. **Set all targets** applies a rule to compatible tiles on that lane.
4. Try **Solo hero**, 2× speed, or a layout using Blink. Reset returns to setup and retains the current layout. Changing fixtures loads that fixture's preset.

The simulation runs at 60 ticks per second, with 21 ticks per beat and 12 beats per loop. Same-tick activations run in hero order. The arena is continuous and uses scripted movement and separation, capped displacement, and checked teleport destinations.

The latest design review approved the combat and engineering direction. The progression milestone should use the original Aether Chart mockup as its reference, with the larger branching constellation and side detail panel. Storage and the forge, location runs, and the between-run chart follow the arena milestone.

## Build

With matching Godot export templates installed, create a `build` folder and export **Windows Desktop**. The preset embeds the game data in the x86-64 executable.

Run `tests/arena_sim_test.gd` and `tests/arena_lab_test.gd` with Godot's `--headless --script` options to check the simulation and setup controls.

## Credits

Brass & Aether uses [Godot Engine](https://godotengine.org/license/). The arena backdrop and character sprites were generated with ImageGen. The prompts are in `assets/imagegen-prompts.md`.
