# Original Game Art

All generated assets use the built-in imagegen tool. They are original assets;
no Ultimate General screenshots or extracted game resources are shipped.

## Terrain

Saved at `public/assets/terrain.png`. The game draws its functional forests,
towns, roads, river, bridge crossings, and units over this base image.

Prompt:

> Use case: historical-scene. Asset type: original terrain base bitmap for a playable top-down Napoleonic strategy game, landscape 3:2, high resolution. Draw a polished richly detailed hand-painted aerial map of southern German countryside in early autumn, viewed straight down orthographic, filling entire frame edge to edge. Soft natural daylight. Beautiful intricate miniature ground texture, natural muted sage and grass green meadows interspersed with small irregular cultivated field parcels in faded straw ochre and cool green, ploughed furrows, subtle hedgerow boundaries, gentle rolling grassy hills. Most of the map is open grassy terrain suitable for drawing thousands of tiny soldiers on top. Atmospheric but crisp richly textured painterly style of a premium historical tactical wargame. The ground must be well lit and very legible, no strong shadows. No buildings, no villages, NO trees or forests, NO rivers or water, NO roads (all these are added as separate game layers). No people, no soldiers, no UI, no text, no labels, no compass, no border or frame, no grid, no perspective horizon. Use small landscape features to convey a broad area of several kilometers, not a close-up photograph of grass. Save the generated asset for use in the local project.

## Forest Canopy

Saved at `public/assets/trees.png`. Rendered as varied, overlapping transparent
sprites inside the simulation's woodland regions.

Prompt:

> Use case: historical-scene. Asset type: transparent background sprite for a premium painterly Napoleonic top-down strategy game. Create a single compact clump of three overlapping mature European deciduous trees as seen from an almost straight-down aerial camera. Original hand-painted realistic game art with exquisite tiny foliage texture and irregular branching canopy edges, sage green, moss green and subtle autumn muted yellow flecks. Soft daylight from upper left, soft transparent ground shadow to bottom right. The trees fill 85% of square frame centered with plenty of fully transparent margin. No ground, no grass, no terrain, no scene background; genuinely transparent alpha around the tree clump. No trunk sticking out at bottom, no perspective horizon, no cartoon circular shapes, no text, no UI. Intended to be rendered as repeated small forest canopy sprites over a detailed overhead grass terrain bitmap, so irregular silhouette and finely detailed naturalistic leaves are essential.

## Village

Saved at `public/assets/village.png`. Used for campaign towns and the battlefield
hamlet.

Prompt:

> Use case: historical-scene. Asset type: transparent background village sprite for a premium hand-painted Napoleonic historical tactical wargame. A tiny rural southern German hamlet circa 1805, roughly 9 small traditional plaster farmhouses with weathered rust-red and grey pitched roofs and a small church tower, organically clustered with narrow gaps, seen almost straight down from a high aerial game camera. Buildings are dimensional but predominantly show roofs and a little side wall, matching top-down strategy game perspective. Exquisite finely painted architectural textures, subtle ambient shadows, softly lit from upper left. Compact irregular village silhouette centered filling 85% of image. Entire background must be genuinely transparent alpha, with no ground, grass, field, square tile, roads, sky, border, text, UI or labels. Leave transparent gaps between buildings so the game terrain can show through. Detailed realistic miniature painterly game art, never geometric low-poly or cartoon.

## Visual Reference

