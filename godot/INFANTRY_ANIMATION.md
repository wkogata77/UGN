# Painted Troop Animation

The October 25 battlefield pass expands infantry to four marching/passing
paintings and five direction rows, with distinct side-on ram/prime actions.
See [battlefield polish](BATTLEFIELD_POLISH.md) and the newer prompt/source
records in [ART_DIRECTION.md](ART_DIRECTION.md). Earlier pass notes below
describe the previous pose sets retained as directional-action fallbacks.

This records the infantry-first pass. The subsequent [polish pass](POLISH_PASS.md)
adds mounted, wagon and gun-crew frames while retaining these infantry assets.

The reload follow-up adds [matching loading frames](RELOAD_ANIMATION.md) for
infantry and mounted troops in all directions. Its two planted loading poses
follow the actual shot cooldown, including the longer artillery cycle. Original
walking, firing and melee artwork is unchanged. Walking now plays at two-thirds
of its previous cadence without changing unit travel speed or combat timing.

## Playback Refinement (September 24)

The source paintings, uniforms and atlas registration are unchanged. Playback
now connects infantry and cavalry steps through a brief planted/passing pose,
with short eased blends instead of abrupt changes between the two extremes.
Gun crews remain in their pushing posture between steps, and wagon frames
blend without inserting a stationary pose on every half-stride. Movement
weight eases starts and stops, including campaign escorts and supply trains.

Firing has one directional recoil and recovery, not repeated torso wobble.
Left-facing recoil is mirrored correctly, and the cannon carriage recoils as
a rigid shape. Firing, loading and ready poses transition gradually; marching
supersedes a lingering reload pose so soldiers do not slide with planted feet.
Melee now returns through guard between thrust and parry, with a quicker attack
and longer recovery. Rear ranks still do not thrust through the front ranks.

Movement weights, support-unit gaits and combat time interpolate between physics
ticks. All playback follows simulation time and actual travel distance: pause
freezes it, 0.5x slows it, and running changes cadence without changing the
underlying marching speed or formation solver. Blending stays in the existing
MultiMesh shader; it adds no per-soldier nodes or duplicate sprite geometry.
The general retains its original single painting with reduced hoof deformation.

This remains a small painted-pose set, not a skeletal animation system. Longer,
fully articulated motion would require additional registered in-between art.

Run `godot --path . -- --verify-animation` for the focused native animation
suite. Its 208 checks cover four facings, boot pixels, transition continuity,
starts/stops, moving while reloading, melee recovery, pause, all four time
speeds, loading hand movement, actual shot cooldowns, support wagons, casualties,
selection and desktop/narrow captures. Gallery captures are
`test-results/animation-*.png` and `test-results/reload-*.png`.

## Implemented Scope

French and Austrian infantry now have a separate planted-feet idle pose and
two painted walking poses. Each set includes right-facing, rear, and front
views; the side view is mirrored for left-facing movement. The same art is used
by dismounted cavalry and campaign infantry escorts.

The renderer uses the short pose transitions described above.
Upper-silhouette registration keeps the head and equipment aligned between
frames. Infantry no longer receives the old procedural leg bend. Original
firing paintings remain; the reload follow-up supplies separate loading poses.
Movement takes priority once troops start marching. Mounted cavalry, guns and wagons use their own
painted motion atlases from the subsequent polish pass.

A full cycle corresponds to 27 map units of actual displacement. At a normal
24-unit/second march and 0.5x simulation speed, this is a 2.25-second cycle.
Running speeds it up; fatigue and terrain slow it down. Cosmetic followers
retain individual phase offsets, so nearby soldiers do not step in lockstep.
Stopping settles into idle. Pausing freezes the selected walking pose rather
than replacing it with idle. Campaign stepping also uses measured displacement.

The two painted stride extremes and idle pose are not a complete four/eight-frame
gait. Short blends soften the transitions without continuously warping limbs.

## Saved Assets And Processing

Both selected originals were made with the **built-in imagegen tool**; no
CLI/API fallback was used.

| Project asset | Selected generated original |
| --- | --- |
| `assets/infantry-walk-french-v1.png` | `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-6f68a4c3-10a1-4216-a599-cfc81e02eb48.png` |
| `assets/infantry-walk-austrian-v1.png` | `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-aa81671d-f0b3-47a7-a2a5-936838c188d3.png` |

Each source is a 1254x1254 RGB atlas with three columns and three rows. Columns
are idle, step A, step B; rows are side, rear, front. The first French draft
returned an opaque checkerboard and nearly duplicated steps, so it is not
shipped. The final assets use the established magenta-key pipeline.

Godot removes the key before mip generation, registers each frame against its
upper silhouette, and caches a 1152x1536 atlas per side with 384x512 cells.
Registration uses a common scale and vertical reference within each direction,
not each frame's changing boot bounds. Source PNGs are preserved. The two
additional atlases reuse existing infantry MultiMesh batches; there are no
per-soldier nodes, texture uploads, or opacity-crossfaded duplicates.

## Prompt Set

### French Base

