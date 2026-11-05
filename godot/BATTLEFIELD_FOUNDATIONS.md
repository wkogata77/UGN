# Battlefield Foundations And Management Polish

September 14-15, 2026. This implements a first set of the native polish review,
not the complete Northern Italy roadmap. Existing painted troop atlases and
the browser project are preserved.

## Buildings And Passage

`FieldLandscape` supplies one deterministic building layout to the renderer,
navigation and line-of-sight simulation. Tactical houses block routes and
shots through their footprint, with height-aware sight checks. Campaign town
buildings use the same layout source but do not block strategic army tokens.
Village building scale is slightly smaller; quieter irregular field patches
blend into the existing terrain on both maps.

Battle routes use Godot's `AStar2D` over visible building corners and river-bank
connections. Regiments can use town streets instead of requiring clearance for
an enclosing circle around the whole formation. Individual figures detour around
house footprints at their existing speed cap. Clear ground orders retain the
exact clicked destination; clicks on houses resolve to the nearest free edge.
Campaign routes retain `AStarGrid2D`. Both include the exact endpoint during
path smoothing, avoiding a grid-center overshoot and turn back on arrival.
Simple group moves preserve relative spacing; drag orders still assign a new
frontage and facing. Individual units keep the exact ground destination.
Existing clearance overlaps can be exited without moving deeper into the
obstacle. Newly created battles move obstructed initial
deployments onto nearby clear ground before play starts; loading a running
battle does not teleport regiments.

Friendly frontages stop advancing formations. A bounded local `AStar2D`
visibility graph inserts detours without changing the final order or increasing
march speed. In head-on meetings, one regiment yields deterministically. Retries
are throttled; impossible destinations produce a waiting state rather than a
speed burst. Detours can skip an intermediate waypoint occupied by friendly
troops without changing the final destination. Drag previews mark invalid ground red,
and partial group failures produce a notification.

Roads give an 8% movement benefit on level ground. Slope reduces pace down to
45% before the road multiplier; existing woodland and formation penalties still
apply. Both campaign armies use the same road/slope calculation. Tactical
figures receive the resulting pace as their movement cap.

Bridge follow-up, October 25: individual figures now obey the river and bridge
deck boundaries. Infantry, cavalry and artillery compress into temporary files
on the approaches, stay compact while any figures are crossing, and reform on
the far bank. The selected formation is retained. Per-step boundary checks also
constrain separation, inertia and turning, and loaded bridge regiments start on
safe ground. Marching speed caps and existing casualty slot assignments remain.
Routing regiments now seek crossings when water blocks their escape; their
escape waypoints are saved and validated. Forests, brush and fortification
occupation retain their existing movement rules. This does not add solid
collision to decorative vegetation or defensive walls.

Traffic between regiments on bridges, other narrow-passage layouts and full
rotation clearance remain unfinished. Building footprints are shared
approximations of the art, not authored 3D collision meshes. Figures
can break ranks around buildings, but crowded town slots do not yet use a full
street-garrison layout. Walls are defensive positions, not solid maze walls.

## Defensive Positions

Each tactical scenario has a farm wall and orchard hedge. Select infantry and
right-click its shield marker to reserve and man it. Ordinary ground clicks beside
a defense remain movement orders and never grant its protection. Hovering the
shield shows capacity, frontal protection and approach/manning/occupied status;
the marker's bar shows deployment progress. The action row includes
Leave defensive position. Ordinary movement, formation changes, withdrawal and
routing relinquish the position. Halt preserves an already occupied position
but cancels an approach.

| Position | Capacity | Frontal ranged protection | Frontal melee protection |
| --- | --- | --- | --- |
| Farm wall | 900 men | 45% | 15.75% |
| Orchard hedge | 720 men | 25% | 8.75% |

One regiment reserves a position while approaching. It must arrive, complete
its formation change, face the defense, and spend at least four simulation seconds
manning it before protection applies. Deployment also waits for every living figure
to reach its defensive slot (within three map units). Figures spread along the
frontage and fill supporting ranks; small remnants cannot fill a whole position.
Clicking its marker again does not restart an existing occupation.
Protection is directional: rear and sufficiently oblique fire bypass it, and
displaced or moving troops receive no benefit. Both sides can occupy a vacated
position; the defender must leave or be routed before an opponent can enter.
There is no dedicated assault/capture progress bar or siege system yet.

