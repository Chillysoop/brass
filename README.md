# Brass & Aether

The Windows playtest covers the arena, tile storage, and the Bash forge family. Open `project.godot` in Godot 4.7.2 and press F5.

## Playtest

1. Start with **Two heroes**. The preset schedules Hexwright's **Pull · Farthest** at beat 4 and Warden's **Bash · Nearest** at beat 6. Start the battle and watch the tether bring the distant clockwork within striking distance.
2. **Reset fight**, change Pull's rule to **Nearest**, and compare the target and follow-up. Each tile previews its target in setup and chooses again when it fires.
3. Drag from the tile palette to an empty starting beat, or select a tile and then a beat. Select an equipped tile to move or remove it. **Set all targets** applies a rule to compatible tiles on that lane.
4. Try **Solo hero**, 2× speed, or a layout using Blink. Reset returns to setup and retains the current layout. Changing fixtures loads that fixture's preset.
5. Open **Tile storage** to find three touching Bash tiles. Use **Combine → Yes**, inspect any rarity, then confirm one of the two upgrades offered at the next rarity. Select the result and use **Transfer selected to timeline** to equip it.
6. Choose **Forge practice** from the fixture picker to start with three Epic Sunwalls on Warden's lane. Combine them into either Legendary, then try the result in battle or move it into storage. To move a tile to storage, select it on the timeline, open **Tile storage**, then choose an empty starting cell.

The simulation runs at 60 ticks per second, with 21 ticks per beat and 12 beats per loop. Same-tick activations run in hero order. The arena is continuous and uses scripted movement and separation, capped displacement, and checked teleport destinations.

The practice palette supplies unlimited base tiles for testing. Switching fixtures resets the practice inventory. The location run and between-run Aether Chart are the next milestone.

## Build

With matching Godot export templates installed, create a `build` folder and export **Windows Desktop**. The preset embeds the game data in the x86-64 executable.

Run `tests/arena_sim_test.gd` and `tests/arena_lab_test.gd` with Godot's `--headless --script` options to check the simulation and setup controls.

## Desktop launcher

The **Brass & Aether** desktop shortcut checks the project's GitHub `main` branch when launched. It builds new revisions in a separate per-user cache and keeps the last working build available for offline play. The updater uses Git, Godot 4.7.2, and the matching Windows export templates.

## Credits

Brass & Aether uses [Godot Engine](https://godotengine.org/license/). The arena backdrop and character sprites were generated with ImageGen. The prompts are in `assets/imagegen-prompts.md`.
