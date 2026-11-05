# Native Port Status

## Scope

The port migrates the **implemented browser game and depth demo** into one
native Godot application. It does not silently turn the longer wishlist into
completed features. The browser code, original art, and original roadmap remain
available and unchanged apart from the root README's native-project link.

The playable native project uses GDScript, Godot's scene tree and Controls,
Camera3D, terrain meshes, MultiMesh sprites, spatial shaders, AudioStreamWAV,
and AStar2D/AStarGrid2D. There is no Chromium wrapper, JavaScript runtime, Three.js,
Phaser, or npm dependency inside the running Godot game.

## Feature Inventory

| Existing area | Native implementation | Notes |
| --- | --- | --- |
| Real-time campaign | `scripts/model.gd`, `campaign.gd` | Marching, road/slope modifiers, fatigue, personality-based patrol/intercept/withdraw, recent sightings, encounters, temporary paid recon |
| Campaign theaters | `scripts/data.gd`, `scripts/terrain.gd` | Existing illustrative Italy sector plus original condensed Danube content |
| Tactical encounters | `model.gd`, `tactics.gd` | Bridge, village, heights; nearby armies arrive as reserves; objectives, victory, defeat, withdrawal |
| Persistent army | `model.gd`, `headquarters.gd` | Recruitment, regiment size/name/corps/officer, drill, experience, perk, history, equipment, replacements |
| Officers | `data.gd`, `model.gd` | Hire pool, experience-based rank, capacity, assignment, wounds, death, combat reports |
| Corps/general | `model.gd`, `tactics.gd` | Four regiments per corps, embedded corps host, standalone general, command radius, rally, follow and independent orders |
| Equipment/economy | `model.gd`, `headquarters.gd` | Seven existing weapons, stock, buy/sell, compatibility, supply, rewards, musket salvage |
| Tactical orders | `world.gd`, `model.gd`, `charge.gd` | Selection, queue, deployment, drawn frontline, anchored facing drag, engage, run, halt, one-time charge impact, fall back, off-field retreat |
| Formation motion | `formations.gd` | Timed/queued formation changes, gradual turns, steady-speed individual cosmetic followers, local spacing, displacement-driven strides |
| Combat rules | `tactics.gd` | Arc-limited automatic fire, explicit acquisition/pursuit, cover terrain, LOS, morale/routing, condition/rest, ammunition, reload |
| Specialist units | `model.gd`, `tactics.gd` | Limbering, mounted/dismounted carbine cavalry, skirmisher detach/recall, vulnerable supply wagons |
| Artillery feedback | `tactics.gd`, `world.gd` | Deterministic scatter, hit-footprint sampling, per-gun ground markers, smoke/flash and recoil |
| Relief on both maps | `terrain.gd`, `world.gd`, `shaders/` | Padded height meshes, mirrored painterly terrain, trees/villages, bridge decks, water, softened fog |
| Troop art and animation | `art.gd`, `world.gd`, `troops.gdshader` | Original combat atlases, two painted infantry steps plus idle in four directions, articulated mounted/crew gait, side firing/reload poses |
| Map/HQ interface | `hud.gd`, `headquarters.gd`, `ui.gd` | Compact roster/actions, inspectors, minimap, officer/weapon comparisons, corps capacity, batch/replacement quotes, responsive layouts |
| Buildings and defenses | `landscape.gd`, `cover.gd`, `passage.gd` | Shared footprints, building-aware routes/LOS, local friendly detours, two enterable infantry positions per battle |
| Camera/input | `world.gd` | Mouse selection/orders, WASD, Q/E, middle/Alt drag, campaign drag, zoom to 6x, touch gesture support |
| Sound | `audio.gd` | Seven event types with three synthesized variants each, 12 prioritized voices, horizontal panning, mute/volume |
| Persistence | `model.gd` | Versioned native JSON, validated previous-save backup and recovery, periodic/close-time saving, paused restoration, browser version 3 import |
| Separate exercises | `main.gd` | Drill campaigns remain in memory and never overwrite the real campaign |

## Deliberate Differences And Remaining Limits

### Native Visual And Order Refinements

The native game now previews every selected regiment during a facing drag,
using formation-sized footprints, troop markers, and direction arrows. Preview
and issued destinations share the same placement calculation, including mixed
unit widths, rotated group frontage, queued orders, and map-edge clamping.
Ordinary non-drag movement keeps its existing spacing. The press point remains
anchored in world coordinates if the camera pans or zooms before release.

Both maps now use a more oblique camera, stronger visual relief, softer contact
shadows, directional sunlight and scenery shadows, textured road surfaces,
shaded river water, and stone bridge materials. Terrain and river winding is
corrected to face upward, fixing the lighting discontinuities caused by viewing
their back faces. Scenery grounding checks its full billboard footprint against
the relief surface. These are rendering refinements: existing tactical terrain
rules, map geography, and painted troop atlases remain unchanged.

