# Native Polish Pass

Follow-up: [COMBAT_MOTION.md](COMBAT_MOTION.md) fixes marching handedness, adds
edge-based melee and painted bayonet/saber frames, and replaces the original
fixed-gap behavior with gradual rank replacements at the user's request.
The checklist and measurements below describe this earlier pass.

## Reference Review

Reviewed the seven local reference photos and sampled the 168.5-second `inspo_photos/Recording 2026-09-10 021115.mp4`, including a denser two-second sequence at 1:49-1:59 to compare cavalry spacing and travel. These Civil War references guide presentation and behavior only: the existing Napoleonic uniforms, weapons, factions, and identities remain.

- 0:00-0:45: readable field parcels, woodland edges and roads establish the map; small anchored labels and the bottom roster leave most of it visible.
- 1:00-1:30: formations have uneven moving edges, smoke remains at firing positions, and settled lines are more orderly than traveling units.
- 1:49-1:59: the lower-right cavalry group spreads into an irregular moving body, with differing rider headings and spacing. This calls for independent movement trajectories, not merely alternating sprite frames.
- 2:00-2:19: destination arrows remain clear across the open fields. The later footage switches to promotional material and is not used as a gameplay specification.
- The headquarters photo `ss_099b5de21f169d4c83fb42cf21f7ef5c295b8d63.1920x1080.jpg` uses a corps selector, horizontal regiment roster, narrow selected-unit editor, and bottom navigation. The native redesign follows that hierarchy without importing its artwork or Civil War insignia.

## Request Checklist

Implemented in the native project; final verification is recorded below.

- Expanded Italy from 1440x960 to 4320x2880, nine times the playable area, with 18 settlements, five crossings, connected routes, overview, dynamic picking and minimap.
- Added one-time strategic save-coordinate migration and a `.pre-expanded-map.bak` backup for legacy native saves. Tactical coordinates are not scaled.
- Added persistent representative battlefield bodies. Formation slots remain fixed; casualties remove front-rank slots first and leave gaps instead of rebuilding all ranks. Bodies and dead-slot identities survive saving.
- Mounted cavalry now follows a short traveled-path history with staggered response, spacing, heading and stride. It loosens on the march and settles back into formation at rest. Infantry has a smaller version of the same behavior.
- Added painted idle/two-step movement frames for cavalry and supply wagons, plus idle/movement/fire/reload frames for artillery, retaining the existing infantry animation and Napoleonic identities.
- Selection checks the actual projected formation sprites. Clicking or box-selecting an outer figure works without enclosing the unit center. Right-clicking an enemy formation issues an attack.
- Campaign left-drag selects without panning. WASD, middle-drag, Alt-drag, and touch pan remain available.
- Added Route, Normal and Slow marching, separate from simulation time speed. Faster modes generate more fatigue. Enemy armies now tire while moving, slow/rest when exhausted, and bring their condition into battle.
- Campaign attack orders pursue visible armies, stop updating on lost contact, and cancel on Halt or a new move order.
- Replaced sparse front-facing woodland art with fuller high-oblique canopies, denser mixed planting and scattered edge vegetation. Added varied cultivated plots, warmer roads, shoreline transitions, denser towns and village lanes on both campaign and tactical maps.
- Corrected bridge deck support and road clearance on hills. Troops retain terrain-supported vertical sprite quads.
- Headquarters now has a corps navigation area, compact regiment roster and independently scrolling unit editor, with bottom tabs. Smaller layouts retain a full-width selectable regiment inspector.
- Commander portraits open an available-officer chooser. Only hired, ready, sufficiently ranked and unassigned officers are offered; replacing a commander releases the previous officer into reserve.
- Map unit labels use more compact translucent faction markers and leader lines above formations. Selected routes have destination arrowheads; morale and fatigue indicators remain.

## Boundaries

