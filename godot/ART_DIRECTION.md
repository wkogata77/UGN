# Native Battlefield Art Direction

The October 26 [grand landscape pass](GRAND_LANDSCAPES.md) supersedes the
environment, camera, map-size and roster presentation below. It extends the
painted terrain treatment to every scenario and the campaign while preserving
the existing troop artwork. New generated asset prompts and provenance are in
that document.

The Valeggio benchmark below is the preceding scoped environment pass. The earlier
environment work follows it for provenance. The subsequent
[native polish pass](POLISH_PASS.md) supersedes the woodland, selection,
mounted/gun/wagon animation and headquarters limitations described below.

## Valeggio Benchmark, September 30

The installed Ultimate General: Civil War illustrated manual was inspected
read-only, particularly its altitude, deployment, battle-interface and strategic
point screenshots. These informed terrain composition, contact with scenery,
and lighter battlefield UI, not asset extraction. No installed game resources
are included in this project. Its exact playable dimensions were not established.

`scripts/valeggio.gd` supplies presentation for crossing battles: 22 authored
farm parcels across the large map (11 on legacy maps), lanes and yards connected
to the existing houses, low verge growth, river stones and three open-arch stone
bridges. Cultivation and yard masks shade the actual terrain mesh, avoiding
extra field planes intersecting slopes. Forest edges use smaller, irregularly
spaced trees and darker ground. River current, damp banks, broken road shoulders
and fine original meadow grain replace the regular ripple and broad repeated
ground appearance at this location. The minimap shows the authored parcels and
actual woodland regions. Other scenarios and campaign scenery keep their art.

Crossing positions, deck height, roads used for marching, building collision,
terrain relief, fortification slots, LOS and troop scale are unchanged. The
low shrubs and stones are decorative, not new cover. Existing saves need no
migration. This is an authored interpretation, not a surveyed historic Valeggio
or a copy of an Ultimate General map.

All tactical maps now have lighter 100x35 unselected strength/name markers.
Selected units, urgent warnings and AI diagnostics retain expanded detail;
morale, fatigue, enemy wavering, label selection and sprite selection remain.
The battle title and objective panel are smaller; the existing command roster,
headquarters, campaign labels and troop sprites remain intact.

Run `Valeggio Preview.cmd` or pass `--valeggio-demo` to open a paused, isolated
battle exercise without loading or autosaving a campaign. The regular battle
exercise and saved crossing battles use the same presentation.

### Original Meadow Asset

Built-in image generation was used, not the CLI/API fallback. Selected image:
`assets/valeggio-meadow-v1.png`. Original retained at
`/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-caa7030d-1b2d-48e5-b8b4-d33cdbc857e4.png`.
The existing terrain atlas is preserved. Final generation prompt:

> Use case: historical-scene. Asset type: original production seamless ground albedo texture for a painterly high-oblique Napoleonic tactical game in rural northern Italy. Primary request: a truly top-down square 2048x2048 tile of natural closely grazed meadow, fine interwoven muted sage and olive grasses, small dry straw flecks, occasional tiny earthy gaps and pebbles. The image covers a large 40-metre patch: individual blades are tiny, most detail is fine and delicate, subdued irregular patches rather than oversized blades or repeated clumps. Fine realistic painted game texture with natural organic variation, not photoreal macro photography, no broad brush swirls or canvas weave. Quiet medium-value cool sage, moss and gray-green with modest dry ochre accents, balanced contrast, no neon yellow green. Completely evenly lit diffuse albedo, no directional cast shadows, no elevation shading, no central vignette. Seamless edge-to-edge tiling, consistent detail scale across whole image. No fields, geometric parcels, rows, roads, paths, trees, shrubs, hills, rivers, buildings, people, UI, text, icons, borders, or watermark. This is original texture artwork, not a screenshot and not copied from any existing game.

### Verification

`tests/valeggio.gd` provides separate headless layout checks and native rendering,
click/move, pause, legacy-map, diagnostic-label and viewport checks. Native
screenshots and logs use the `test-results/valeggio-*` prefix. Run:

