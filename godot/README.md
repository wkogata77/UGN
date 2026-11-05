# Field Command: Godot Port

Native Godot project combining the browser campaign, army management, and
painterly terrain-depth demo. Gameplay and UI are GDScript and Godot Controls;
this is not an embedded browser. The original browser project remains intact
one directory above this folder.

## Open And Play

Tested with **Godot 4.7.2 Standard**, using the Compatibility renderer. No .NET,
Node.js, npm, web server, or third-party Godot add-ons are required to play.

1. Open Godot's Project Manager, choose **Import**, and select `project.godot`
   in this folder.
2. Open the project and allow the initial asset import to finish.
3. Press **F5**. The first screen is your paused campaign at **0.5x** speed.

On this Windows setup, `Play.cmd` runs the game directly and `Open Editor.cmd`
opens the project. Both look for Godot under `Documents/Tools/Godot`, then on
`PATH`. An explicit executable can be supplied to the helper:

```powershell
./tools/launch.ps1 -Mode Editor -Godot "F:/Users/wes/Documents/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"
```

After cloning the repository, the play and verification launchers use Godot's
`--import` command to finish preparing assets before starting. The generated
`.godot/` cache is local and is not included in Git.

The first launch prepares filtered versions of the painted atlases. Prepared
images are then cached under `user://art-cache/` for subsequent launches, and
map changes reuse them in memory. Initial preparation takes longer than later
launches. Current landscape and performance measurements are recorded in
[GRAND_LANDSCAPES.md](GRAND_LANDSCAPES.md).

## Playable Content

**Mincio battlefield polish exercise:** `Battlefield Demo.cmd` opens a paused
12-versus-12 battle at 0.5x, with three corps, reserves, authored farms and
villages, planted orchards, bridge queues, street compression, expanded painted
animation, multi-front melee and spatial battlefield effects. `Grand Battle.cmd`
opens the heavier 20-versus-20 exercise. These exercises do not load or write
campaign saves. Both are also available in the Battle Exercises menu. See
[BATTLEFIELD_POLISH.md](BATTLEFIELD_POLISH.md) for details and measured limits.
New battles cover **5760×3840**, with five river crossings, populated outer
districts and broader deployment fronts. Both campaign and battle views start
at **35° above the ground**; **Q/E** or the right-side arrow buttons change the
angle between 28° and 60°. Existing troop sprites and uniforms are preserved.
See [GRAND_LANDSCAPES.md](GRAND_LANDSCAPES.md) for the shared environment pass.
The performance pass preserves figure counts and runs tactical rules at 30 Hz,
with GPU interpolation between 15 Hz figure-steering samples. Repeatable native
frame-time measurements are available through `tests/performance.gd` (use
`-- --after --long`, adding `--combat` for the crowded fire/melee drill).