This is still an illustrative Northern Italy sector, not a researched reconstruction of the whole 1796 campaign. Towns and fields are scenery, not new garrison, loyalty, fortification or cover systems. Cosmetic soldiers have independent motion but damage, path orders and combat remain regiment-level; this is not per-soldier tactical AI. Bodies represent rendered figures (roughly nine men, or an artillery group), not an exact one-to-one casualty count. The separate main general retains the existing articulated animation. Dedicated melee frame sheets, continuously blended eight-direction animation, formation-aware building avoidance and a fully authored historical landscape remain further work.

The broader progression/replenishment, scouts, loyalty, forts and strategic-objective roadmap is tracked separately in `feature plans/visual-depth-demo-and-northern-italy-roadmap.md`; this pass does not mark that entire roadmap complete.

## Asset Delivery

All seven new selected assets were produced using the **built-in imagegen tool**, not CLI/API fallback. Original unit and environment assets were preserved. No reference-game pixels were copied into shipped assets. Native code performs chroma removal, atlas registration and mip generation. Wagon and woodland row bounds account for the generated spacing rather than clipping sprites into forced equal cells.

- `godot/assets/cavalry-walk-french-v1.png`, selected original `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-7e02293c-5bcb-48ab-ae7d-5ed5f4f307b5.png`.
- `godot/assets/cavalry-walk-austrian-v1.png`, selected original `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-86826a21-24b7-4331-8428-538952fb8b3a.png`.
- `godot/assets/artillery-motion-french-v1.png`, selected original `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-7691a584-9183-43e0-a039-0b957388bec0.png`.
- `godot/assets/artillery-motion-austrian-v1.png`, selected original `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-8b9d04aa-2318-4160-b17a-c4d3a8b060ba.png`.
- `godot/assets/wagon-motion-v1.png`, selected original `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-ce10094c-a846-49a2-9090-92699f9d95b4.png`.
- `godot/assets/casualties-v1.png`, selected original `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-ea0f3933-ba0d-43b3-918f-b192d2645acc.png`.
- `godot/assets/woodland-v3.png`, selected original `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-7797f574-a138-46f3-9ac3-34078651b526.png`.

## Final Prompt Set

### French Cavalry

Use case: identity-preserve. Original production animation atlas. Reference1 is existing unit art; use ONLY its top-row third subject: French hussar in dark blue gold-braided jacket, red breeches and red-plumed shako on chestnut horse. Reference2 supplies that same hussar's front/rear views in column3. Create square THREE columns THREE rows on perfectly flat #ff00ff magenta chroma-key backdrop. Rows: three-quarter SIDE facing RIGHT, REAR walking away, FRONT walking toward viewer. Columns: IDLE horse with all four hooves planted; WALK A left foreleg and right hindleg advance while opposite pair push back; WALK B OPPOSITE diagonal pair advance, visibly reversed knee/hock flex and lifted hooves. Moderate marching horse, not rearing, jumping or galloping. Anatomically four horse legs only, a rider seated in saddle throughout. Keep head, chest, rider, saddle, tail root and reins REGISTERED in identical positions and scale within each row; change primarily legs below horse belly, with a tiny natural tail difference. Step B must NOT duplicate A and must NOT mirror the whole horse/rider. Match the reference's detailed realistic painterly game-sprite finish and exact uniform/equipment, no cartoon outline or plastic toy. Every complete subject in its equal cell with generous 8 percent margins, top plume at cell y=8%, lowest hoof y=92%, identical baseline and scale. Keep all weapons, tails, ears and hooves inside their own cells. No ground, shadows, labels, grid, scenery or extra subjects. Flat MAGENTA including gaps, no checkerboard or transparency. Preserve original-art identity.

### Austrian Cavalry

