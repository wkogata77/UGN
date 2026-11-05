# Grand landscapes — October 26, 2026

This pass addresses the flat environment and cramped scale while preserving
the existing Napoleonic uniforms, painted troop sprites and animation sheets.
The reference is the landscape composition of Ultimate General: Civil War:
quiet broad fields, irregular woodland, readable terrain relief, grounded
settlements, a lower camera and a restrained command interface. It is original
art and geometry, not a copy of that game's resources or surveyed map layouts.

## Play and camera

Run `Grand Battle.cmd` for the isolated paused 20-versus-20 Mincio exercise, or
`Battlefield Demo.cmd` for 12-versus-12. Neither loads or saves your campaign.
Space pauses; 0.5x remains available. Right-click orders movement/engagement;
right-hold/drag previews formation facing. WASD pans and the wheel zooms.

Both campaign and tactical cameras start at **35° above the ground**.
**Q lowers / E raises** the angle; the two arrow buttons on the right do the
same. The range is **28–60°**, in five-degree steps from buttons. Terrain
picking, pan speed, camera bounds, selection bounds and grounded painted
figures all follow the actual projection. The troop foot anchor stays fixed
while the view tilts. Overview fits the expanded map into the available space.
The former Q/E corps shortcuts move to **1/2** so tilting does not change the
selected corps. Corps buttons remain available in the command rail.

## Scale and compatibility

| Newly created map | Previous dimensions | Current dimensions |
| --- | --- | --- |
| Valeggio / Saint Martin / The Heights | 2880×1920 | **5760×3840** |
| Italy / Mantua campaign | 8640×5760 | **17280×11520** |
| Danube campaign | 2880×1920 | **5760×3840** |

Each has four times its preceding area. Dimensions are game coordinates,
not kilometers. New battles add broad ridges, ten woodland districts, six
outer settlements, roads and five total crossings on river maps. The larger
Mincio exercise starts the fronts and reserves farther apart, leaving actual
approach and maneuver space. Troop size, gun range and marching pace remain
physical distances; reinforcements enter from the real perimeter.

Campaign geography retains its existing towns and objectives, spread over
more space. No new provinces or historical orders of battle were invented.
Longer marches affect operational timing; sight and reinforcement reach do
not automatically grow with geographic spacing.

Campaign map version 4 migrates all strategic coordinates once, including
paths, intelligence, enemy homes, pending battles and operational sites.
An existing version-3 native save receives a `.pre-grand-map.bak` backup;
previous migration backups remain intact. Money, troops, experience, morale
and campaign time do not change. Existing active battlefield versions 1 and 2
retain their own dimensions, positions and orders. New battles use version 3.
Validation uses isolated test saves and does not write the player's campaign.

## Shared environment and interface

- All three battle scenarios and campaigns use painted meadow, worked earth,
  stubble and limestone materials with coherent cultivation and settlement
  masks on the actual relief mesh. Crop surfaces cannot intersect the hill
  because there is no separate crop plane.
- Larger central parcels, quiet river meadows and sparse outer cultivation
  replace the collection of disconnected small field patches. Woods feather
  into darker ground and smaller edge trees; additional town groves break up
  exposed scenery.
- A new original six-tree sheet has irregular open branches and subdued
  olive foliage. Tree roots and building feet meet their real terrain anchor.
  Canopy and building shadows shade the ground and passing figures. Existing
  architecture is batched by its six paintings; major/minor new-map towns
  support 22/14 houses when road/water/spacing constraints permit.
- Broad hills use gradual grades rather than sharply raised knolls. The
  river floodplain has a bounded grade. Surface normals, painted lighting,
  footing, LOS and actual rendered terrain use the same sampled surface.
- The charcoal and brass command rail is quieter and shorter. Desktop roster
  cards are 112 pixels wide, retaining strength, state, morale and fatigue;
  twelve fit where roughly nine did previously. Existing unit art is reused.

## Performance and verification

The previous tactical spatial index, reduced visual steering frequency and
GPU interpolation remain in place. Static cultivation, yards and canopy
shadows rasterize once per map using Godot's native SVG image loader, with
mipmaps. There are no per-frame landscape bakes. Ground height surfaces use a
bounded six-entry cache with separate model-owned arrays. Road-nearness queries
use a spatial segment index; exact unbounded distance queries remain available.
House routes are prepared while a battle map loads to avoid delaying the first
order through a settlement. No regiments or figures were removed for this pass.
SVG fragments are joined once rather than repeatedly copying the whole shadow
document. Warm-cache native main-scene startup measured **4.36 seconds**; the
isolated headless campaign scene check measured **4.53 seconds** with 10,768
decorative trees and 259 buildings. These are separate loading measurements,
not frame-rate measurements.