**Valeggio visual benchmark:** `Valeggio Preview.cmd` opens an isolated paused
exercise with authored farmland, connected village yards and lanes, refined
woodland/river edges, arch bridges and lighter battle labels. Campaign saves are
not loaded or autosaved by this preview. See [ART_DIRECTION.md](ART_DIRECTION.md#valeggio-benchmark-september-30).

**New: Mantua operational demo.** Run `Mantua Campaign.cmd` for a separate saved
campaign starting with one army. Split and merge forces, manage army confidence,
capture crossings and depots, blockade Mantua, and fight persistent enemy armies
with route-timed reinforcements. Rules, controls, and the demo's historical
limitations are in [OPERATIONAL_CAMPAIGN.md](OPERATIONAL_CAMPAIGN.md).

### Shared And Legacy Content

- Faction arsenals with 22 equipment entries, ten infantry firearms from reserve
  muskets to specialist rifles, weapon-specific reload/accuracy, national field
  guns, howitzer trajectories, captured stores and paid refurbishment. Batteries
  check individual firing lanes and explicit attacks seek clear firing positions.
  See [ARSENAL.md](ARSENAL.md) for mechanics, compatibility and current limits.
- Field-headquarters UI theme: engraved atlas, faction standards, painted
  regimental records, compact command groups and dispatch-style battle reports.
  Slope-aware figure anchoring and contact shadows apply to both maps.
  See [UI_THEME.md](UI_THEME.md) for details and focused native checks.
- Legacy campaigns have one persistent army, two corps of up to four regiments, and an independent
  battlefield general. Corps commanders are attached to their host regiments.
- Real-time campaign movement, patrols, intelligence, paid reconnaissance,
  encounters, reinforcement armies, three battlefield scenarios, and reports.
- Army, Armory, and Officers screens: hiring, officer assignments and promotion,
  regiment recruitment, naming, training, perks, equipment, authorized strength,
  replacements, weapon trading, resupply, and service records.
- Timed formations and gun deployment; movement, facing, queued orders,
  frontlines, run, charge, individual retreat, fall back, halt, rally, skirmisher detachments, and
  carbine cavalry dismounting.
- Arc-limited automatic fire, explicit engagement, terrain and sight checks,
  morale, fatigue, routing, general support, supply wagons, artillery scatter,
  impact markers, firing/reload poses, and displacement-driven troop animation.
  Infantry now has four painted marching poses, a separate idle pose and five
  direction rows with mirroring, for both sides and campaign escorts.
- Cavalry loosens while moving and reforms at rest; cavalry, guns and wagons
  have painted movement frames. Marching preserves formation left/right.
  Battlefield bodies persist while infantry step forward into casualty gaps.
- Edge-based melee contact, opposing contact ranks, and painted bayonet/saber
  cycles for both armies. Engaged regiments stop shooting; depleted front ranks
  refill gradually. See [COMBAT_MOTION.md](COMBAT_MOTION.md).
- Steady figure speeds without slot catch-up bursts, terrain-surface LOS,
  friendly-frontage obstruction, one-time charge impacts, and directional morale
  pressure strongest from the rear. See [BATTLE_ORDERS.md](BATTLE_ORDERS.md).
- Shared building geometry for scenery, blocked shots and town-street routes;
  individual house avoidance, friendly detours and road/slope movement modifiers.
- Enterable farm enclosures, curved orchard hedges and earthwork redans with
  shaped multi-rank garrisons, outward-facing side positions, limited capacity,
  timed manning, directional protection and leave orders. See
  [FORTIFICATIONS.md](FORTIFICATIONS.md).
- Expanded 17280x11520 Italy sector with 18 settlements, five crossings, overview,
  independent marching modes, enemy fatigue and visible-army interception.
- All new battlefields are 5760x3840, four times the preceding version's area.
  The landscape includes wooded flanks, broad ridges, hamlets and connecting
  roads. Valeggio has five crossings; the central crossing remains the objective.
  Troop size, weapon range and walking pace are unchanged. See [LARGE_MAPS.md](LARGE_MAPS.md).
- Corps-oriented headquarters with compact regiment roster and a narrow editor.
  Click a commander portrait to assign an available eligible officer. Officer
  and weapon comparisons, corps capacity, replacement previews and armory batch
  prices are available before purchase.
- Persistent campaign personality preferences and recent-sighting pursuit;
  varied, prioritized native sounds with horizontal battlefield panning.
- Shared musket cracks for infantry and cavalry firearms, distinct bass-heavy
  cannon reports, baked uncompressed effects and a volley peak limiter; camera
  distance changes volume and sharpness, with quiet wind during play.
- Both maps use correctly lit relief meshes, oblique framing, scenery and
  contact shadows, individual painted trees and buildings, grounded sprites,
  textured roads and bridges, shaded water, drifting volley smoke, fog, zoom
  through 6x, minimaps, and a compact battle roster.
- Independent battle exercises, sound settings, dispatches, autosaving,
  native save loading, and version 3 browser JSON import.

Northern Italy is an expanded **illustrative sector**, not the researched,
large 1796 campaign described in the roadmap. The original Danube campaign is
also available under Settings > New Campaign. Full feature status and remaining
limits are in [PORTING.md](PORTING.md).

## Controls

The **Coordinated Defense** battle exercise uses the new army-level tactical AI.
Settings > **AI diagnostics** shows its plan, visible unit intentions and decision
reasons. Rules, architecture and remaining limits are in [BATTLE_AI.md](BATTLE_AI.md).

| Input | Action |
| --- | --- |
| Left-click a unit | Select/inspect |
| Shift/Ctrl-click or Shift-click roster | Add/remove selection |
| Left-drag on either map | Select formations/army without panning |
| Double-click unit or roster entry | Center the camera |
| Right-click ground/enemy | Move / explicitly engage |
| Right-click a fortification shield marker with infantry selected | Reserve, approach, and man the shaped defensive position |
| Leave defensive position tool | Cancel approach / vacate occupied cover |
| Right-hold and drag, then release | Preview each selected formation; center the group at the **press point**, facing the release point |
| Shift-right-click | Queue a destination |
| WASD; middle-drag; Alt-left-drag | Pan camera |
| Campaign overview tool | Frame the expanded region |
| Route / Normal / Slow | Marching pace and fatigue, independent of time speed |
| Mouse wheel; plus/minus tools | Zoom |
| Home | Reset camera |
| Space | Pause/resume |
| Q / E | Lower / raise camera angle |
| 1 / 2 | Select I / II Corps |
| F / H | Engage / halt selected troops |
| C / X / R | Charge / tactical fall back / retreat selected units off the battlefield |
| Touch drag / pinch | Pan / zoom; pointer tool switches inspect and order taps |

Automatic engagement never turns an idle regiment to an enemy behind it.
An explicit Engage command advances into range and turns far enough to acquire
the arc; the regiment then holds its facing. Fighting prevents rest recovery.

Facing drags show individual formation footprints, troop slots, and direction
arrows; red footprints indicate invalid ground. House clicks resolve to nearby
clear ground, not an interior garrison. Simple group moves preserve spacing. Mixed
regiments are spaced by their formation widths and rotate as a
shared frontage; the released and Shift-queued destinations use the same layout
as the preview. The ground anchor stays fixed when the camera moves during a
drag. Escape cancels the preview. Frontline mode previews its own placements.

## Saves And Browser Migration

The native save is `user://campaign.json`, normally at
`%APPDATA%/Godot/app_userdata/Field Command/campaign.json` on Windows. It uses a
versioned JSON envelope, periodic autosaving, and temporary-file replacement.
Loading pauses time. Battle exercises cannot overwrite the campaign.
The previous validated save is retained as `campaign.json.bak`. Startup recovers
it when the primary is missing or invalid. If neither copy validates, autosaving
is disabled and the original files are kept, with a visible warning.
Older native saves are backed up beside the save with the suffix
`.pre-large-maps.bak` before strategic coordinates migrate. The earlier Italy
backup `.pre-expanded-map.bak` is retained where applicable. Existing battles
keep their original terrain dimensions, soldiers, bodies and tactical orders;
only newly started battles use the larger layouts. Save migration runs once.

Browser local storage is not read automatically or deleted. To migrate it,
open the browser game's existing address/port and download its version 3
campaign JSON using the developer-console commands in
[PORTING.md](PORTING.md#exporting-an-existing-browser-save). Then choose
**Settings > Import browser save** in Godot. Keep the exported file as a backup.
Campaign, ongoing-battle, and post-battle-report fixtures generated by the
browser model are tested.

## Verification

`Verify.cmd` imports assets, runs headless simulation tests, then opens a native
game window for graphical verification. It must have a working graphical
desktop; do not run the graphical phase with `--headless`.

```powershell
./tools/launch.ps1 -Mode Verify
```

Individual commands, with `godot` replaced by your executable path:

```text
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/simulation.gd
godot --headless --path . --script res://tests/regression.gd
godot --headless --path . --script res://tests/maps.gd
godot --headless --path . --script res://tests/terrain_relief.gd
godot --headless --path . --script res://tests/combat_motion.gd
godot --headless --path . --script res://tests/battle_orders.gd
godot --headless --path . --script res://tests/battle_ai.gd
godot --headless --path . --script res://tests/polish.gd
godot --headless --path . --script res://tests/firing_audio.gd
godot --headless --path . --script res://tests/town_movement.gd
godot --path . -- --verify
godot --path . -- --verify-maps
godot --path . -- --verify-cover
godot --path . -- --verify-ai
godot --path . -- --verify-slopes
godot --path . -- --verify-animation
```

The native graphical runner checks inputs, scene pixels, animation, camera
framing, scenario changes, headquarters tabs, resizing, and exercise isolation.
Screenshots and renderer/frame timing results go to `test-results/`. Tests use
in-memory campaigns and separate temporary files, not the player's native save.
`--verify-cover` runs the focused native fortification UI checks,
including shield-marker input and desktop/narrow occupation screenshots.

The original browser regression suite remains `npm test` from the parent folder.

Campaign-order follow-up (September 25): movement resumes after forced retreat,
without waiting for full recovery. Reorganizing armies march at 70% pace, and
victors pause for two simulation seconds before pursuit. Both sides share these
rules. Right-click queues orders during withdrawal or that brief pause; the
player's real save was also replayed with native mouse input without altering
the saved file. See [OPERATIONAL_CAMPAIGN.md](OPERATIONAL_CAMPAIGN.md).

Fortification follow-up (September 25): **432 checks passed** (228 shaped-garrison,
151 polish and 53 native visual/input). Stone enclosures, curved hedgerows and
earthworks share their visible outline with their multi-rank troop positions.
Desktop/mobile captures and implementation boundaries are in
[FORTIFICATIONS.md](FORTIFICATIONS.md).

Reload/cadence follow-up (September 24): **360 focused checks passed** (208 native
animation and 152 simulation). Walking cadence is one-third slower with no change
to travel speed. Matching planted loading frames restore infantry and mounted
reloads in every direction, and gun crews follow their actual longer cooldown.
Original walking, firing and melee art is retained. Asset provenance and prompts
are in [RELOAD_ANIMATION.md](RELOAD_ANIMATION.md); native captures are
`test-results/reload-*.png`. Performance was not re-profiled for this follow-up;
the unresolved frame-time results below still apply.

Animation playback verification (September 24): **615 focused checks passed**
(155 native animation, 149 simulation, 87 combat motion, 82 battle orders and
142 operations). Original sprites are preserved; walking uses short passing-pose
transitions, starting/stopping eases to idle, and combat has directional recoil
and guard/strike/recovery timing. Movement takes priority over lingering reload
poses. Playback interpolates simulation ticks and freezes on pause. Details and
scope limits are in [INFANTRY_ANIMATION.md](INFANTRY_ANIMATION.md).
The separate active-battle profile still fails both timing budgets: the latest
454-sprite sample measured 29.0 ms median and 62.0 ms p95 against targets of
20/33.4 ms. A comparison using the previous animation shader also failed
(48.0/67.8 ms); local timings varied substantially, so this pass does not claim
a frame-rate improvement. Logs are `test-results/animation-profile.log` and
`test-results/animation-baseline-profile.log`.

Command-rail theme verification (September 24): **524 focused checks passed**
(192 native theme, 79 native campaign, 23 native fortification, 82 headless
battle-order and 148 headless polish). The atlas-textured bottom rail uses
illustrated regiment cards, officer portraits, live strength and supply counts,
corps-selection highlights and framed order controls. Battle and operational
campaign rails fit 118 pixels on desktop and 156 on narrow windows. Tests cover
320-1440-pixel viewports, eight corps, card clicks, additive selection, disabled
orders and access to scrolled controls. See [UI_THEME.md](UI_THEME.md) and
`test-results/theme-battle-desktop.png`. Full renderer performance was not retested.

Hillside-gradient verification (September 24): **801 headless checks passed**
(simulation 149, expansion 42, terrain relief 42, combat motion 66, battle orders
82, battle AI 79, operations 142, polish 148 and town movement 51). **167 focused
native checks passed** (slopes/selection 67, campaign 77 and fortifications 23).
The relief suite covers every battle map and campaign theater, both ground
triangles, slope/normal continuity, relief toggling and bridge decks. Native
captures check grounded figures, movement, field overlays and narrow viewports.
The terrain pass rounds hill shoulders and lowers small knolls; physical heights
remain shared by rendering, line of sight and slope movement penalties. Field
overlays now reuse ground triangles rather than intersecting them. No per-frame
formation smoothing was added. See `test-results/slope-*.png` and [UI_THEME.md](UI_THEME.md).
The full graphical/performance suite and browser suite were not rerun; the older
frame-time budget failures below are not claimed fixed.

The focused firing-audio check can also run natively with
`godot --path . --script res://tests/firing_audio.gd -- --playback`. It exercises
real playback, simultaneous-volley limiting, mute/pause and voice cleanup.
Generation notes are in [assets/audio/README.md](assets/audio/README.md).

Battle-AI verification (September 20): **79 AI, 149 baseline simulation, 42 expansion,
66 combat-motion, 81 battle-order and 148 foundation/polish checks passed** (565
headless checks), plus **30 focused native UI checks**. The defensive exercise,
reserve response, withdrawal and diagnostic inspectors were captured on desktop
and narrow screens. The maximum scheduled AI decision step in this native drill
was 1.55 ms; this is not a full renderer benchmark. The full graphical/performance
suite and browser tests were not rerun for this pass; the earlier renderer budget
failures below are not claimed fixed.

Fortification-marker verification (September 15): **149 baseline simulation,
148 foundation/polish, and 23 focused native checks passed**. Desktop and narrow
screenshots confirm marker placement, occupation, and readable hover details.
The full graphical/performance suite was not rerun for this focused change.

Previous complete verification (September 15, town-movement correction): **149 baseline
simulation, 42 expansion regression, 66 combat-motion, 81 battle-order, 144
foundation/polish, and 51 town-movement checks passed** (533 headless checks).
The native runner passed **396 functional checks**, with **two frame-time budget
failures**; `Verify` is not fully green. These are 929 passing checks out of 931.
The native suite produced 66 captures, including town approach/arrival on desktop
and mobile, wall approach and
occupation, desktop/narrow replacement quotes, charge run-up,
steady wheeling, rear-fire warnings, blocked shots, individual retreat, and melee on desktop/mobile,
rank replacements, commander selection, wagon movement, bridge approaches,
expanded campaign overview, group-facing previews, terrain winding, hillside
grounding, scenery alpha/placement, volley smoke, infantry idle/opposite-step
views, and shadow-pixel checks.
The unchanged browser suite last passed its 106 tests during the original port.
The latest active-battle sample at 1440x900 with 454 visible sprites measured
25.6 ms median, 34.3 ms p95, and 48.2 ms worst frame time on the RTX 3070 Ti.
This misses the 20 ms median / 33.4 ms p95 targets. Avoidance optimizations reduced
an initial 36.2 ms median / 116.9 ms p95 measurement, but more work remains.
The previous foundation pass measured 19.9 ms median / 30.8 ms p95 with 396
visible sprites. Restored movement brings more troops into view, so these are
not identical workloads; the current change does not claim a performance win.
Timing varies with system load; an earlier run included a 905 ms outlier. These
measurements are a baseline for this machine and scenario, not a
hardware-independent promise. Automated runs ignore window-focus pausing and
verify that battle time advances during the measured sample; normal play still
pauses on focus loss.

## Exporting

A Windows Desktop preset is included. To build a distributable executable,
install the **matching export templates** through Godot's export-template
manager, then use Project > Export. Templates were not installed on this machine
when the port was created, so no standalone release executable is claimed.
The project and `Play.cmd` work with your installed Godot without templates.

## Maintenance

`tools/export-browser-data.mjs` copies the existing art, fonts, Lucide icons,
and baseline catalog data. `tools/export-browser-fixtures.mjs` regenerates
cross-engine save fixtures. These optional developer tools require the parent
project's npm dependencies; normal Godot play does not.

Original art provenance remains in [../docs/ASSETS.md](../docs/ASSETS.md).
The native environment refresh, saved assets, and generation prompts are in
[ART_DIRECTION.md](ART_DIRECTION.md).
The infantry-first frame animation and its assets/prompts are documented in
[INFANTRY_ANIMATION.md](INFANTRY_ANIMATION.md).
The expanded map, independent formation movement, bodies, headquarters redesign,
video observations and new asset prompts are in [POLISH_PASS.md](POLISH_PASS.md).
The current building/cover, passage, AI, management, cache, audio and recovery
pass is documented in [BATTLEFIELD_FOUNDATIONS.md](BATTLEFIELD_FOUNDATIONS.md).
Remaining work from the full review is tracked in
[the implementation checklist](../feature%20plans/native-polish-implementation.md).
Font and icon licenses are bundled beside their assets. No Ultimate General
artwork or extracted game files are included.
