# Formation Movement And Melee

The [October 25 battlefield pass](BATTLEFIELD_POLISH.md) extends contact
placement to simultaneous opposing fronts and divides each regiment's attack
strength between those fronts. It also adds bridge queues and gradual street
compression while preserving the movement and replacement behavior below.

September 10, 2026. This pass supersedes the fixed-gap casualty behavior in [POLISH_PASS.md](POLISH_PASS.md), following the request for infantry to step up after losses.

The later [battle-orders pass](BATTLE_ORDERS.md) replaces trail-based formation
loosening and catch-up acceleration with steady per-regiment walking speeds,
and adds charge impacts, individual retreat, improved LOS and directional morale.
Verification figures below describe this earlier melee/art pass, not the latest run.

## Implemented

- Corrected the lateral sign in the moving formation's path-following coordinates. Standing and marching now agree on left/right; changing pace does not send soldiers across their own files. Existing gradual turns and independent cavalry movement remain.
- Infantry replacements advance within their own file at walking pace. Stable soldier identities are separate from occupied formation slots. A vacancy propagates toward the rear, without recentering every survivor. Bodies remain at the actual death location. Slot assignments persist in native saves and are validated on import.
- Formation-edge contact uses oriented bounds, including oblique and flank approaches. Advancing centers stop at contact, not at the opposing center or an arbitrary 22/45-unit radius. Small formations and saber cavalry use the same physical-contact stop.
- Contact is established for both armies before combat is resolved. An engaged regiment fights in melee only: no musket/cannon shots, ranged effects, or ammunition expenditure. Firing arcs do not prevent a defender fighting back in close combat. Saber-only cavalry cannot fire at a nearby but out-of-contact target. Gun crews defend with reduced melee power rather than cannon damage.
- Individual infantry and cavalry gradually form opposing contact ranks and face the opponent. Front ranks have slight independently timed lunges and weight shifts; rear ranks guard/parry and step forward after losses. Both infantry and cavalry refill their current contact frontage while engaged; outside melee, only infantry refill ordinary line/column files.
- Painted guard, strike, and recovery frames for French/Austrian infantry and cavalry. Bayonets and sabers replace shooting poses; frames are independently phased from simulation time and freeze on pause. Leaving contact restores normal movement/idle frames.
- Fall Back and ordinary move-away orders can disengage. Contact reveals a previously hidden opponent at close quarters.

## Boundaries

Damage, strength, morale and command remain regiment-level, not individual-soldier combat simulation. Not every rear-rank soldier can physically reach an opponent: those models guard and support rather than shooting through the front ranks. The closest opponent determines a regiment's primary visual contact line; encirclement and several intersecting melee fronts still need broader individual contact allocation. Existing buildings remain cosmetic and are not formation-aware obstacles. Square formation keeps its perimeter gaps outside melee; line/column infantry refill files. Dedicated gun-crew hand-to-hand art and eight-direction blends remain future work. The new art retains three painted directions plus side mirroring, not fully skeletal 3D animation.

## Verification

- `tests/combat_motion.gd`: handedness at six bearings for foot and mounted troops, file preservation while marching, gradual rank replacements, repeated losses, save validation, frontal/oblique/flank/rear contact, mutual melee, zero ammunition use, spacing, fatigue, withdrawal, small formations, saber-only behavior and gun-crew defense.
- `tests/regression.gd`: revised casualty acceptance checks and replacement assignment round-trip, plus prior campaign/marching/cavalry regressions.
- `tests/visual.gd`: native rendered infantry/cavalry melee on desktop/mobile, dedicated atlas poses, actual troop-pixel changes, pause freezing, persistent bodies and leaving melee poses, in addition to the full existing visual/input suite.
- `Verify.cmd` now includes the combat-motion suite. Results and screenshots are under `godot/test-results/`. Final run counts are recorded in the README.

Final verification: **587 checks passed** (149 simulation, 42 expansion, 66 combat-motion, 330 graphical/input), with **52 native screenshots**. The final five-second active-battle sample at 1440x900 measured 11.7 ms median, 21.7 ms p95, and 29.6 ms worst on the local RTX 3070 Ti. These are machine/load-specific measurements, not a universal performance guarantee.

## Art Provenance

Built-in image generation was used, not the API/CLI fallback. Original output directory: `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/`.

Selected project assets:

| Project path | Generated original |
| --- | --- |
| `godot/assets/infantry-melee-french-v2.png` | `exec-1caf339c-73df-446a-a160-efb67ac65287.png` |
| `godot/assets/infantry-melee-austrian-v2.png` | `exec-f9676f5e-4346-4514-938e-dfcfd6b2ba79.png` |
| `godot/assets/cavalry-melee-french-v1.png` | `exec-bd3f28d0-7564-4bc7-a6a0-0be79d091c56.png` |
| `godot/assets/cavalry-melee-austrian-v1.png` | `exec-2727abd5-7f7a-4c9d-ab60-b98c45deb735.png` |

The infantry v1 drafts (`exec-a79c555d-6766-4cb0-b65b-3e601ec9addf.png` and `exec-e1b2cd02-774f-4e39-a17a-0eddcdbbf09d.png`) were revised for atlas spacing and are not loaded by the renderer. Existing walk atlases supplied uniform/style references. Original movement art was not replaced.