The environment art refresh adds quieter painted fields, six individual tree
variants, six northern Italian building variants, and translucent musket/cannon
smoke. Both maps share the new scenery and ground treatment. Troop sprites and
unit labels are smaller; the original soldier art is preserved. Smoke stays at
its firing origin and follows simulation time, including pause. Asset provenance
and exact generation prompts are in [ART_DIRECTION.md](ART_DIRECTION.md).

This is still a painted 2.5D presentation on real terrain meshes. Buildings now
share footprint/height metadata with navigation and LOS. Farm-wall and hedge
positions support infantry occupation; ordinary houses cannot be garrisoned.
Authored landscape compositions,
full 3D building models, and fuller animation cycles remain future art work;
this pass does not claim Ultimate General-level fidelity. The subsequent
[infantry-first animation pass](INFANTRY_ANIMATION.md) adds two painted steps
and separate idle art for both sides in four directions without changing the
existing combat artwork.

### Existing Limits

- The native version combines campaign management with the depth rendering
  previously isolated in the browser demo. It does not reproduce the old flat
  Phaser view as a separate renderer.
- The Italy map now covers 4320x2880, with 18 settlements and five crossings.
  Geography and encounters remain illustrative, not a complete researched
  Northern Italy campaign. See [the polish checklist](POLISH_PASS.md).
- The native UI preserves the existing visual direction and workflows but
  uses native widgets, not a pixel-for-pixel HTML recreation or Ultimate General
  interface clone.
- Battle simulation remains regiment-based. The individual painted soldiers
  are cosmetic instances, not separately simulated combatants.
- Infantry, dismounted cavalry, and campaign foot escorts use two painted
  walking frames plus separate idle art, driven by displacement and staggered
  per soldier. Mounted cavalry and wagons also have painted idle/two-step
  frames, and artillery has movement/fire/reload frames in three directions.
  Generals retain articulation. Fuller gait cycles and eight-direction action
  artwork remain future work.
- Direct shots now test intervening friendly formations' oriented footprints,
  including close and offset frontage. This is not per-soldier firing lanes
  or ballistic projectile collision. Terrain LOS follows the rendered mesh;
  buildings use approximate shared occluders rather than authored 3D meshes. Melee uses
  oriented formation-edge contact, opposing ranks and painted infantry/cavalry
  attack cycles; engaged units cannot shoot. Multi-front encirclement and
  building-interior fighting still need broader contact allocation. Persistent bodies
  retain casualty identities while rear ranks gradually fill vacancies.
  See [COMBAT_MOTION.md](COMBAT_MOTION.md) for exact behavior and limits.
- Charge, retreat, directional morale, and steady figure speeds are detailed
  in [BATTLE_ORDERS.md](BATTLE_ORDERS.md). Rear attacks apply the greatest morale
  pressure; mounted charges have the largest impact and lower fatigue than foot.
- Existing woods/hills influence sight and combat; roads and slope now modify
  movement on both maps. Campaign march modes and enemy fatigue are implemented.
  Tactical building-clearance routes, local friendly detours and two infantry
  defensive positions are available. Narrow-crossing compression, more authored
  fortifications and campaign logistics remain expansion work.
- Existing replacements are immediate purchases with experience preservation
  or dilution, not timed arrival queues or a strategic manpower pool. Existing
  perks are the original single-perk implementation, not the planned multi-level
  ability tree with active perk loss on demotion.
- Loot still uses the existing abstract musket-recovery calculation, not a
  weapon-by-weapon capture ledger. Recon is still a paid temporary effect, not
  independently moving scout troops.
- Native audio is synthesized anew, with variant waveforms, horizontal camera-
  relative panning, attenuation and voice priority. It is not a recorded battle
  soundscape; ambience, environmental reverb and depth attenuation remain work.
- Touch gestures are implemented and can be exercised through synthetic native
  events; physical phone/tablet hardware and mobile platform exports have not
  been certified. Native Windows is the tested target.
- Export templates were absent on this machine. A Windows preset is included;
  a packaged release executable still requires matching templates and an
  exported-build smoke test. Running through the installed Godot is supported.

## Wishlist Still To Implement

The source of truth for the wider design is
[the original feature plan](../feature%20plans/visual-depth-demo-and-northern-italy-roadmap.md),
especially its later progression notes and section 22 backlog.

1. Multi-front melee contact allocation, narrow-passage compression, robust
   congestion/turn clearance, gun-crew hand-to-hand art and individual firing lanes.
2. Expand the infantry's two-step/idle artwork into fuller gait cycles and
   corresponding mounted/crew animation; complete directional combat poses.