Focused checks are in `tests/grand_landscape.gd`. Headless checks exercise
new bounds and populated outskirts, actual peripheral marching, exact road
queries, height-cache isolation, legacy battle save/load and all five crossings
in both directions with infantry, cavalry and artillery. Native checks capture
all scenarios and the campaign, exercise angle controls, verify true scenery
root positions and check terrain picking and sprite selection at 28°, 35°,
50° and 60°. Movement, terrain, campaign migration, town-entry, animation and
fixed-rate performance suites provide additional coverage.

Reproduce from this directory:

```text
godot --headless --path . --script res://tests/grand_landscape.gd
godot --path . --script res://tests/grand_landscape.gd -- --visual
godot --path . --script res://tests/performance.gd -- --after --all-visible
godot --path . --script res://tests/performance.gd -- --after --combat --long
```

The last two commands are uncapped native benchmarks, not normal game settings.
They record actual rendered figure counts, map size, pitch, simulation timings
and frame-time distribution. The explicit `--all-visible` case exposes both
armies continuously; older measurements that let visibility be recalculated
are not equivalent. Crowded melee can still hitch, and a larger landscape
alone does not establish a constant frame-rate guarantee.

Native measurements at 1440×900 on the RTX 3070 Ti machine, Compatibility
renderer, 35° camera, 30 Hz tactical clock, no other Godot instance running:

| Scenario | Rendered figures | Mean FPS | Median / p95 / worst frame, ms |
| --- | ---: | ---: | --- |
| Normal visibility, 12 versus 12 | 648 | 157.8 | 3.99 / 18.43 / 36.07 |
| Normal visibility, 20 versus 20 | 1,333 | 100.7 | 5.10 / 34.09 / 85.31 |
| Both armies forced visible, 12 versus 12 | 1,294 | 55.8 | 9.72 / 67.05 / 89.89 |
| Both armies forced visible, 20 versus 20 | 2,664 | 31.5 | 14.67 / 274.12 / 358.37 |

Normal visibility retained approximately 30 simulation ticks per second.
The exposed 20-versus-20 stress case fell to 26.8 ticks per second. All-visible
stress runs preceded the final small road-cache/UI layout adjustments; they
show an unresolved dense-scene limit, not a claim of smooth maximum-scale play.
Raw distributions and actual counts are in `test-results/performance-grand-after.json`
and `performance-grand-after-exposed.json`. The older `performance-fixed-*`
archives remain intact; current runs with `--legacy-maps` write to the separate
`performance-grand-legacy-*` prefix.

A final 60-FPS-capped fire/melee stress drill measured **54.2 FPS** with 1,385
figures and **27.7 FPS** with 2,532 figures. The latter retained 30.2 simulation
ticks/second but reached a 112.80 ms p95 and 183.24 ms worst frame. See
`test-results/performance-grand-after-long-combat-60fps.json`. The same current
renderer on the legacy map measured 52.2 uncapped FPS with 2,533 combat figures.
The enlarged densely engaged case therefore remains a material performance
limitation; further work is needed before promising smooth maximum-scale combat.

Focused validation passed: grand-map rules **47**, native camera/input/scenery
**26**, native expanded-map/overview/input **127**, native animation **208**, native slope/footing **67**, native themed UI
**190**, terrain relief **75**, campaign map migration **98**, operations
**189**, town movement **223**, combat motion **87**, and polish **153** checks.
Native interpolation checks passed **75** earlier in this pass. Each reported
suite finished with zero failures. The player's Mantua save remained byte-identical
through validation (SHA256 `da60b1cd875ecbe732311989fcff6d69df4e579a62fecd8f8e325f646d3c4a4a`).

Representative captures: `test-results/grand-landscape-command.png`,
`grand-landscape-village.png`, `grand-landscape-village-field.png`,
`grand-landscape-ridge-field.png`, `grand-landscape-overview.png`,
`grand-landscape-tilt-28.png`, `grand-landscape-tilt-60.png` and
`grand-landscape-campaign.png`. Earlier command/village images are preserved
as `grand-before-command.png` and `grand-before-village.png`.

