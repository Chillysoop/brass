# Brass & Aether

The Windows playtest includes Easy, Medium, and Hard expeditions in Brass Frontier, Glass Foundry, and Crown Relay, plus a separate practice arena. Open `project.godot` in Godot 4.7.2 and press F5.

## Playtest

From the title screen, choose **New Expedition**, select **Brass Frontier**, and start on **Easy** to draft a hero, relic, and starting tile. You can enter an optional seed on the difficulty screen. Win the opening fight, pick rewards, then travel a seeded route through battles, elites, shops, events, and a rest site. Health, relics, gold, and tile layouts carry between stops. The game saves between fights and after loadout changes. **Continue** picks up from the saved checkpoint.

Defeat the Tollkeeper on Easy to bank Aether Marks and unlock **Medium**. Open the **Aether Chart** from the title or after a run to inspect prerequisites and spend Marks on permanent upgrades between expeditions.

Medium starts solo. After the Tollkeeper, take a Legendary tile into your build and recruit a second hero with a starter tile. Both lanes fire on the same beat clock. Push or pull the Gilded Marshal to expose its armor, then land a hit with the other hero before it closes. Defeating the Marshal unlocks Brass Frontier Hard and Glass Foundry Easy.

Glass Foundry Easy is a solo route that ends at the Crucible Twins. Hunters prioritize the hero with the most ranged tile damage. Skirmishers prioritize the hero with the lowest current HP. The clear awards Aether Marks and records the unlock for Glass Foundry Medium.

Glass Foundry Medium starts solo. After the Crucible Twins, take a Legendary tile and recruit a second hero for the next leg. The Prism Warden pressures the hero with the most ranged damage and the hero with the lowest current HP. Push or pull to open its ward, then hit it with the other hero within three beats. A clear records the unlocks for Glass Foundry Hard and Crown Relay Easy.

Glass Foundry Hard adds the Tempering Causeway and a third hero after the Prism Warden. When the Tempered Colossus charges Forge Sweep, push or pull it with one hero, crack its guard with a hit from a second hero, and shatter it with a hit from the third. Shattering the guard cancels Forge Sweep for the rest of the fight.

Crown Relay Easy is a solo expedition through the skybridge outposts. Relay Guards shield nearby allies. Defeat the guard or pull one enemy away from the other to break the link. Time a Bash during the Relay Captain's windup to interrupt the charged strike. The first clear records the unlock for Crown Relay Medium.

Crown Relay Medium starts solo. Take a Legendary tile after defeating the Relay Captain and recruit a second hero for the High Relay Gate. While the Relay Marshal charges, separate the pair with one hero, then Bash the Marshal with your other hero before the link returns. A clear earns the unlocks for Crown Relay Hard and Moonwreck Docks Easy.

Crown Relay Hard adds the Crown Causeway and a third hero after the Relay Marshal. During Crown Charge, assign different heroes to break the Left and Right Guards' links. Bash the Crown Regent with your third hero while both links are down. Each link has its own reconnect timer. Defeating a guard removes its link from the fight.

Brass Frontier Hard has three legs. Recruit after the Tollkeeper and the Gilded Marshal. When the Iron Regent raises its seals, land damaging hits from three different heroes within four beats to break them.

## Arena practice

1. Start with **Two heroes**. The preset schedules Hexwright's **Pull · Farthest** at beat 4 and Warden's **Bash · Nearest** at beat 6. Start the battle and watch the tether bring the distant clockwork within striking distance.
2. **Reset fight**, change Pull's rule to **Nearest**, and compare the target and follow-up. Each tile previews its target in setup and chooses again when it fires.
3. Drag from the tile palette to an empty starting beat, or select a tile and then a beat. Select an equipped tile to move or remove it. **Set all targets** applies a rule to compatible tiles on that lane.
4. Try **Solo hero**, 2× speed, or a layout using Blink. Reset returns to setup and retains the current layout. Changing fixtures loads that fixture's preset.
5. Open **Tile storage** to find three touching Bash tiles. Use **Combine → Yes**, inspect any rarity, then confirm one of the two upgrades offered at the next rarity. Select the result and use **Transfer selected to timeline** to equip it.
6. Choose **Forge practice** from the fixture picker to start with three Epic Sunwalls on Warden's lane. Combine them into either Legendary, then try the result in battle or move it into storage. To move a tile to storage, select it on the timeline, open **Tile storage**, then choose an empty starting cell.

The simulation runs at 60 ticks per second, with 21 ticks per beat and 12 beats per loop. Same-tick activations run in hero order. The arena is continuous and uses scripted movement and separation, capped displacement, and checked teleport destinations.

The practice palette supplies unlimited base tiles. Switching practice fixtures resets their inventory.

## Build

With matching Godot export templates installed, create a `build` folder and export **Windows Desktop**. The preset embeds the game data in the x86-64 executable.

Run the scripts under `tests/` with Godot's `--headless --script` options to check practice combat, setup controls, and the Frontier run.

## Desktop launcher

On Windows, `tools/Install-DesktopShortcut.ps1` installs the launcher in `%USERPROFILE%\Games\Brass Aether` and creates the **Brass & Aether** desktop shortcut. The launcher opens the cached game immediately and checks the project's GitHub `main` branch in the background. An update takes effect the next time you open the game. The updater uses Git, Godot 4.7.2, and the matching Windows release template.

## Credits

Brass & Aether uses [Godot Engine](https://godotengine.org/license/). The title and expedition illustrations, arena and map backdrops, and character sprites were generated with ImageGen. The prompts are in `assets/imagegen-prompts.md`.
