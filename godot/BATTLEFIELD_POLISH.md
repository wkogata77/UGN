# Mincio battlefield polish — October 25, 2026

The October 26 [grand landscape pass](GRAND_LANDSCAPES.md) expands newly
created battlefields to 5760×3840 with five crossings and a lower adjustable
camera. The measurements and map sizes below describe the preceding pass.

Run **Battlefield Demo.cmd** for 12 regiments per side, or **Grand Battle.cmd**
for 20. Both start paused at 0.5x and also appear in Battle Exercises. Space
pauses/resumes, right-click orders movement or engagement, and right-hold/drag
previews facing. WASD pans; the wheel zooms. The battlefield remains 2880x1920
with three crossings and room for flank movements.

The exercises use three or five player corps with four regiments apiece,
attached commanders, an independent army general and supply wagons. Each army
has line infantry, cavalry, two batteries and reserves; one reserve regiment
per side arrives from the perimeter after 110 simulation seconds. These are
illustrative tactical exercises rather than researched historical orders of
battle. Their models never load or autosave the user's campaign, and explicit
saving of an exercise is blocked.

## Delivered systems

- Authored village and farm positions, one church landmark, connected lanes
  and yards, passable garden patches, stored timbers within building footprints,
  planted orchard rows, irregular woodland margins and river-bank detail.
  Scenery and troops share the terrain's slope-sensitive light direction.
- Same-side reservations keep a following regiment waiting before a narrow
  crossing until the preceding regiment's last figures clear. Existing bridge
  columns and water boundaries remain enforced. Near buildings, frontage
  gradually compresses and reopens after the unit clears the street.