Use case: identity-preserve. Image1 is the EDIT TARGET nine-frame cavalry atlas. Image2 provides the uniform/horse reference: ONLY its TOP RIGHT Austrian cavalryman, white coat, red facings, brass helmet with black crest, dark horse. Convert every French hussar and chestnut horse in Image1 into that Austrian cavalryman and dark horse. Preserve all nine poses, exact framing, registration, limb positions, directions, lighting, realistic painterly detail. Rows remain side RIGHT / REAR / FRONT; columns remain planted-hoof IDLE / WALK A / opposite WALK B. Keep visibly DIFFERENT raised hooves in the last two columns and opposite stepping legs. Keep rider seated, upper body and horse torso consistent across columns. Do not duplicate the same step or mirror the entire horse. Same square3x3 equal-cell layout, full tails, weapons, plume, hooves inside each cell. Perfect flat pure #ff00ff magenta background including every gap. No shadows, floor, scenery, labels, grid, checkerboard or extra subjects.

### French Artillery Base

Use case: identity-preserve. Original production artillery animation atlas derived from reference image1's BOTTOM LEFT French cannon with two blue-coated bicorne artillerymen; reference2's first-column lower-row front/rear cannon views supply direction. Create landscape FIVE equal columns by THREE equal rows, fifteen complete sprites of this SAME brass field cannon, timber carriage and two French crew. Rows: high-oblique side facing RIGHT; rear with barrel pointing AWAY; front with muzzle pointing TOWARD viewer. Columns: 1 IDLE two crew upright, gun at rest; 2 MOVE A crew taking a left-foot step while rolling gun, wheels with spoke angle A; 3 MOVE B opposite right-foot step and visibly rotated wheel spokes, distinct lifted boots; 4 FIRE crew braced/leaning away, barrel recoiled a little, no smoke because engine adds smoke; 5 RELOAD one crew member leaning and working a rammer at muzzle, the other handling ammunition. Keep cannon carriage, wheel centers, scale and baseline registered across every frame in each row. Keep the same two crew, uniforms, equipment and weapon identity, all different action poses must be visibly distinct without changing cannon proportions. No duplicated unchanged move poses. Realistic fine painterly style matching reference, no cartoon outlines. Each entire cannon, men, ramrods and wheels must stay inside its own equal cell, generous 8% magenta margins on every side, planted boots/wheels baseline at cell y=92%. Perfectly flat pure #ff00ff magenta chroma-key background in every gap. No floor, shadows, smoke, flames, flashes, labels, cell borders, scenery, watermark or extra subjects.

### French Artillery Correction

Use case: precise-object-edit. Edit this original artillery animation atlas. Correct ONLY the faction uniforms: ALL THIRTY artillerymen in all fifteen cells must wear the same French blue coat, white crossed belts, white trousers, black boots and black bicorne with tricolor cockade as the LEFT crew member. Remove EVERY white-coated Austrian and shako by changing his uniform to the French uniform. Both crew in every cell are French. Keep this exact five-column three-row atlas, all fifteen poses, identical cannon geometry, wheel centers, cell positions, framing and flat #ff00ff magenta background. Also make the third-column SIDE-view walking crew step with the OPPOSITE leg to column two, while retaining wheel/gun center. No text, smoke or background scenery. No other changes.

### Austrian Artillery

Use case: identity-preserve. Create the Austrian army variant of this original five-column by three-row artillery animation atlas. Change ALL crew uniforms in all fifteen sprites to Austrian white coats and white trousers, red cuffs/facings, dark boots and black Austrian military headwear. All crew are Austrian; no blue-coated men. Preserve exactly the brass gun, carriage, all fifteen idle/walking A/walking B/fire/reload poses, wheel centers, framing, cell arrangement and flat pure #ff00ff magenta background. Do not change sprite positions or proportions. No scenery, shadows, smoke, text or borders.

### Supply Wagon