Use case: identity-preserve. Asset type: original production infantry animation sprite atlas for a native Godot Napoleonic tactics game. Reference image 1 is the existing eight-unit atlas: preserve ONLY the identity, uniform, equipment, realistic fine painterly rendering and proportions of the FRENCH INFANTRYMAN in its top-left cell. Reference image 2 supplies the SAME French infantryman's rear and front views in its first column, not the other unit types. Create a NEW SQUARE transparent atlas, exactly THREE equal columns by THREE equal rows, nine full-body sprites of this SAME infantryman, no other subjects. Row 1: three-quarter SIDE view marching to the RIGHT; Row 2: REAR view walking directly away; Row 3: FRONT view walking directly toward viewer. Columns are animation frames: column1 NEUTRAL IDLE with both boots planted nearly together, relaxed straight knees, upright stationary soldier; column2 LEFT LEG stepping forward, right leg back with lifted heel; column3 RIGHT LEG stepping forward, left leg back with lifted heel. The two stride poses must be visibly DIFFERENT anatomy, with reversed knee bends and boot placement, NOT duplicate poses and NOT horizontally mirrored complete soldiers. Moderate disciplined marching, not running or lunging. CRITICAL ANIMATION REGISTRATION: within each row the head, face, hat, chest, hands, backpack, musket, bayonet and belt should be IDENTICAL pixels/positions across all three columns as closely as possible. Change primarily the anatomy BELOW THE HIPS. Keep weapon carried diagonally upward as in the reference, do not swing or change it between frames. Preserve dark blue coat, red cuffs, white crossed belts, white trousers, black boots, black bicorne with tricolor cockade, brown rolled pack and long musket/bayonet. No shako or cavalry helmet on this French infantryman. Camera high oblique matching references, restrained painterly detail, not cartoon, not pixel art, no thick outlines. Every sprite centered at cell x=50%, topmost bayonet/hat no higher than cell y=6%, lowest planted boot at cell y=92%, belt/hips exactly cell y=61%. Equal scale across all nine sprites, generous genuinely transparent gutters, all equipment and limbs entirely within their own cell x=8%-92%, no cross-cell spill. GENUINELY TRANSPARENT alpha backdrop and gaps, no checkerboard, magenta, floor, shadows, scenery, labels, text, cell borders or watermark. Original new animation artwork, not an extracted game asset.

### French Final Correction

Use case: precise-object-edit. Image1 is the EDIT TARGET nine-frame infantry atlas. Preserve every sprite's painted detail, uniform, face, bicorne, torso, arms, musket, backpack, scale and position. Preserve the entire first and second columns' soldiers. Fix ONLY the lower legs in column THREE and the background. Column3 must be the OPPOSITE marching step from column2, not a near duplicate. TOP RIGHT side view: swap which leg is forward: the soldier's NEAR leg now sweeps backward and bends at the knee, its boot distinctly lifted behind the body, while the FAR leg extends forward to a planted boot; make the bent-knee/boot silhouette distinctly different from the middle cell but keep hips and torso registered. MIDDLE RIGHT rear view: the boot on the IMAGE LEFT must be lifted forward/up with a bent knee and shortened leg, while the boot on IMAGE RIGHT is planted at the bottom baseline; this is the opposite of middle-center which has IMAGE RIGHT lifted. BOTTOM RIGHT front view: the boot on IMAGE LEFT must now be lifted upward with a bent knee, and the IMAGE RIGHT boot planted on the lowest baseline; this reverses bottom-center. Do not mirror any upper body or weapon. Keep all three rows, three equal columns and square canvas. Replace the ENTIRE checkerboard background including holes between limbs and around bayonets with absolutely flat pure #ff00ff MAGENTA, no transparency, no white or grey residue, no gradients or texture. This is a chroma-key sprite atlas using the game's established magenta-removal pipeline. No shadows, floor, outlines, labels, text or extra objects. All nine full figures stay entirely within their original cells.

The correction target was the unshipped first draft:
`/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-cc9da861-b995-45ce-b3c7-b5a077f668dc.png`.

### Austrian Variant

Use case: identity-preserve. Image1 is the EDIT TARGET: an exact three-column three-row infantry idle/walk atlas. Image2 is the UNIFORM reference: use ONLY the Austrian infantryman in TOP ROW COLUMN TWO (white coat, green collar/cuffs, white crossbelts, black tall shako with green pompom, brown knapsack, white trousers, black boots). Convert all NINE French soldiers in Image1 into this SAME Austrian infantryman. Preserve Image1's exact nine poses, framing, directions, weapon positions, limb geometry, frame registration, lighting and painterly quality. Only replace the faction uniform, hat, face and insignia using Image2's second top-row soldier; never use cavalry or artillery. THREE rows remain side RIGHT / REAR / FRONT. THREE columns remain planted-feet IDLE / STEP A / opposite STEP B. Keep the distinctly different leg bends and opposite raised feet of columns2 and3 exactly as in Image1: do NOT collapse them into repeated copies. Upper body remains registered consistently within each row. Square canvas, nine equally sized cells, same cell spacing and equal scale. Every complete bayonet, boot, plume, weapon and backpack remains inside its own cell. Keep a perfectly flat pure #ff00ff MAGENTA chroma-key backdrop, including every gap between limbs. No transparency, checkerboard, shadows, floor, scene, text, labels, grid or extra objects. Fine realistic painted original game sprites.

Reference files were the existing `assets/depth-units-keyed.png` and
`assets/depth-unit-directions-v2.png`, plus the final French atlas when
deriving the Austrian variant. No other game's artwork was included.

## Verification

The native simulation suite checks idle and alternating frame selection,
distance-driven cadence, update-rate independence, half-speed cycle duration,
and staggered phases. The graphical suite checks registered atlas bounds,
actual batch frame selection, visible boot changes for both sides in all four
directions, paused pixels, campaign stepping, actual march cycles, return to
idle, existing firing/reload behavior, and active-battle performance.

Close-up captures are `test-results/battle-infantry-idle.png`,
`test-results/battle-infantry-step-a.png`, and
`test-results/battle-infantry-step-b.png`. Exact full-suite results remain in
`test-results/verification.json`.

Original infantry-only run: **149 simulation checks and 246 graphical/input checks passed**,
with 41 captures. The active 445-sprite battle sample at 1440x900 measured
19.3 ms median and 31.3 ms p95 on the RTX 3070 Ti; this is a local measurement,
not a guarantee for every machine or army size.