Walls use a batched stone mesh and hedges reuse painted woodland art. Enemy
occupancy does not color the marker while the defender is hidden. The HUD shows
approach, deployment, occupation and blocked movement; flank/rear warnings take
priority over the normal cover status.

## AI And Headquarters

The first coordinated tactical planner now assigns an army stance and infantry
sectors, supports them with cavalry and guns, commits reserves to pressure or
opportunity, and orders recovery or withdrawal. Infantry can choose an appropriately
facing vacant defense through the shared manning rules. See [BATTLE_AI.md](BATTLE_AI.md)
for decision timing, the defensive exercise, diagnostics and remaining limitations.

Campaign generals have persistent aggressive, cautious and opportunist
preferences. Their willingness to intercept depends on reported relative
strength; exhausted/overmatched forces withdraw toward their home reserve.
Pursuit uses a recent sighting, not the hidden player's current position, and
reports expire after two campaign hours. Woodland reduces observation range.
Visible army inspectors show personality, intent and fatigue. Physical scouts,
couriers, supply objectives and loyalty are still roadmap work.

Headquarters now shows corps occupancy, officer experience comparisons,
compatible weapon range/power deltas, replacement quantity/cost/weapon/experience
previews, and armory batch totals. Quotes and transactions share model methods;
dealer/reserve stock limits and affordability are reflected before purchase.
Commander portraits still open the eligible-officer assignment dialog.

Replacements remain immediate. This pass does not yet add the requested timed
arrival queues, manpower pools, level-dependent veteran prices, or multi-level
perks that disappear when experience drops below their threshold.

## Audio, Startup And Recovery

Native synthesized audio has three variants per event, including foot, hoof,
wheel, musket, cannon, melee and order sounds. A 12-voice pool gives commands
and cannon reports priority, with camera-relative horizontal panning and lateral
attenuation. Muting stops active sounds; paused orders retain acknowledgements.
Infantry and cavalry firearms share the same musket crack/body/reflection set.
Cannons use a separate low-frequency pressure report and a 2.8-second rolling
tail. Firing effects are baked as uncompressed 44.1 kHz WAVs, with three variants
per family, and a shared peak limiter protects overlapping volleys. Other events
retain the existing synthesis. See [audio generation notes](assets/audio/README.md).
This is not a recorded sound library or a full ambient soundscape; vertical
distance and environmental reverb are not yet modeled.

Prepared keyed/registered sprite atlases are cached under `user://art-cache/`.
Source modification times and `FieldArt.CACHE_VERSION` invalidate cached images.
Subsequent launches can restore prepared pixels without repeating registration.
The first uncached launch still does the preparation, and progressive loading
feedback remains a separate task. Generated test screenshots are excluded from
Godot's asset import scan.

Saving retains the previous validated snapshot as `campaign.json.bak` before
replacing the primary save. Startup can recover that snapshot if the primary is
missing or invalid, with a dispatch recording the recovery. If both snapshots
are invalid, automatic saving is disabled and the original files are preserved.
A successful explicit save or load resumes autosaving when recovery suspended
it. Intentionally nonpersistent battle exercises remain nonpersistent.

## Verification

`Verify.cmd` includes `tests/polish.gd` alongside the previous suites. New checks
cover shared layouts, clear initial deployments, building LOS/routes, exact
endpoints, friendly detours and speed caps, cover reservations/deployment/exit,
directional protection, AI intelligence, quotes and backup recovery.

The native graphical suite exercises wall orders, occupied troop placement,
desktop/narrow headquarters previews, identical cached sprite pixels, stereo
audio and its voice priority/mute lifecycle. Unit-animation drills remove
buildings from both their test simulation and rendered scene; separate scenery
tests retain the real maps. Completion guards prevent a script error from
silently skipping an entire animation or polish test group.

The full outstanding review is tracked in
[native-polish-implementation.md](../feature%20plans/native-polish-implementation.md).
Measured results are recorded in [README.md](README.md#verification) after the
complete native verification run.

The October 25 bridge follow-up passed 151 crossing/boundary checks, 14 focused
routing/save checks, 228 fortification checks and the existing battle-order,
combat-motion, town-movement, map and polish suites. Native checks passed 36
assertions using a copy of the player's saved crossing battle at desktop and
narrow window sizes. The source save was unchanged by the replay. Captures use
`test-results/bridge-safe-*`; the headless suite is included in `Verify.cmd`.
