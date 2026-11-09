# Godot Asset Library submission: AnvilFX

Prepared 2026-11-08. Nothing here has been pushed or submitted. This file is not part of the Asset Library download
(`.gitattributes` leaves it out).

## Form fields (godotengine.org/asset-library/asset/submit)

| Field | Value |
|---|---|
| Asset Name | AnvilFX |
| Category | Addons > 2D Tools |
| Godot version | 4.3 (the plugin targets 4.3 and later; see "Tested on" below) |
| Version | 1.6 (matches `addons/anvilfx/plugin.cfg`) |
| Repository host | GitHub |
| Repository URL | `https://github.com/<ACCOUNT>/anvilfx` (placeholder: fill in after step 1 below) |
| Issues URL | `https://github.com/<ACCOUNT>/anvilfx/issues` (or leave empty) |
| Download Commit | full 40-character hash of the commit on `main` you want to publish (`git rev-parse HEAD`) |
| Icon URL | `https://raw.githubusercontent.com/<ACCOUNT>/anvilfx/main/icon.png` (must be raw.githubusercontent.com, not github.com; 256x256) |
| License | MIT |

Previews (up to three, type Image). Use raw links like the icon, from `media/` in the repo:
`media/catalogue.png`, `media/pulse-laser.gif`, `media/repair-beam.gif`.
If the form rejects a GIF, use `catalogue.png` alone.

### Description (plain text; the form has no Markdown)

```
AnvilFX adds an editor tab for browsing, previewing and placing painted 2D effects in Godot 4.

Open the AnvilFX tab in the bottom panel to see every effect in your project as an animated card. Preview an effect at its real game size over a floor colour you choose, step through its frames, then add it to the selected node with one button, by double-clicking its card, or by dragging it into the 2D view. Each add is a single undo step.

Features:
- Search, browse by pack or kind, and keep favourites.
- A speed control from 0.25x to 3x that warns when motion will step or frames will be skipped.
- A Pieces panel to toggle, scale, retime, offset or remix each sheet and layer, or split an effect into child nodes.
- Import your own sprite sheet (a PNG of frames in a grid) and animate it like the included effects.
- One line of code from your game: AnvilFX.spawn("shell-impact", hit_point) aims, mirrors, attaches to a marker and frees itself. The Copy code button writes the line for you.
- Hit-stop and camera shake built in, with effects that keep playing through the freeze.
- Three starter scenes (top-down, isometric, side view) with a camera, a floor and stand-in units.
- Install effect packs straight from their zip: drop it on the editor.

Four starter effects are included: Pulse Laser, Shell Impact, Command Ping and Repair Beam. Effects play without the plugin as well: each is a single AnvilFXEffect node or a ready-made scene.

Install: download from the AssetLib tab, keep everything ticked, then enable AnvilFX under Project > Project Settings > Plugins. More effect packs: thepixelgoblin.itch.io

MIT licensed. Godot 4.3 or later.
```

## What is in the repo

- `addons/anvilfx/`: the plugin as shipped in v1.6, plus a copy of `LICENSE` and `README.md` (the Asset Library
  guidelines recommend this).
- `effects/anvilfx-starter/`: the four starter effects, where the plugin looks for effect packs (`res://effects/<pack>/`).
- `project.godot`, `main.tscn`, `main.gd`: opening the repo as a project plays all four effects on a dark floor.
- `media/`: the README's images. `media/.gdignore` stops Godot importing them.
- `.gitattributes`: the Asset Library download keeps only `addons/`, `effects/` and `LICENSE`.

## Changes from the shipped plugin

Only comments and examples that named paid effects or private modules, so the code behaves the same:

- Doc-comment examples in `anvilfx.gd`, `effect.gd`, `sheet_player.gd`, `sample_player.gd` used paid-pack effect ids
  and a private pack path; they now use the starter effects.
- Comments in `dock/brand.gd`, `dock/dock.gd`, `dock/installer.gd` named private modules ("store_theme",
  "shop_links") and "the store zip"; reworded.
- `effects/anvilfx-starter/shell-impact/effect.json`: its summary said how the effect was made; now just "painted".
- Left as is on purpose: the **Get more packs** button and `SHOP_URL` open `thepixelgoblin.itch.io`, and **Send
  feedback** opens the AnvilFX community board on itch. Swap `FEEDBACK_URL` in `addons/anvilfx/dock/dock.gd`
  for the GitHub issues page if you would rather feedback land in the repo.
- Left as is: the installer still accepts packs built under the old addon name (`addons/spritestack/`).

## Checks run (2026-11-08)

- Searched the whole tree for private paths, repo names, keys and tokens, tool or model names, store licence text,
  prices and paid-pack effect ids: nothing found. The only web addresses are `thepixelgoblin.itch.io` and
  `thepixelgoblin.itch.io/anvilfx/community`.
- Headless Godot 4.7.2: project import and editor load with the plugin enabled, the library finds the four effects,
  every effect and sheet spawns, the dock builds, and `main.tscn` runs 180 frames. Results are in the final report.
- `git archive` of the commit holds only `addons/`, `effects/` and `LICENSE`.

## Tested on

Godot 4.7.2 (headless). Not run on 4.3 itself; the 4.3 floor comes from the plugin's existing store listing. If you
want certainty before choosing "4.3" in the form, open the repo in Godot 4.3 once.

## Checklist for Zach

1. Read `README.md`, look at `icon.png`, and decide whether you are happy with the repo as it stands.
2. On GitHub create a **public** repository, for example `anvilfx`, under the account you want to publish with.
   Do not add a README or licence there (the repo already has them). Do not use `vfx-forge`; it stays private.
3. In `/Users/zach/Projects/anvilfx-oss`:
   ```
   git remote add origin https://github.com/<ACCOUNT>/anvilfx.git
   git push -u origin main
   ```
4. Optional: swap `FEEDBACK_URL` (see above) and add a repo description and topics (`godot`, `godot4`,
   `vfx`, `2d`, `editor-plugin`).
5. Open the repo's raw icon link in a browser to confirm it loads:
   `https://raw.githubusercontent.com/<ACCOUNT>/anvilfx/main/icon.png`.
6. Log in at godotengine.org/asset-library, open **Submit Assets**, fill the table above (Download Commit =
   `git rev-parse HEAD` after pushing), press **Submit**. Review takes up to a few days.
7. After it is approved, put the Asset Library link on the itch page and in the README if you like. A later
   version needs a new commit hash on the asset's edit page.