Runtime registration chroma-keys the source and aligns frames beneath the body, retaining room for extended weapons; atlases are cached and batched. As with the existing art, runtime preparation adds startup work but does not run during each animation frame.

## Exact Prompts

### Infantry French first pass

Use case: historical-scene. Asset type: game sprite animation atlas. Reference image is the existing French infantry walk atlas: preserve exactly its painted miniature aesthetic, blue Napoleonic coat with red cuffs, white crossed belts and trousers, black bicorne and brown pack. Create a NEW melee-only 3-column by 3-row atlas, square image, equal cells, nine complete isolated soldiers. Columns: bayonet guard with musket across body, decisive two-handed bayonet thrust with arms extended, recovering/parrying with musket raised diagonally. No shooting poses, no muzzle flashes, no smoke. Rows: right-facing side view, rear view facing away, front view facing camera. Each cell one identical soldier, same camera scale and boot baseline; full body and complete musket/bayonet inside its own cell with generous empty margins. Clearly different arm and leg poses between frames but consistent body and uniform. Painted high-quality strategy-game sprites, crisp readable silhouettes. Solid pure magenta #ff00ff background matching reference for chroma key. No grid lines, text, scenery, labels, blood, or other people.

### Infantry Austrian first pass

Use case: historical-scene. Asset type: game sprite animation atlas. Reference image is the existing Austrian infantry walk atlas: preserve exactly its painted miniature aesthetic, white Napoleonic coat with green cuffs and collar, white crossed belts and trousers, tall black cap with brass plate and green pompom, and brown pack. Create a NEW melee-only 3-column by 3-row atlas, square image, equal cells, nine complete isolated soldiers. Columns: bayonet guard with musket across body, decisive two-handed bayonet thrust with arms extended, recovering/parrying with musket raised diagonally. No shooting poses, no muzzle flashes, no smoke. Rows: right-facing side view, rear view facing away, front view facing camera. Each cell one identical soldier, same camera scale and boot baseline; full body and complete musket/bayonet inside its own cell with generous empty margins. Clearly different arm and leg poses between frames but consistent body and uniform. Painted high-quality strategy-game sprites, crisp readable silhouettes. Solid pure magenta #ff00ff background matching reference for chroma key. No grid lines, text, scenery, labels, blood, or other people.

### Infantry French selected revision

Edit this melee sprite atlas for production registration. Preserve the beautiful painted French Napoleonic infantry design and the guard/thrust/parry concept. Important correction: strict 3 by 3 equal square cells, all characters including bayonets must remain at least 35 pixels INSIDE their own cell. Scale ALL nine characters down to the SAME smaller body scale to fit the long horizontal bayonet completely within the middle cell. Give each row generous blank magenta gutters so no bayonet touches the row above. Keep the torso center and boot baseline aligned across each row. Rows must be genuinely directional: row one side facing RIGHT (bayonet thrusts right); row two directly REAR (bayonet thrusts AWAY from camera, foreshortened); row three directly FRONT (bayonet thrusts TOWARD camera, foreshortened). Three columns: combat guard with musket LOW across chest, two-handed BAYONET THRUST (not aiming to fire), recovery/parry diagonal. No shooting, no smoke, no text, no grid lines. Solid #ff00ff backdrop. Uniform and equipment unchanged.

### Infantry Austrian selected revision

Use image 1 as an EXACT animation atlas edit target; image 2 is uniform reference only. Replace the French uniform on every soldier in image 1 with the Austrian uniform from image 2: white coat and trousers, green cuffs and collar, black cap with brass plate and green pompom. Preserve every pose, size, position, boot baseline, 3x3 equal-cell grid, magenta backdrop, full musket and bayonet. Do not enlarge or move any soldier or weapon. Keep broad blank gutters between all frames. Same painted miniature sprite art. No French blue or bicorne remains. No labels, grid lines, scenery or shooting flashes.

### Cavalry French

Use case: historical-scene. Create a mounted MELEE animation sprite atlas matching the referenced French cavalry exactly: blue and gold hussar uniform, red trousers and plume, brown horse and blue/gold saddlecloth. 3 columns by 3 rows of equal square cells. Columns: saber held ready to strike; a clear saber cut forward/down with rider leaning and arm extended; saber parry/recovery raised above shoulder. No pistols or firearms. Rows: side facing RIGHT; rear facing away; front facing camera. Every rider and complete horse and sword fully contained in its cell with at least 30 pixels blank margin. Make the sprites smaller to ensure this; all nine share exactly the same scale and hoof baseline within each row. Horse shifts weight slightly, no rearing or jumping. Keep sword arm clearly different across columns. Painted miniature strategy-game art, beautiful and clean readable shapes. Pure flat #ff00ff chroma-key background, no shadows outside figures, no text/grid/scenery.

### Cavalry Austrian

Use image 1 as exact edit target, image 2 as Austrian cavalry uniform and horse reference. Repaint ALL nine cavalry melee poses in image 1 as Austrian cavalry: white coat, red cuffs and trousers, gold helmet with black plume, dark brown/black horse, same equipment as image 2. Preserve the exact 3x3 grid, positions, scale, saber guard/cut/recovery poses, directional side/rear/front rows, horse hoof baselines, and generous margins. No French blue uniform or shako remains. Keep beautiful painted strategy sprite style, pure #ff00ff background, no text, no grid, no guns.
