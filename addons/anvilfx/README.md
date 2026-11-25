# AnvilFX

Painted 2D effects for Godot 4, and an editor tab to find them, preview them and drop them into your scene.

AnvilFX adds a tab to the bottom panel of the Godot editor. It shows every effect in your project as an animated
card. Click one to preview it at its real game size, then add it to the selected node with one button, or drag it
straight into the 2D view. The `effects/anvilfx-starter` folder next to `addons` holds four starter effects to try it with.

## What you get

- **An AnvilFX tab** in the bottom panel. Browse by pack or kind, search, and keep favourites.
- **Preview at game size** over a floor colour you pick. Step through frames and choose a single sheet (muzzle,
  flight, hit) or the whole effect.
- **Add to the selected node**, double-click a card, or drag it into the 2D view. Each add is one undo step.
- **A speed control** from 0.25x to 3x that knows each effect's frame rate and warns you when motion will step.
- **A Pieces panel** to toggle, scale, retime, offset or remix each sheet and layer, or split an effect into child nodes.
- **Import your own sprite sheet** (a PNG of frames in a grid) and animate it like the included effects.
- **One line of code** to play an effect from your game. It aims, mirrors, attaches to a marker and frees itself.
- **Hit-stop and camera shake**, built in, with effects that keep playing through the freeze.
- **Three starter scenes** (top-down, isometric, side view) with a camera, a floor and stand-in units to try things on.
- **Install effect packs from their zip.** Drop the zip on the editor, no unzipping.

Effects play without the plugin too: each one is a single `AnvilFXEffect` node, or a ready-made scene you can
instance anywhere.

## The four starter effects

- **Pulse Laser**: muzzle, flight and hit
- **Shell Impact**: dust, sparks and a ground scuff
- **Command Ping**: move and attack markers
- **Repair Beam**: start, loop and stop

## Install

You need Godot 4.3 or later.

**From the Godot Asset Library**

1. Open the **AssetLib** tab in the editor and search for "AnvilFX".
2. Download it, keep everything ticked and press **Install**. That adds `addons/anvilfx/` and
   `effects/anvilfx-starter/` to your project.
3. Open **Project > Project Settings > Plugins** and switch **AnvilFX** on.
4. Open the **AnvilFX** tab at the bottom of the editor.

**From GitHub**

Copy the `addons/anvilfx` folder, and the `effects` folder if you want the starter effects, into your project.
Then enable the plugin as in step 3 above. You can also open this repository itself as a Godot project:
`main.tscn` plays all four effects on a dark floor.

## Use an effect

Pick an effect in the tab and press **Add to selected node**. To play one from code, use its id (the folder name):

```gdscript
AnvilFX.spawn("shell-impact", hit_point)
AnvilFX.spawn("pulse-laser/muzzle", $Muzzle.global_position, {"attach": $Muzzle})
AnvilFX.spawn("shell-impact", hit_point, {"hit_stop": 0.06, "shake": 6})
```

The **Copy code** button in the tab writes the line for whatever you have chosen. `AnvilFX.spawn` takes options for
direction, scale, speed, tint, layer visibility, hit-stop, shake and more. They are listed at the top of
`anvilfx.gd` in this folder.

### Heavy fire

For hundreds of effects a second (a minigun, a swarm's hits), pass `"pool": true`. The effect node comes from a
pool and goes back to it when it ends, so nothing is built or freed during the fight. Fill the pool first, and end
a pooled looping effect with `AnvilFX.release(node)` instead of `queue_free()`:

```gdscript
AnvilFX.warm(["pulse-laser/muzzle", "shell-impact"], 64)   # 64 idle nodes of each, made now
AnvilFX.spawn("pulse-laser/muzzle", $Muzzle.global_position, {"attach": $Muzzle, "pool": true})
```

A pooled node is reused by a later spawn, so don't keep it after it finishes.

## Effect format

Each effect folder holds an `effect.json` and its sprite-sheet atlases. Frames run left to right, then top to
bottom, and every sheet lists its frame rate, pivot, cell size and blend mode (additive or multiply). The player in
`addons/anvilfx/` reads them for you; the JSON is plain, so any engine can read it too.

## More effects

More AnvilFX effect packs: [thepixelgoblin.itch.io](https://thepixelgoblin.itch.io)

## License

MIT. See the `LICENSE` file in this folder. It covers the plugin and the four starter effects.