The interface and terrain direction were informed by the official
[Ultimate General: Civil War Steam screenshots](https://store.steampowered.com/app/502520/Ultimate_General_Civil_War/).

Engine and navigation references:

- [Phaser getting started](https://docs.phaser.io/phaser/getting-started/making-your-first-phaser-game)
- [PathFinding.js](https://github.com/qiao/PathFinding.js/)

## Fonts

Inter and Cormorant Garamond are bundled from their Fontsource packages. Their
licenses are included in those packages under `node_modules/@fontsource/`.

## Officer Portraits

Saved at `public/assets/officers.png`. Original 4-by-4 bitmap portrait atlas,
used by army organization, regiment details, and officer recruitment. Napoleon
is the first portrait; remaining officers are fictional. Mode: built-in imagegen,
new image generation, no reference images. No API fallback was used.

Prompt:

> Use case: historical-scene. Asset type: one production-ready portrait atlas for a Napoleonic strategy game, 4 columns by 4 rows, sixteen exactly equal square cells, edge-to-edge no gaps, no borders, no text. In every cell a distinct hand-painted realistic early-1800s French military officer bust, head and shoulders, facing forward or subtle three-quarter. Classic refined oil portrait illustration, detailed readable faces, softly lit neutral charcoal gray studio backdrop throughout, no scenery. First cell top left is Napoleon Bonaparte in dark green colonel uniform and black bicorne, unmistakably recognizable likeness. Remaining fifteen are fictional officers: varied adult ages from 28 to 65, different facial shapes, dark/gray/blond hair, several sideburns and a few moustaches, no modern beards. French dark navy coats, red or white facings, brass epaulettes and gold embroidery, some with black bicornes and some bareheaded. Each bust centered with full top of head and epaulettes inside its cell, face occupies upper-middle 45 percent of cell, fine balanced painterly quality for use at 60-150px. Subtle blue, burgundy and brass accents, natural skin. No labels, no watermark, no UI. Square output 2048x2048 if available.

## Armory Illustrations

Saved at `public/assets/weapons.png`. Original bitmap atlas with five painted
weapon patterns. CSS sprite regions select each illustration. Related carbine
and howitzer entries currently share representative rifle and cannon art.
Mode: built-in imagegen, new image generation, no reference images.

Prompt:

> Use case: historical-scene. Asset type: one weapon illustration atlas for an 1805 Napoleonic strategy game's armory. Landscape sheet 1536x1024, EXACTLY FIVE equal horizontal bands stacked vertically, no gaps, no borders, no text or labels. Solid uniform desaturated dark charcoal background #242b2b across entire sheet. Every weapon centered fully inside its band with ample horizontal margin. From top band to bottom: 1 French Charleville flintlock infantry musket, long walnut stock and steel barrel with bayonet; 2 refined French AN IX flintlock musket, warm walnut and polished steel, without bayonet; 3 short Versailles flintlock rifle with brass furniture, darker wooden stock; 4 French light cavalry curved saber with brass three-bar hilt and steel blade, side profile; 5 French Gribeauval six-pounder field cannon, barrel and two wooden spoked wheels, olive-green wooden carriage, clean three-quarter side view, fully contained in bottom band. Fine realistic hand-painted museum-catalog illustrations, crisp silhouettes, visible wood grain and metal highlights, no modern firearm parts, no people, no decorative objects, no watermark. Items 1-4 horizontally aligned, barrels or blade point right. Consistent soft lighting, readable at small interface sizes.

## Sound

Musket, cannon, order, and marching sounds are synthesized by Web Audio in
`src/game/audio.js`; no recorded audio files or third-party audio samples are used.

## Visual Depth Demo Unit Atlas

Generated with the built-in imagegen tool, with no API/CLI fallback and no
extracted game artwork. The demo reuses the existing ground, canopy, and village
bitmaps listed above. Three.js supplies terrain relief, lighting, camera
projection, and instanced sprite rendering; shadows and water detail are
code-generated rendering effects.

Selected project assets:

- `public/assets/depth-units.png`: original painted 4-by-2 atlas, used for the
  small unit inspector illustrations.
- `public/assets/depth-units-keyed.png`: matching atlas with a magenta matte,
  used by the battlefield and campaign sprite renderer. A chroma-key fragment
  shader removes the matte at runtime. This is not an alpha-channel PNG.

The eight cells represent French/Austrian infantry, French/Austrian cavalry,
French/Austrian artillery, a mounted French general, and a supply wagon. The
art is representative, not a verified reconstruction of every 1796 uniform.
The original side-facing sprites use horizontal mirroring. The directional
pass below adds front and rear views; eight-way action artwork is not yet
implemented. The animation pass replaces whole-sprite movement bobbing.

Initial generation prompt:

> Use case: historical-scene. Asset type: transparent bitmap sprite atlas for an original painterly Napoleonic tactical strategy game, NOT a scene or UI mockup. Create exactly eight separate miniature unit sprites in an exact 4-column by 2-row grid, all cells equal size, transparent background throughout, no drawn grid, no labels. Row 1 left to right: French line infantryman 1796 in dark navy coat white crossbelts black bicorne carrying long musket with bayonet; Austrian line infantryman in off-white coat dark hat carrying musket; French hussar mounted on chestnut horse; Austrian cavalryman mounted on dark horse. Row 2 left to right: French bronze field cannon with olive carriage and two crew; Austrian cannon with two crew; mounted French general wearing black bicorne; wooden covered supply wagon with two horses. Every sprite faces toward upper-right, viewed from an elevated tactical game camera 50 degrees above horizon, visible head, shoulders, front/side, body and feet or wheels. Fine detailed hand-painted realistic miniature illustrations, restrained saturated navy, ivory, forest green, muted red, brass. Dimensional soft upper-left lighting, crisp readable silhouettes, natural proportions, not low-poly geometry, no cartoon or outlines. Full sprite contained inside its cell with generous transparent margins, maximum height about 80 percent of cell; no sprite touches another cell. No ground patch or opaque shadow puddle; genuinely transparent background, no text no watermark. Landscape 1536x1024 if possible. Original artwork only, do not copy extracted game assets.

The transparency retry produced an opaque checkerboard and was rejected by a
pixel-alpha check. It is not referenced by the game. The final selected edit
used a chroma-key matte instead.

Final selected edit prompt:

> Edit only the background of this exact 1536x1024 eight-sprite atlas. Keep all eight figures and their positions and sizes unchanged. Replace ALL the studio background with ONE exact SOLID PURE MAGENTA RGB 255,0,255 (#ff00ff) chroma-key background. Also fill gaps between legs, around wheels, around weapons and between all figures with that exact magenta. Do NOT output transparency or checkerboard. Do not add any texture, glow, shading, shadow, vignette or noise to the magenta background; every background pixel must be uniformly #ff00ff. No ground planes. Preserve the original detailed painted figures and all non-background colors. We will remove the uniform magenta with a chroma-key shader when rendering the game.

## Unit Animation Pass

The original `depth-units-keyed.png` and inspector art remain unchanged. The
renderer now articulates their legs, bodies, crew, and weapons with weighted
instanced meshes. Infantry march and make melee thrusts; cavalry and generals
have horse gaits; cavalry have melee reactions; artillery recoil and crew
activity follow cannon events; supply horses step while the wagon moves.
Campaign escorts use the same movement system. No animation changes gameplay
positions or damage. Displacement drives gait, so paused, blocked, and halted
units do not march indefinitely. Render-frame rate does not set game speed.

Selected supplemental asset: `public/assets/depth-unit-actions-keyed.png`, a
1536-by-1024 RGB PNG with an opaque magenta matte, four columns and two rows.
The top row contains French/Austrian infantry and French/Austrian mounted
cavalry firing; the second row contains their reload poses. A runtime shader
keys the matte and excludes small painted spillovers in atlas gutters.
Foot-line registration keeps the supplemental poses aligned with the original
troops. Textures are shared across instances with no per-soldier texture loads.
Both atlases together occupy about 12 MiB as uncompressed RGBA textures without
mipmaps. Animated sprites use 35, 77, or 187 vertices according to their
projected size; low-detail infantry use 49 vertices to preserve separate boot
shapes through the stride. Articulation remains at every detail level. The renderer
retains its existing population cap and instancing, not a separate skeletal
rig per soldier. Only populated instance buffers are uploaded, and offscreen
regiments do not submit troop geometry. See [performance notes](PERFORMANCE.md).

New art was produced with the **built-in imagegen tool**, using the original
atlas as the identity/style reference. No API/CLI fallback or extracted game
assets were used. The selected generated original remains at
`/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-339f1ba5-6b6a-459d-93b2-abdbb463c347.png`.

Initial supplemental pose prompt:

> Use case: precise-object-edit. Asset type: supplemental action pose atlas for existing Napoleonic tactical game sprites. Input image 1 is the identity/style reference: preserve exactly these first FOUR characters, uniforms, faces, horses, painterly shading, proportions, three-quarter right-facing view. Do not redesign them. Create a NEW atlas of eight sprites on a perfectly flat solid RGB(255,0,255) magenta chroma-key background, no ground shadows, no scenery, no labels, no grid lines, no smoke or flashes (engine adds them). Canvas 1536x1024, exactly FOUR equal columns and TWO equal rows, each 384x512. Every subject stays entirely within its cell with 20px padding, bottom of feet at cell y=470. TOP ROW from left: original French infantry aiming and firing a shouldered horizontal musket to the right; original Austrian infantry aiming and firing shouldered horizontal musket right; original French hussar mounted on same brown horse firing a short carbine right from saddle; original Austrian cuirassier mounted on same black horse firing a short carbine right from saddle. BOTTOM ROW: same four characters in same positions, body scales, identical heads/horses/feet alignment, now reloading their respective weapons (infantry musket stock near hip, hands attending lock/barrel; mounted cavalry tending carbine across saddle). Keep horses matching their upper row exactly, don't change their posture between firing/reload. Match original troop height and mass: infantry actual figure from y=85 to470, cavalry from y=20 to470, not oversized infantry. Full-length feet/hooves visible, bayonets fully inside cells. Preserve the original detailed hand-painted realistic aesthetic and colors. No extra units. No cannon, general, or wagon on this supplemental sheet.

Final layout correction prompt:

> Use case: precise-object-edit. Correct ONLY the layout of this supplemental 4-column 2-row Napoleonic firing/reload atlas. Preserve the exact painted characters, uniforms, horses, all eight distinct action poses, magenta background, and painterly quality. Every complete figure and weapon must fit in its OWN exact 384x512 cell. CRITICAL: the first two TOP ROW bayonets currently protrude across the cell boundary; shorten or foreshorten those muskets and bayonets so each ends at local x=365 or earlier. Remove the stray weapon fragments currently extending into the next cells. Align the infantry bodies in both rows to the SAME SCALE: infantry hat top local y=100, boots bottom local y=465, hips local y=285. This means modestly reducing bottom-row infantry heights to match top row; keep them horizontally aligned. Mounted figures keep their current positions and sizes. No new objects or shadows or markings, preserve flat uniform #ff00ff background. Final canvas stays 1536x1024, four equal columns, two equal rows, no text.

The result needed small runtime alignment offsets and gutter exclusions rather
than another repaint. An experimental wheel UV rotation distorted overlapping
crew details and was removed. Independent wheel rotation, eight-way action
art, anatomically complete skeletal animation, and final uniform/weapon
accuracy remain outside this pass. Generals and wagons have no shooting state
because the combat model does not grant them attacks.

Verification: `npm run test:animation` checks displacement-driven movement,
paused poses/pixels, actual model-generated firing, all eight sprite types'
rendered foot movement, armed types' firing/reload reactions, and chroma-key
leaks. It saves close-up sprite rows (rest, opposite gait phases, firing,
reloading) and desktop/mobile combat screenshots in
`test-results/depth-animation/`. `npm run test:demo` retains full-map, touch,
camera-boundary, save-isolation, and overlay checks.

## Directional Views And Slower Strides

Selected new asset: `public/assets/depth-unit-directions-v2.png`, 1086x1448 RGB
with a magenta matte, four columns and four rows. The top two rows contain the
eight rear views; the bottom two rows contain the front views. It is original
art generated with the **built-in imagegen tool**, using the original unit
atlas for identity/style. No API/CLI fallback or extracted game art was used.
Two draft atlases were rejected for wagon orientation and cell-edge spillovers;
they remain only in the generator's output directory, not shipped assets.

The selected generated original is
`/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-244e9781-83bc-4db6-a32e-fde55503b1f6.png`.
Its final edit references were the same directory's
`exec-78fb9d74-f669-4a61-8447-f8ea3959b9b6.png` and
`exec-170b9d82-e1ae-4985-862f-220f1cf408b7.png`.

Final generation/edit prompt:

> Use case: compositing. Production game sprite atlas cleanup. Image 1 is the EDIT TARGET and supplies all sixteen sprites EXCEPT row2 column4; Image 2 supplies ONLY its corrected rear-view wagon from row2 column4. Output ONE final four-column four-row atlas on flat pure #ff00ff matte, exact same 3:4 portrait aspect. Preserve every character identity, uniform, horse, cannon, face, pose and painterly style from image1; replace ONLY the north/rear wagon row2 column4 with the correct rear tailgate-facing-us wagon from image2. CRITICAL preserve the FRONT-view wagon in bottom right from image1: horse faces toward us, horses IN FRONT of wagon; do not use the incorrect front wagon from image2. Layout cleanup on ALL cells: SHRINK EACH individual complete subject uniformly by 12 percent WITHIN ITS OWN CELL, centered horizontally, reposition so its full silhouette (including bayonets, head plumes, hooves, wheels and crew) stays inside local cell x=8%-92%, y=8%-92%, with feet/wheels baseline y=92%. Every pixel outside that local rectangle must be perfectly pure magenta. No cross-cell spillover, no cut-off boots or head plumes, no parts from neighboring sprites. Top half remains rear-facing, bottom half front-facing. Do not redesign or merge figures. No ground shadows, text, labels, scenery, grid lines or extra parts. The goal is exact clean sprite registration with generous magenta gutters, and correct rear and front wagon views in their respective cells.

The runtime accounts for the remaining small rear-cavalry cell overhangs in
its UV bounds. The extra atlas uses about 6 MiB uncompressed GPU texture memory,
without extra troop batches or per-soldier texture uploads. Four coarse facing
directions are supported, with the side views mirrored for left/right.
Front/rear combat currently uses mesh recoil and crew work; separate painted
aim/reload frames remain side-facing only.

Leg poses blend between opposite strides on the existing instanced meshes,
not opacity-crossfaded duplicate soldiers. Normal marching alternates poses
about every 1-2 real seconds at the default 0.5x speed; pause, fatigue-related
movement, and other time scales remain respected. This is weighted sprite
articulation, not an anatomically complete skeleton.

`npm run test:polish` records the directional gallery, compact roster on three
viewport widths, keyboard controls, and model-generated artillery impact
markers under `test-results/depth-polish/`.

Troop quads now stand vertically, with height compensation to preserve their
painted on-screen proportions at the elevated camera angle. Their base samples
the full animated support width on the rendered terrain/bridge surface. This
prevents the old camera-aligned planes from leaning into uphill terrain without
disabling depth testing. Muzzle effects use the same instance transform.
`npm run test:grounding` checks infantry and wagons on four steep slope directions
in side/front/rear views, verifies foreground-ridge occlusion, and captures both
maps on desktop and mobile. No new artwork was needed for this correction.

The formation-following pass reuses the same art and instanced rigs. Soldiers
have individual cosmetic positions, velocities and headings, with bounded
acceleration and local spacing. Positions advance with battle time, independently
of camera visibility and render frequency. During movement the art follows each
soldier's heading; combat poses use the regiment's firing direction. Stationary
soldiers settle back to their ordered ranks. This is not individual tactical AI,
terrain routing, or per-soldier hit detection. `npm run test:engagement` captures
the closer 6x views on both maps and checks targeting, fatigue, and turning.

## Native Godot Environment Refresh

The native project uses four new original assets under `godot/assets/`:
`terrain-v2.png`, `woodland-v2.png`, `architecture-v2.png`, and `smoke-v2.png`.
These add quieter rural ground, six individual trees, six separate buildings,
and translucent gunpowder smoke. All were generated with the built-in imagegen
tool; no CLI/API fallback or extracted game artwork was used. The legacy browser
assets and original troop atlases remain unchanged.

[Native art direction](../godot/ART_DIRECTION.md) records the selected source
paths, final prompt set, reference links, runtime integration, and limitations.

## Native Infantry Walking Frames

`godot/assets/infantry-walk-french-v1.png` and
`godot/assets/infantry-walk-austrian-v1.png` provide original idle and two-step
infantry artwork, derived from the existing soldiers using built-in imagegen.
Both are 1254x1254 magenta-keyed source atlases. The original combat sprites
remain unchanged; native runtime registration aligns the animation frames.
[Infantry animation notes](../godot/INFANTRY_ANIMATION.md) include exact saved
paths, the complete final prompt set, processing, scope, and verification.

## Native Movement And Map Polish

Seven further original assets are integrated under `godot/assets/`:
`cavalry-walk-french-v1.png`, `cavalry-walk-austrian-v1.png`,
`artillery-motion-french-v1.png`, `artillery-motion-austrian-v1.png`,
`wagon-motion-v1.png`, `casualties-v1.png`, and `woodland-v3.png`.
They were generated using built-in imagegen and preserve Napoleonic identities.
[Polish pass notes](../godot/POLISH_PASS.md) record all selected source paths,
the complete prompt set, local video observations, processing and limitations.

## Native Melee Frames

Four built-in-imagegen atlases add painted guard, strike and recovery poses:
`godot/assets/infantry-melee-french-v2.png`,
`godot/assets/infantry-melee-austrian-v2.png`,
`godot/assets/cavalry-melee-french-v1.png`, and
`godot/assets/cavalry-melee-austrian-v1.png`.
Existing walking and firing art is preserved. Infantry v1 drafts are not used
by the renderer. [Combat motion notes](../godot/COMBAT_MOTION.md) contain the
selected originals, exact prompt set, runtime registration and scope.