3. Extend the two implemented infantry defenses into more authored fortifications,
   building garrisons, assault behavior and strategic forts.
4. The researched, larger Northern Italy campaign: terrain/navigation, objective
   chains, forts, supply points, named armies, and persistent strategic state.
5. Objective-driven strategic decision-making beyond the implemented general
   preferences/recent sightings; physical scouts and recall/capture, town loyalty
   and visible messenger-based intelligence.
6. Regiment level/ability progression; timed recruit/veteran replacements;
   money and manpower costs; experience dilution, lost levels, and perk removal.
7. Richer weapon catalog and salvage, campaign supply/logistics, revised economy,
   encounter balance, audio mix, and continued native performance/UX polish.

The right-drag order in this port already anchors the destination at mouse-down
and faces toward mouse-up. Navigation also retains the requested exact final
point when legal. Those behaviors are explicitly tested, but they do not close
the entire movement/animation backlog above.

See [BATTLEFIELD_FOUNDATIONS.md](BATTLEFIELD_FOUNDATIONS.md) for exact new rules
and [the complete implementation checklist](../feature%20plans/native-polish-implementation.md)
for the unfinished portions of the polish review.

## Save Format And Migration

Native saves have this envelope:

```json
{
  "format": "field-command-godot",
  "version": 1,
  "state": { "version": 3, "mode": "campaign" }
}
```

The example is abbreviated, not a loadable save. `state` retains the browser's
camelCase field names so migration can preserve armies, weapons, officers,
orders, casualties, and history. Native-only fields include `portVersion` and
`theater`. No cross-engine lockstep determinism is claimed: native AStar paths,
floating point, AI tie-breaking, and presentation can differ.

Imports validate known shapes, numeric values, catalog compatibility, IDs,
corps capacity, paths/orders, and battle structure before replacing the current
state. Native imports normalize old wagon display fields and attach corps
commanders to regiment hosts. Visibility is recalculated; the imported game is
paused. Invalid input leaves the existing campaign in place.

### Exporting An Existing Browser Save

The browser build uses local storage key `field-command-save`. Return to the
same address and port where the campaign was played, pause and save it, then
run this in that page's browser developer console:

```javascript
const raw = localStorage.getItem('field-command-save');
if (!raw) throw new Error('No campaign save at this address and port.');
const campaign = JSON.parse(raw);
if (campaign.version !== 3) throw new Error('Open and save with the current browser build first.');
const url = URL.createObjectURL(new Blob([raw], { type: 'application/json' }));
const link = document.createElement('a');
link.href = url;
link.download = 'field-command-browser-campaign.json';
link.click();
setTimeout(() => URL.revokeObjectURL(url), 1000);
```

This downloads a local backup and does not send the save anywhere or remove it.
Import the downloaded JSON from the native Settings screen. Browser depth-demo
sessions were deliberately in-memory and therefore do not appear in this
persistent local-storage slot.

## Engineering And Verification

- Simulation uses Godot's fixed 30 Hz physics clock, with interpolated troop
  positions and gait between ticks. Game speed multiplies simulation time,
  while camera input remains real-time and responsive while paused.
- AStar2D searches visible building corners and river-bank connections in battle;
  AStarGrid2D owns campaign route search. Both smooth through the exact legal
  endpoint, without an extra grid-center turn at arrival. Battle regiments use
  streets, while individual figures detour around house footprints.
- Grounding samples cached vertices of the same rendered terrain triangles and
  explicit bridge decks. There is no independent approximated ground curve for
  positioning troops.
- Fog's cosmetic LOS-cell work is distributed across simulation ticks, while
  combat visibility remains a separate periodic update. This avoids a large
  single-frame fog sweep during active battles.
- Troops share eight MultiMesh batches, three original atlases, and two cached
  registered infantry walking atlases; no per-soldier
  scene nodes or texture loads. Typed cosmetic tracks and cached formation
  layouts avoid rebuilding the same data every frame. Key removal happens
  before mip generation.
- The simulation suite includes real browser-model fixtures for campaign,
  battle, and report migration. It also covers malformed input, campaign
  completion, trading, replacements, officers, orders, engagement, fatigue,
  supply, melee, scatter, reinforcements, and sustained scenario updates.
- The graphical suite runs an actual Windows Godot window on the GPU. Captures
  cover desktop and 390x844 layouts, maps, HQ tabs, reports, close zoom, movement,
  firing/reload, and active-battle frame timing. Exact results are recorded in
  `test-results/verification.json`; frame timings apply to that test machine,
  not every device or future army scale.
- The browser's original regression tests are run separately. This is focused
  automated coverage, not a claim that the complete game has no remaining bugs
  or has received a full-length manual campaign playthrough.