```text
godot --headless --path . --script res://tests/valeggio.gd
godot --path . --script res://tests/valeggio.gd
```

The native runner measures frame and simulation time separately. A roughly
one-second simulation tick was observed during the active-battle sample; this
visual pass is not a certification that larger battles meet a smoothness budget.
No combat or AI rules were changed to conceal that measurement.

Final September 30 checks: 626 headless assertions passed (8 benchmark, 91 map,
51 terrain relief, 153 polish and 323 weapons), plus 673 native visual/input
assertions. The native run produced center, overview, bridge, village, orders,
narrow-window, legacy, Saint Martin and Heights control screenshots, with no
runtime or shader errors. Its 120-frame active sample at 1440x900 measured
28.70 ms median, 33.09 ms p95 and 986.14 ms worst; the corresponding worst
simulation tick was 985.55 ms. These are a short local sample, not a universal
performance guarantee or a claim that the simulation hitch is fixed.

## Direction And Scope

This pass moves Field Command toward the restrained, naturalistic painted
battlefield presentation the user likes in Ultimate General. It retains the
existing Napoleonic soldiers and orders rather than copying another game's
maps, sprites, interface artwork, or branding. It is not a pixel-identical
recreation, full 3D character conversion, or historically surveyed Italy map.

Visual references: the official [Ultimate General: Civil War gallery](https://www.ultimategeneral.com/ug-civil-war.html),
especially [battlefield overview](https://www.ultimategeneral.com/gui/civil-war/ss-3_1.png)
and [town and farmland](https://www.ultimategeneral.com/gui/civil-war/ss-3_5.png).
References were viewed outside the project; their pixels are not shipped.

## Integrated Assets

All four selected originals were produced with the **built-in imagegen tool**.
No CLI/API fallback was used. Original legacy files remain intact.

| Native project file | Contents |
| --- | --- |
| `assets/terrain-v2.png` | Quiet meadow, straw and tilled-field albedo; both maps and minimap |
| `assets/woodland-v2.png` | Six individual painted tree variants with real alpha |
| `assets/architecture-v2.png` | Six separate northern Italian building variants with real alpha |
| `assets/smoke-v2.png` | Six translucent gunpowder clouds for musket and cannon volleys |

Trees mix species, size, and mirroring inside the existing woodland regions.
Native atlas regions include complete silhouettes and are cached as separate
runtime textures; transparent margins are trimmed without editing source art.
Villages are assembled from individual buildings, avoiding river and road
centers. Buildings remain cosmetic: this does not add building entry or cover.
Soft woodland-floor shading extends across the padded map without a hard edge.

Existing troop atlases are unchanged. Their world size is reduced and their
rendered colors slightly restrained to sit more naturally among scenery.
Smaller on-map labels retain strength, morale, and fatigue; inspectors and
battle roster remain available. Selection targets and tactical rules are unchanged.

Painted smoke is batched, fades and drifts on the simulation clock, stays at
the firing origin when a regiment moves, and freezes while paused. It is a
cosmetic effect, not a new visibility or damage rule. The subsequent
[infantry animation pass](INFANTRY_ANIMATION.md) adds two painted walking
frames and a separate idle pose for infantry. Mounted troops, guns, generals,
and wagons still use their existing articulated sprites.

## Prompts

### Terrain

Use case: historical-scene. Asset type: production terrain albedo bitmap for the native Godot Napoleonic tactical game Field Command, landscape 3:2 at the highest available resolution, preferably 3072x2048. Create an ORIGINAL hand-painted overhead countryside surface with the restrained realistic battlefield art direction associated with Ultimate General: Civil War. Do not reproduce any existing game's map. Northern Italy circa 1796 in spring: subdued grey-sage pasture and dusty pale olive grass, a few large irregular dry straw fields and freshly tilled grey umber parcels, extremely fine ground detail and sparse stony soil. Quiet broad open spaces suitable for hundreds of very small soldiers, 60 percent meadow. Larger coherent agricultural parcels, not dozens of tiny checkerboard patches. Fine painted gouache/oil treatment with realistic natural mottling, no conspicuous impasto brush strokes. Truly straight-down orthographic albedo surface: no perspective, horizon, distant hills or dark distance gradient. Even diffuse daylight, no painted height shading because engine adds real relief and sunlight. No trees, shrubs, forests, buildings, houses, roads, tracks, rivers, ponds, fences, units, people, text, UI, border, grid or watermark. Natural muted colors with balanced cool greens, dry yellow grasses, and grey earth; avoid vivid lime green, strong yellow cast, brown monochrome, high-contrast repeated furrows, artificial checkerboard, glossy 3D-render style. Complete full-bleed ground surface, subtle consistent detail at all four edges; not a screenshot or concept scene.

Selected original: `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-34db9d60-3bd2-435f-a333-9c6511af4969.png`.

### Woodland

Use case: historical-scene. Asset type: one original production-ready transparent woodland sprite atlas for a painterly Napoleonic tactical game, THREE equal columns by TWO equal rows, landscape 3:2, preferably 1536x1024. EXACTLY six isolated European deciduous trees, one complete tree per equal cell. Row1: broad mature oak with irregular airy crown; tall slender poplar with sparse small branches; medium ash with open branching. Row2: a smaller multi-stem willow; an uneven mature elm; sparse weathered oak with some bare branches. Viewed from a tactical camera 52 degrees above the horizon, predominantly crowns but clearly visible lower trunks and branches. Realistic finely hand-painted historical wargame art in the restrained natural style of Ultimate General battlefields, delicate irregular leaves and visibly branching structure, NOT a cartoon spherical clump, not thick broccoli foliage, not glossy miniature toys. Spring in Northern Italy, dusty sage, subdued silver green, moss and grey bark, no bright yellow or neon. Consistent soft light from upper left, restrained highlights; no large cast shadow (the engine supplies shadows). Generous empty alpha around each individual tree, every trunk root at local cell y=92%, crown top no higher than 8%, all twigs remain between cell x=8% and92%. No overlap between cells, no scenery, grass, ground tiles, floating dirt islands, buildings, people, text, grid lines or labels. Genuinely TRANSPARENT alpha background across the entire atlas and all gaps between twigs and leaves, NOT a painted checkerboard and NOT a solid backdrop. Original art only; not copied game sprites.

Selected original: `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-61b15b8c-1d6b-4fa1-a10b-171e90270293.png`.

A subsequent layout-only retry produced an opaque checkerboard and was rejected
by alpha inspection. It is not included or referenced. The first generated
atlas has genuine RGBA transparency; custom runtime regions handle its irregular
spacing without the rejected edit.

### Architecture

Use case: historical-scene. Asset type: original transparent architectural sprite atlas for a Northern Italy 1796 real-time tactical wargame in a realistic finely painted Ultimate General-like battlefield art direction. EXACTLY THREE equal columns and TWO equal rows, six complete separate buildings, one per cell, landscape 1536x1024. Camera is high oblique at 52 degrees above horizon, roofs dominate but side walls are visible; orthographic, consistent scale, no perspective horizon. Row1 left to right: modest two-story pale weathered plaster farmhouse with faded clay tile roof; long low agricultural barn with grey slate and stone walls; small Lombard village church with simple square bell tower and muted tile roof. Row2: L-shaped stone farmstead without an enclosed ground courtyard; narrow two-story ochre-plaster town house with shutters and faded tile roof; a small rough stone storehouse with lean-to. Fine restrained realistic painted surface detail, softly weathered masonry, tiny timber doors, faded roof tiles, dusty warm grey and stone with restrained terracotta, never saturated orange, never toy-like chunky outlines or glossy render. Soft light from upper left. FULL buildings and towers comfortably inside their cell with at least 12 percent transparent padding all around, base at local y=85%, center horizontally. GENUINELY TRANSPARENT alpha background and gaps, no painted checkerboard, no scenery or studio backdrop, no ground patches, no roads, no trees or shrubs, no grass, no big shadow puddles, no people, no modern objects, no text, labels, lines or watermark. Engine will assemble buildings into villages on its actual terrain. Do not copy any existing game's assets or literal building models.

Selected original: `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-991344fa-9c54-4390-b45c-299082ccfd19.png`.

### Gunpowder Smoke

Use case: historical-scene. Asset type: one original production smoke sprite atlas for a realistic painterly Napoleonic tactical game. Landscape 1536x1024, EXACTLY THREE equal columns by TWO equal rows, SIX isolated translucent gunpowder smoke clouds. These are visual effects assets, not a battle scene. Each cloud consists of a soft turbulent irregular billowing wisp of pale warm grey smoke with cool grey inner folds, almost white thin sunlit edges, with uneven gaps and genuinely translucent fading edges. Top row: small compact musket puff; wider drifting volley puff; thin dissipating wisp. Bottom row: dense cannon smoke puff; medium spreading smoke cloud; nearly dissipated translucent smoke. All six clouds centered in their own cell with at least15percent empty alpha padding, no cloud overlaps another cell or touches edges. Refined soft hand-painted historical battlefield aesthetic, no crisp geometric circles, no black soot, fire, explosion, sparks, objects, cannon, soldiers, ground, sky or scene. GENUINELY TRANSPARENT alpha background, no checkerboard, no opaque studio backdrop, no text or labels. Smoke itself should be softly translucent rather than a hard opaque sticker. Viewed from high oblique battlefield camera, dimensional but diffuse. Original artwork.

Selected original: `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-4167b05c-abd1-4901-8050-ef6ab78960ab.png`.

## Verification

The native graphical suite checks actual alpha and cached sprite regions,
tree variety and road clearance, buildings and their road clearance, terrain
and shadow pixels, smoke emission and anchoring, pause, desktop/mobile inputs,
map framing, animations, multi-unit facing previews, and active-battle performance.
Captures and exact results are written to `test-results/verification.json`.
New close-ups include `campaign-woodland-art`, `campaign-village-art`,
`battle-woodland-art`, `battle-village-art`, and each unit type's smoke.

Further fidelity work remains in period-specific architecture, hit/death frames,
and continued unit/terrain scale and lighting review. The October 25 pass adds
an authored Mincio exercise and expanded walking, charging and gun-crew cycles.

## Battlefield polish animation assets — October 25, 2026

Generated with the built-in image-generation tool, using our existing painted
Napoleonic sprites as uniform and style references. Original reference-game art
was not copied. All six selected images are stored in this project's `assets/`
folder; source images and exact prompts are recorded below. Existing atlases stay
available for directional firing, melee, generals and supply wagons.

Infantry uses eight columns and five direction rows, including diagonal views,
four marching poses, aiming, ramming and priming. Cavalry has six columns and five
rows, including separate extended/gathered charge poses. Artillery has seven
columns and three rows: idle, two moving poses, firing, swabbing, ramming and
priming. Runtime registration shares scale and foot baselines within each row.
Brief crossfades connect painted poses and movement follows traveled distance.
Front/rear infantry firing retains the earlier directionally correct paintings
where the generated atlas did not preserve the weapon direction well enough.

### infantry-cycle-french-v2.png

Project asset: `assets/infantry-cycle-french-v2.png`.
Selected original: `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-71297b28-b97d-41b9-ae81-f509455d2912.png`.

Exact prompt:

Create a NEW production sprite atlas, the input is a UNIFORM AND PAINTED STYLE REFERENCE only. Preserve this exact Napoleonic soldier identity, proportions, equipment and refined painted miniature finish. STRICT EIGHT equal COLUMNS by FIVE equal ROWS, 40 complete isolated full-body soldiers on pure flat #ff00ff magenta background. Landscape 3072x1920 preferred. No labels or grid lines. ROWS, top to bottom: side facing RIGHT; three-quarter rear facing diagonally RIGHT and AWAY; directly REAR facing AWAY; three-quarter front facing diagonally RIGHT and TOWARD; directly FRONT facing TOWARD. COLUMNS, left to right, repeat these exact eight actions in EACH direction: 1 planted idle with musket at shoulder; 2 left-foot forward walking; 3 left-leg planted, right leg passing under hips; 4 right-foot forward walking, opposite column2; 5 right-leg planted, left leg passing under hips; 6 aim musket braced at shoulder, ready to fire; 7 musket butt on ground, ramrod held at muzzle for loading; 8 musket angled across body, both hands near breech priming the pan. In walking columns change mostly legs, keep torso and gun steady; footfall baselines, head and body scale registered within each row. In every cell the entire soldier and full musket/bayonet fit with 12% margins. No extra limbs, duplicates, smoke, flashes, ground, shadows, scenery, text or borders. Forty equal cells exactly, with consistent framing. This is original game art.

### infantry-cycle-austrian-v2.png

Project asset: `assets/infantry-cycle-austrian-v2.png`.
Selected original: `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-7d1cd038-bacd-4328-a9f7-70396c6cd9c7.png`.

Exact prompt:

Create a NEW production sprite atlas, the input is a UNIFORM AND PAINTED STYLE REFERENCE only. Preserve this exact Napoleonic soldier identity, proportions, equipment and refined painted miniature finish. STRICT EIGHT equal COLUMNS by FIVE equal ROWS, 40 complete isolated full-body soldiers on pure flat #ff00ff magenta background. Landscape 3072x1920 preferred. No labels or grid lines. ROWS, top to bottom: side facing RIGHT; three-quarter rear facing diagonally RIGHT and AWAY; directly REAR facing AWAY; three-quarter front facing diagonally RIGHT and TOWARD; directly FRONT facing TOWARD. COLUMNS, left to right, repeat these exact eight actions in EACH direction: 1 planted idle with musket at shoulder; 2 left-foot forward walking; 3 left-leg planted, right leg passing under hips; 4 right-foot forward walking, opposite column2; 5 right-leg planted, left leg passing under hips; 6 aim musket braced at shoulder, ready to fire; 7 musket butt on ground, ramrod held at muzzle for loading; 8 musket angled across body, both hands near breech priming the pan. In walking columns change mostly legs, keep torso and gun steady; footfall baselines, head and body scale registered within each row. In every cell the entire soldier and full musket/bayonet fit with 12% margins. No extra limbs, duplicates, smoke, flashes, ground, shadows, scenery, text or borders. Forty equal cells exactly, with consistent framing. This is original game art.

### cavalry-cycle-french-v2.png

Project asset: `assets/cavalry-cycle-french-v2.png`.
Selected original: `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-21430a43-d49c-42c5-89ce-75c2a1e8397c.png`.

Exact prompt:

Create a NEW production cavalry sprite atlas. Input is a UNIFORM, HORSE AND PAINTED STYLE REFERENCE only; preserve the exact Napoleonic rider and horse identity, proportions and refined painterly finish. STRICT SIX equal COLUMNS by FIVE equal ROWS, thirty complete rider-and-horse sprites on flat pure #ff00ff magenta. Landscape 3072x2560 preferred, no labels or grid. ROWS top to bottom: side facing RIGHT; three-quarter REAR facing RIGHT and AWAY; directly REAR facing AWAY; three-quarter FRONT facing RIGHT and TOWARD; directly FRONT facing TOWARD. COLUMNS left to right repeated in every row: 1 idle, all four hooves planted; 2 walking left foreleg/right hindleg forward; 3 passing step, weight balanced, moving hooves under body; 4 walking opposite right foreleg/left hindleg forward; 5 charge gallop EXTENDED, front legs reach forward and hind legs stretch backward, rider leans slightly forward; 6 charge gallop GATHERED, legs tucked under body, visibly different from column5. Four horse legs only. Preserve saddle, horse torso, rider head, size and location within each row; no jumping or rearing, saber carried safely. Full rider, sword, horse, ears, tail and hooves inside each equal cell with 10% margins, common hoof baseline and consistent body scale. No scenery, smoke, floor, cast shadows, text, grid or extra subjects. Original game sprite art.

### cavalry-cycle-austrian-v2.png

Project asset: `assets/cavalry-cycle-austrian-v2.png`.
Selected original: `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-69ee5ad2-66d1-4b44-aa2e-e626af7f2114.png`.

Exact prompt:

Create a NEW production cavalry sprite atlas. Input is a UNIFORM, HORSE AND PAINTED STYLE REFERENCE only; preserve the exact Napoleonic rider and horse identity, proportions and refined painterly finish. STRICT SIX equal COLUMNS by FIVE equal ROWS, thirty complete rider-and-horse sprites on flat pure #ff00ff magenta. Landscape 3072x2560 preferred, no labels or grid. ROWS top to bottom: side facing RIGHT; three-quarter REAR facing RIGHT and AWAY; directly REAR facing AWAY; three-quarter FRONT facing RIGHT and TOWARD; directly FRONT facing TOWARD. COLUMNS left to right repeated in every row: 1 idle, all four hooves planted; 2 walking left foreleg/right hindleg forward; 3 passing step, weight balanced, moving hooves under body; 4 walking opposite right foreleg/left hindleg forward; 5 charge gallop EXTENDED, front legs reach forward and hind legs stretch backward, rider leans slightly forward; 6 charge gallop GATHERED, legs tucked under body, visibly different from column5. Four horse legs only. Preserve saddle, horse torso, rider head, size and location within each row; no jumping or rearing, saber carried safely. Full rider, sword, horse, ears, tail and hooves inside each equal cell with 10% margins, common hoof baseline and consistent body scale. No scenery, smoke, floor, cast shadows, text, grid or extra subjects. Original game sprite art.

### artillery-cycle-french-v2.png

Project asset: `assets/artillery-cycle-french-v2.png`.
Selected original: `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-74281201-53d2-4c99-98fe-cb3ec6ba93fb.png`.

Exact prompt:

Use case: identity-preserve. Produce an original expanded animation atlas derived from the supplied artillery sprite reference, keeping exactly the same painted brass field cannon, timber carriage, TWO crew and Napoleonic uniforms. STRICT SEVEN equal COLUMNS and THREE equal ROWS, 21 complete gun-and-crew groups on pure flat #ff00ff magenta, landscape 3584x1536 preferred. ROWS: side facing RIGHT; directly REAR with barrel pointing AWAY; directly FRONT muzzle toward camera. COLUMNS in every row: 1 idle ready crew upright; 2 pushing the gun left-foot step; 3 pushing opposite right-foot step with wheel spokes turned; 4 firing recoil, crew braced, cannon has rolled back slightly, NO smoke; 5 SWAB, one man holds sponge rammer at muzzle, other tends ammunition; 6 RAM, man pushes rammer into barrel with both hands and leans forward, other prepares fuse; 7 PRIME, rammer withdrawn, gunner crouches at breech and other stands clear. All seven actions clearly different, common scale, cannon wheel centers and ground baseline precisely registered within each row. Full men, wheels, barrel and ramrods INSIDE each cell with generous 10% empty margins. Exactly two crew per cell, same uniform as reference. No floor, shadows, text, grid, scenery, flashes or smoke. Beautiful painterly strategy-game art, not toy render. Maintain coherent machinery and human anatomy.

### artillery-cycle-austrian-v2.png

Project asset: `assets/artillery-cycle-austrian-v2.png`.
Selected original: `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-b9bc0348-7c72-4b19-bfbc-7a411f750ac1.png`.

Exact prompt:

Identity-preserve edit. Image1 is the EDIT TARGET: a strict SEVEN-column THREE-row, twenty-one-cell artillery action atlas. Image2 is AUSTRIAN UNIFORM REFERENCE ONLY. Change ONLY all crew uniforms in Image1 to the white Austrian coats and trousers, red facings, dark headgear and belts of Image2. Preserve exactly the seven by three equal grid, all twenty-one cannon-and-two-crew poses, wheel centers, baselines, framing, ramrods, barrel directions and pure #ff00ff magenta background. Keep full men and equipment inside their cells. No French blue coats remain. Do not change gun shape, pose, scale, image dimensions, layout or add text, smoke, floor or scenery.