- Six new original motion sheets preserve the existing Napoleonic sprite style:
  four infantry walking/passing poses and diagonal views, cavalry walk and
  extended/gathered charge poses, gun pushing steps and swab/ram/prime stages.
  Movement follows distance traveled; brief crossfades and shared registration
  soften pose changes. Existing directional melee/fire paintings remain in use.
  [Art sources and exact prompts](ART_DIRECTION.md#battlefield-polish-animation-assets--october-25-2026)
  record the built-in image-generation workflow and all project asset paths.
- Regiments can fight several contact fronts. Stable visual assignments place
  different soldiers against different opponents; one attack is divided across
  those opponents rather than multiplied. Engaged infantry use melee and consume
  no musket ammunition. Existing front-rank replacement and persistent bodies
  continue to work.
- Front-rank muzzle flashes and smoke originate at actual figure positions.
  Smoke stays behind when a regiment moves. Marching and mounted charges raise
  restrained dust; artillery impacts retain their scatter markers and add dust.
  Prioritized 24-voice audio adds two-dimensional distance attenuation, distant
  high-frequency filtering, subtle reverb and quiet outdoor wind. Pause and mute
  stop combat tails and ambience.
- Figure and shadow batches grow instead of silently dropping soldiers at a
  fixed ceiling. Tactical rules run at 30 Hz; figure steering runs at 15 Hz,
  with positions, shadows and stride phases interpolated each rendered frame
  on the GPU. Hit testing follows those interpolated positions. This preserves
  troop counts, art, tactical speed and combat rules.
- Spatial cells cache active formation bounds for contact and movement queries.
  Transition layouts reuse their endpoint geometry. Straight passage checks
  use continuous rectangle sweeps; route endpoints connect to nearby visible
  graph nodes, with the full-graph fallback retained. Passage planning and
  individual house detours have per-tick budgets; collision safety still runs
  while a route request waits. Cosmetic fog work also has a time budget.
- Settled marching and melee ranks sleep until orders, contact geometry or
  casualties change. GPU clocks continue firing, loading, bayonet and saber
  animation without rebuilding those figures. Reloading troops defer expensive
  firing-lane traces until a volley is ready; actual fire still checks range,
  arc, terrain, friendly obstruction and individual gun lanes before damage.
- Unchanged render instances reuse transforms and selection bounds. Fallen
  figures retain their nine sampled ground points and completed 128-body mesh
  surfaces, so adding a body avoids resampling old casualties. Corps, wagons,
  reserve arrivals, bridge columns and terrain boundaries remain active.

## Verification and limits

`tests/battle_polish.gd` checks both exercise schemas, existing campaign loading,
reserves, roads, bridge reservations, street release, multiple melee fronts,
sleep/wake, real native animation frames, front-rank effects, spatial sound,
pause, desktop/narrow layouts and rendering beyond the former sprite ceiling.
Use `--visual` for screenshots and manually stepped render exercises, or
`--profile-only` for isolated simulation profiling. Results are in
`test-results/battle-polish-verification.json`; screenshots use the
`battle-polish-` and `battle-motion-` prefixes. `Verify.cmd` includes the new
headless and graphical checks alongside the existing suites.

The fixed-rate runtime benchmark is `tests/performance.gd`. Unlike the older
manually stepped render exercise, it advances tactics from `_physics_process`
at the same 30 Hz as the playable game. `-- --after` captures the normal views;
add `--long` for 12-second samples, `--combat` for an isolated open-ground drill
with simultaneous ranged and melee fights, or `--limit-60` to cap rendering.
It pins the camera/input, warms up for 1.8 seconds, measures CPU/GPU work and
frame intervals, then exits without loading or saving a campaign. Running with
`--baseline` explicitly replaces the archived baseline; ordinary runs preserve it.

`tests/performance_regression.gd` checks spatial queries against full searches,
transition invalidation, presentation-rate independence, swept approaches,
friendly fire safety, melee sleep/wake, native GPU interpolation and selection,
reload-clock wrap and continuously animated settled melee. `--visual` enables
the native pixel checks. Both modes are included in `Verify.cmd`.

Final performance regressions: **62 headless / 75 native checks, zero failures**.
Native battlefield exercise: **85 checks, zero failures**. Additional focused
suites passed for animation (208), slopes (67), native audio playback (56),
bridge movement (161), town movement (97), battle orders (82), combat motion
(87), tactical AI (79), polish mechanics (153), weapons (323), simulation
(152), operational campaigns (189), map layout (91), relief (51), and the
expansion/save regression (42).

On this Windows machine (Godot 4.7.2 Compatibility, RTX 3070 Ti, 1440x900), the
October 25 performance fix measured these fixed-rate runs at 0.5x. VSync was
disabled and rendering uncapped to expose throughput. Normal views use six-second
samples; the combat drill uses twelve seconds. Normal runs retain all troop and
terrain detail; the exposed whole-field view disables cosmetic fog for load.

| Exercise/view | Before FPS | After FPS | After 95th percentile | After worst frame |
| --- | ---: | ---: | ---: | ---: |
| 12 vs 12, normal command view (648 sprites) | 47.5 | 238.3 | 10.63 ms | 30.18 ms |
| 20 vs 20, exposed whole field (1,333 sprites) | 12.7 | 129.2 | 29.53 ms | 48.07 ms |
| 12 vs 12, ranged drill (1,385 surviving sprites) | — | 221.9 | 12.30 ms | 49.38 ms |
| 20 vs 20, ranged/melee drill (2,533 surviving sprites) | — | 90.3 | 34.93 ms | 123.24 ms |

The fixed-rate baseline's 95th-percentile frame times were 36.75 ms and 359.32 ms
for the two normal views. Simulation now sustained 30 ticks/second in every
tested view; the baseline's larger battle managed 24.5. An additional rendering
cap of 60 FPS averaged 59.8 / 58.6 FPS in the normal views, with 32.34 / 43.36 ms
95th-percentile frames. High average throughput does **not** establish even
60 FPS pacing: larger battles and simultaneous casualty replacements still
produce occasional hitches, especially the crowded melee drill.

Raw results are `test-results/performance-fixed-before.json`,
`performance-fixed-after.json`, `performance-fixed-after-long-combat.json` and
`performance-fixed-after-60fps.json`. The old 180-frame numbers in earlier notes
advanced simulation once per rendered frame; they are not a valid real-time
before/after comparison. The archived raw capture remains in
`test-results/performance-before.json`. The normal views have different camera
and visibility loads from one another, so these are tested scenarios, not a
controlled per-regiment scaling ratio. Combat drills have no archived baseline.

The 20-versus-20 exercise is a heavier scaling option. Short benchmark runs are
not a guarantee for sustained crowded melee or every camera position. Remaining
work includes full traffic deadlock resolution, inter-regiment individual-body
collision, more painted hit/death transitions, recorded acoustic layers and
long human balance sessions. Artillery markers represent the existing volley
resolution; this pass does not add delayed projectile damage. Forests, brush,
gardens and enterable fortifications retain their existing passability rules.
