# Field Command UI Theme

## Presentation

- Neutral charcoal control surfaces, ivory text, muted blue/red faction colors,
  and brass reserved for selected controls, headings and important information.
- Shared `FieldTool`, `FieldTab` and `FieldRecord` theme variations distinguish
  toolbar actions, navigation and selectable roster entries. Existing tooltips,
  keyboard focus, disabled states and order behavior are retained.
- Headquarters uses an original engraved-atlas backdrop with a subdued French
  standard. Army command, corps command, painted regiment records and the
  selected regiment's service record share one consistent layout.
- The regiment record retains naming, commander assignment, corps transfers,
  training, equipment, strength, replacements and service history. Training
  purchases have separate price labels and compact action buttons.
- Battlefield and campaign roster cards have painted troops or commander
  portraits, tricolor edging and distinct morale/condition bars. The battle HUD
  has not grown.
- Map labels use the same pennants and larger name text. Existing label collision
  avoidance, outer-figure picking, drag selection and enemy orders remain active.
- Objectives read as field dispatches. Reports contain commander portraits,
  aligned casualty returns, confidence changes and actual captured weapon art.
  Open dispatches/reports reflow when the window is resized.

## Command Rail

The bottom HUD and top navigation now share the original engraved atlas
material, charcoal frames and restrained brass edges. `CommandTool` controls
have raised/inset states; `RegimentCard` entries use muted crimson selection
inlays, ivory serif names and prominent strength readouts. Infantry, cavalry,
artillery and supply entries reuse the game's painted troop artwork. Generals
and operational armies use their assigned officers' portraits.

Morale and condition remain separate live bars, while compact status labels
keep current orders readable. Full names, experience, ammunition and exact
status remain in tooltips. The supply readout counts friendly stores only.
Selection, additive selection, double-click centering, commander orders,
formation transitions and time controls retain their existing behavior.

Order groups, corps selectors and the unit roster scroll independently when
needed. Corps selection stays highlighted, including mixed selections. The
desktop command heading identifies the current regiment or selection. Controls
stay within a 118-pixel desktop / 156-pixel narrow-screen rail in both battle
and operational campaign views. Campaign mode's previous rail was slightly
taller. The header collapses to icon navigation at intermediate widths; wrapped
battle titles no longer collide with their objective dispatch on narrow screens.

No new image generation or copied reference-game assets were needed for this
pass. All bitmap artwork comes from the project's existing asset library.

## Hillside Figures

Figure support now uses the boot/wheel footprint instead of the full empty
sprite rectangle. The registered painted-foot position is anchored to that
support height. Infantry stays upright; mounted figures, artillery and wagons
receive at most 0.14 radians of lateral slope tilt. Contact shadows follow the
local ground plane and clear terrain at their corners.

This footing correction is not a new formation solver or an IK animation
system. A wide formation still follows the hill's actual contours. Selection
rectangles account for the adjusted sprite transforms.

The follow-up terrain pass softens the physical hills as well: broad, rounded
shoulders, lower small knolls, smoothly joined overlapping hills and eased
riverbanks replace the steep caps. Campaign relief respects the map's scale.
Ground normals follow the sampled mesh, and cultivated fields reuse its exact
triangles so their textures no longer cut through slopes. Terrain heights still
drive troop support, sight lines and marching penalties together; the gentler
grades therefore also reduce the corresponding movement penalties. Formation
slots, casualties and bridge deck heights are unchanged.

## Asset Provenance

`assets/headquarters-atlas-v1.png` was generated with the built-in image-generation
tool for this project. It is decorative artwork, not a researched geographic map.
Original game-reference screenshots were not copied into the asset. Existing
officer portraits, painted troop frames, weapon art and Lucide icons are reused.
The atlas is also sampled very faintly for dispatch paper grain.

Generation prompt:

> Use case: historical-scene. Asset type: subdued full-screen background bitmap
> for a playable Napoleonic army headquarters UI, landscape 1536x1024. Create an
> original beautifully crafted old military atlas engraving on very dark neutral
> charcoal-gray paper, seen perfectly flat from above, covering the whole image.
> Faint silver-gray and smoky blue-gray engraved map lines suggest northern Italy
> with Alpine hachures along the top, a winding river descending through cultivated
> plains, clusters of tiny engraved towns, thin tracks, and a delicate compass rose
> in lower right. This is a decorative atlas backdrop, not a readable historical
> map. Keep all the engraving very low contrast, with broad quiet areas in the
> middle and right for UI text to be overlaid by the game. Along only the far-left
> 12 percent, show the edge of a vertically hanging French blue-white-red cloth
> standard, realistically painted soft fabric folds, subdued colors and no
> insignia, no text, no border. The left cloth fades naturally into shadow; it must
> not obscure the map center. Rich tactile fine linen paper grain, elegant
> copperplate marks, restrained museum-quality military print aesthetic, flat
> even lighting. Charcoal neutral dominates, with restrained dusty blue, pale gray,
> muted red, absolutely not sepia or brown. No words, letters, numbers, typography,
> labels, UI, controls, portraits, weapons, people, decorative circles, glowing
> effects, gradients, watermark, or frame. Deliver a single finished background image.

## Verification

Run with the installed Godot executable:

```powershell
& $godot --path $project -- --verify-theme
& $godot --path $project -- --verify-slopes
& $godot --path $project -- --verify-campaign
& $godot --path $project -- --verify-cover
```

Theme checks cover headquarters, commander reassignment, armory/officers,
dispatch links, order controls, labels and report dismissal. Command-rail tests
cover 320, 390, 739, 740, 1024, 1280 and 1440-pixel widths, eight-corps overflow,
painted-figure clicks, additive selection, support orders, friendly stores,
four-digit strengths and unchanged map insets. Slope checks cover foot anchoring, restrained tilt,
continuous support heights, sloped shadows, moving pixels, all troop types,
campaign escorts, outer-figure selection, bodies, wagons and bridges.

Captures are under `test-results/theme-*.png`, `test-results/command-rail-*.png`
and `test-results/slope-*.png`.
These focused checks do not certify full-battle frame rates or complete the
broader animation and performance roadmap.

Initial September 24 results: theme 100, slopes/selection 66, campaign UI 77 and
fortifications 23 native checks passed. Operational simulation 142, expansion
regression 42 and combat motion 66 headless checks also passed.

Command-rail follow-up (September 24): **192 theme, 79 campaign and 23
fortification native checks passed**, alongside **82 battle-order and 148 polish
headless checks** (524 total). Native screenshots were inspected at desktop,
intermediate and narrow widths. The complete graphical/performance suite was
not rerun; this UI pass does not claim to fix the earlier frame-time overruns.