Use case: identity-preserve. Original production movement sprite atlas for the SAME canvas-covered supply wagon in the BOTTOM RIGHT of the reference. Keep its timber carriage, covered canvas, seated brown-coated driver, two harnessed brown draft horses and painterly realistic style. THREE equal columns by THREE equal rows, nine complete wagon-team sprites. Rows: high-oblique SIDE facing RIGHT; REAR with horses moving AWAY from viewer; FRONT with horses coming TOWARD viewer. Columns: IDLE horses planted; walking A with left fore/right hind lifted; walking B with opposite legs stepping. Horse legs visibly swap position between A and B, wheel spokes rotate; canopy, carriage and driver stay registered at exactly the same scale and position within each row. Full wagon, BOTH horses, driver, all wheels and harnesses contained inside each cell with at least 8% empty margin; no clipping at any cell edge. Flat pure #ff00ff magenta chroma background, no shadows, floor, scenery, text, borders or extra units. No Civil War uniforms.

### Casualties

Use case: historical-scene. Production sprite atlas of non-graphic fallen Napoleonic soldiers for a strategy game's persistent battlefield casualties, stylistically matching the painted French and Austrian soldiers and cavalry in the reference. SIX isolated sprites in THREE equal columns by TWO equal rows, each safely inside its cell with 12% margins. TRUE OVERHEAD camera looking straight down at figures lying flat on the ground, heads toward the TOP of each cell. Top row: French blue-coated bicorne infantryman lying on side with fallen musket; Austrian white-coated infantryman lying on back with musket; French blue-coated bicorne artilleryman lying on side. Bottom row: Austrian white-coated artilleryman lying on side; fallen chestnut horse and French blue-and-gold hussar beside it; fallen dark horse and white-coated Austrian cavalryman beside it. Relaxed uneven limbs, recognizable uniform identities, fine hand-painted realistic detail readable at small size, not standing upright, no gore, no blood or exposed injuries. Flat pure #ff00ff magenta chroma background everywhere outside the six subjects, no ground, grass, cast shadows, text, grid, cell borders or UI. Preserve Napoleonic, not Civil War, uniforms.

### Woodland

Use case: stylized-concept. Original environment sprite atlas for a polished Napoleonic tactical game in rural northern Italy. SIX separate trees in THREE equal columns by TWO equal rows, orthographic high-oblique view from 52 degrees ABOVE the ground, so we see predominantly full rounded CANOPIES, not tall front-view exposed trunks. Species: broad mature oak, compact poplar, dense elm, riverside willow, small rounded orchard tree, low dense shrub cluster. Realistic hand-painted game art, compact irregular interlocking leaf masses, deep natural forest greens with olive and yellow-green highlights, soft directional sunlight from upper left, dark shaded lower-right canopy; no chalky gray edges or bright white outlines. Tree crowns broad and full; trunks short and mostly concealed by the overhead crown. Each complete silhouette safely within its equal cell with 8% margins. TRANSPARENT background with clean alpha edges; no ground plane, grass bases, cast shadows, labels, borders, text or scenery. Designed to blend into a green terrain mesh, not ornamental standalone botanical illustrations.

## Verification

`tests/regression.gd` covers campaign extent and navigation, old/new save migration, marching and enemy fatigue, interception, persistent casualty identities, bounded cavalry motion, independent stride and stationary settling. The native visual suite checks rendered motion atlases, formation-edge selection, campaign drag behavior, headquarters commander swapping, body geometry, wagon movement, bridge clearance, map framing and performance in addition to existing coverage.

Final verification: **149 baseline simulation checks, 41 expansion regression checks, and 296 graphical/input checks passed**, with 46 native screenshots. The final five-second active-battle sample at 1440x900, 445 visible figures, on the RTX 3070 Ti measured **10.0 ms median, 19.5 ms p95, 26.3 ms worst**. An earlier run had a 905 ms outlier; timings are machine/load dependent, not a universal smoothness guarantee. The earlier pause-pixel discrepancy did not recur in subsequent full runs. Test screenshots and machine-readable results are under `godot/test-results/`.