## Original generated asset provenance

Mode: **built-in image generation**, not CLI/API fallback. New images were
generated from text. Existing game art was not supplied as an edit reference.
The tree atlas is registered/cropped at runtime into six textures; source
pixels are preserved. No troop animation or uniform atlas was regenerated.

### Woodland

Selected repository asset: [`assets/woodland-v4.png`](assets/woodland-v4.png).
Source: `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-17f4bca5-a70f-4037-92de-ee99ca84c20b.png`.
Actual size: 1536×1024, transparent. A later layout-only retry was not selected.

Generation prompt:

> Use case: historical-scene. Asset type: ORIGINAL production transparent woodland sprite atlas for a refined painterly Napoleonic battlefield game, northern Italy circa 1796. Strict 3 equal columns by 2 equal rows, six separate complete trees, one in each cell, landscape 1536x1024. Camera high oblique approximately 45 degrees above horizon, orthographic, see crowns as well as branching trunks. Top row: mature spreading oak with asymmetrical broken airy canopy; slender tall Lombard poplar; broad medium ash with open branching. Bottom row: irregular elm with a spreading uneven crown; small orchard tree with a rough crooked trunk; low bushy hawthorn with sparse foliage. Understated realistic painted historical tactical game style like Ultimate General battlefield landscapes: soft fine foliage masses and clearly legible branches, restrained natural gray olive, moss and sage, occasional warm dry leaves, subdued highlights, cool brown bark. Visually intricate but quiet at small game scale. Avoid ball-shaped broccoli crowns, bright lime highlights, glossy miniature render look, exaggerated thick trunks, black outlines, uniform foliage blobs, or front-elevation botanical specimens. One soft consistent sun from upper left, natural dimensional self-shadow within the crown. No cast shadow or ground patch; engine will supply ground shadows. Complete silhouette including every branch and roots fits inside each cell with 10% transparent padding. All cells have exactly the same perspective. GENUINELY TRANSPARENT alpha background and transparent gaps among branches and leaves. No scenery, ground, grass, hills, buildings, people, text, frames, grids, borders, watermark, opaque backdrop or checkerboard. Original art, do not copy any existing game's assets.

### Terrain materials

Selected repository asset:
[`assets/terrain-materials-v3.png`](assets/terrain-materials-v3.png).
Source: `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-16a77906-9e59-4bbd-a1b7-f7276040c93f.png`.
Actual size: 1254×1254, opaque; four equal quadrants sampled by the terrain shader.
Requested dimensions were 2048×2048; the selected output remains at its native size.

Generation prompt:

> Use case: historical-scene. Asset type: original production terrain MATERIAL atlas for a painterly historical tactical battlefield, 2048x2048 square. EXACTLY TWO equal columns and TWO equal rows, four 1024x1024 material tiles. Truly straight-down orthographic albedo, evenly lit, no height shading or perspective. Each tile represents about 80 meters of ground, with fine grounded natural detail and larger quiet surface variations. TOP LEFT: closely grazed dry olive and sage meadow with sparse straw, tiny bare earth gaps, subtle tufts; TOP RIGHT: worked grey umber agricultural earth, realistic irregular fine plough furrows running vertically, slight stony gaps and dry clods; BOTTOM LEFT: harvested ochre wheat stubble with delicate parallel crop rows, trampled straw and subtly uneven dry soil; BOTTOM RIGHT: weathered grey limestone bedrock, angular irregular exposed stone slabs, small warm grey fractures, lichen and stony rubble, matte surface, no tall rocks or perspective. Refined naturalistic painted 19th-century tactical wargame landscape treatment, finely brushed realistic illustrated terrain like Ultimate General Civil War, not a cartoon or coarse concept painting. Rich subdued tonal detail that remains coherent at command-view scale. NOT photoreal macro photography, not noisy gravel, not canvas weave or impasto strokes. Understated dusty olive, grey umber, warm straw ochre and pale limestone; avoid neon green, orange dirt and saturated gold. No trees, bushes, buildings, people, soldiers, roads, rivers, shadows, hills, horizons, fields painted inside tiles, grid lines, borders, text or watermark. Four strictly equal fully filled material squares, original artwork, no copied game assets.
