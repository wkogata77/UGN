# Reload Sprite Frames

Added September 24 with the built-in `image_gen` tool, not the CLI/API fallback.

## Delivered Asset

`godot/assets/unit-reload-v1.png`, 1536x1024, six columns and four rows.
Rows are French infantry, Austrian infantry, French cavalry and Austrian cavalry.
Columns are side loading A/B, rear loading A/B and front loading A/B. The side
pair is mirrored for left-facing units. Original walking, firing and melee
assets remain unchanged.

Final source: `/home/wes/.codex/generated_images/01a07d06-c28f-7f72-bdde-6b9ec06387ca/exec-f95c7b06-9123-424c-9140-6e334af04d40.png`.
The initial sheets had an unusable painted backdrop. Only the final flat-magenta
version is shipped. Godot's existing key-removal, premultiplied-alpha and mipmap
pipeline processes it; both frames in each direction share a scale and foot anchor.

References were the project's `depth-unit-actions-keyed.png`,
`depth-unit-directions-v2.png` and `infantry-walk-french-v1.png`. The corrected
intermediate was `exec-ca33c32f-d223-479e-af49-462144469fa3.png` in the same generation
folder. No artwork from another game was used.

## Playback

Hands lift the ramrod and return to the lower loading pose while feet and horses
stay planted. Artillery uses its existing ready/loading crew paintings. Progress
is normalized to the actual cooldown recorded at each shot, rather than ending
all unit types at 2.8 seconds. Walking still overrides reloading, melee keeps its
own animation, and pausing freezes the loading frame. Walking cadence is now
one-third slower independently of movement speed and combat timing.

## Prompt Set

Verification: 208 focused native animation checks and 152 simulation checks
passed. The native suite compares loading pixels in all four facings for each
troop type, checks the recorded cooldown and artillery's longer loading window,
and confirms pause and movement override behavior. Captures are
`godot/test-results/reload-*-lowered.png` and `reload-*-raised.png`.

### Atlas

Use case: identity-preserve. Production sprite animation atlas for this native Napoleonic tactics game, matching the supplied original painted unit sprites exactly in identity, uniforms, proportions and painterly rendering. References: image1 existing French/Austrian infantry and mounted French/Austrian cavalry actions, image2 their rear/front identities, image3 French infantry registration and planted idle boots. Create ONE new loading-action atlas, exactly SIX equal columns and FOUR equal rows, 24 sprites, landscape 1536x1024 or larger same 3:2 ratio. ROW1 French infantry dark blue coat red cuffs white trousers black bicorne; ROW2 Austrian infantry white coat green facings black shako; ROW3 French blue/gold hussar on brown horse; ROW4 Austrian white/red mounted cavalry on brown horse. In EACH row the six columns are: (1) side facing RIGHT, loading frame A; (2) identical side RIGHT, loading frame B; (3) rear facing away, loading A; (4) identical rear, loading B; (5) front facing viewer, loading A; (6) identical front, loading B. Infantry frame A: planted legs, musket held nearly vertical beside body, left hand supports stock and right hand at muzzle preparing cartridge/ramrod. Infantry frame B: EXACT SAME body head feet musket and position but right elbow lifted and right hand visibly higher on thin ramrod above muzzle, about to press ramrod down. Mounted cavalry A: horse fully stationary ALL FOUR FEET planted, rider holds short carbine nearly vertical across saddle with right hand low at lock; B same horse and rider posture but right forearm raises a thin ramrod to carbine muzzle, very clearly different hand/arm position. All sprites in each pair must have IDENTICAL pixel locations and scale of hat/head, torso, hips, feet/hooves, horse, weapon barrel; animate ONLY arms, hands and ramrod. Realistic loading, NO firing, NO thrusting or melee, NO walking, NO rearing horses. The two loading poses must be visibly distinct at small game scale. Full bodies and full horses entirely inside cells, feet at cell y=92%, hats/ears about y=18%, tallest ramrod no higher than y=5%; torso/horse centered x=50%, generous gutters and no limbs crossing cell boundaries. Same oblique game-camera angle and restrained painted realism as the references, not a new art style. Preserve original faces, weapons and equipment, do not simplify or change uniforms. Absolutely flat pure #ff00ff magenta backdrop throughout including limb gaps, NO floor, shadow, checkerboard, transparent simulation, labels, text, grids or borders.

### Uniform/Key Correction

Use case: precise-object-edit. Image 1 is the EDIT TARGET sprite atlas. Preserve exactly the 6 columns x 4 rows, all 24 figures, both loading poses, weapons, horses, position, scale, anatomy and painted sprite detail. Make ONLY these corrections: (1) REMOVE the entire brown/grey scene background, all light halos and all ground/contact shadows. Replace every background pixel and every gap around limbs, weapons and between horses' legs with one perfectly flat pure #FF00FF MAGENTA chroma-key backdrop. No gradients, no lighting, no shadow, no brown or grey anywhere outside the figures. The flat magenta must touch the exact silhouettes, not a rectangular patch or halo. (2) In ROW ONE COLUMNS THREE AND FOUR ONLY, replace the incorrect rear-view cylindrical shako hats with the same French black two-point BICORNE worn by the other four French infantry in row one. Preserve head and neck location, pack and blue/red uniform. The Austrian infantry in row two keep their shako hats unchanged. Everything else must remain identical. Production keyed sprite atlas, absolutely flat solid #FF00FF background, NO text, no labels, no frames. Do not redesign any sprites.

### Discarded Extraction Attempt

Use case: background-extraction. Remove the background from this sprite sheet. Return the exact same 24 figures with real transparent alpha everywhere outside their silhouettes, including holes between limbs and around weapons. Delete the entire brown backdrop and the glows. No replacement background. Genuine transparency, not a drawn checkerboard. Preserve every sprite's artwork, alignment, dimensions, all six columns and four rows, and do not crop the canvas.

### Final Keyed Background

Replace the brown background with solid bright neon MAGENTA (#ff00ff). The entire background must be MAGENTA, like a chroma-key greenscreen but pink. Keep all 24 sprites and their layout unchanged. No brown backdrop, no glow, no shadows, no gradient. Flat neon magenta everywhere outside the soldiers and horses.
