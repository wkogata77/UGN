# Native Polish Implementation

Requested September 14, 2026; implementation pass September 14-15. This tracks
the complete September 13 review alongside the original Northern Italy roadmap.
The painted 2.5D art, existing saves, and separate browser project are preserved.
Checked entries identify the delivered subset, not completion of the full review.

## Battlefield Foundation

- [x] Shared building layout, rendered scenery, navigation footprints and LOS heights.
- [x] Building-clearance routes, exact endpoints and local friendly detours without
  catch-up bursts. Newly created deployments avoid buildings.
- [x] Town-entry regression: street-scale battle routes, individual house detours,
  exact-endpoint smoothing and preserved spacing for simple group moves.
- [ ] Complete congestion resolution, rotation clearance and individual figure
  collision between units. Current local detours can still require manual traffic orders.
- [x] Same-side bridge reservations and queues, safe individual bridge columns,
  gradual street compression and reformation after leaving the passage.
- [x] Enterable farm wall and hedge per battlefield, capacity reservations, troop
  files, timed manning, directional protection, approach and exit orders.
- [x] Explicit shield-marker occupation, frontage-filling troop slots, arrival-gated
  protection, and visible approach/manning/occupied status.
- [ ] Additional fortification layouts, building garrisons and assault/capture
  behavior. Either side can currently occupy a vacated position.
- [x] Road/slope marching modifiers on both maps, alongside existing woods effects;
  directional wall/hedge protection in battle.
- [x] Multi-front melee allocation and individual contact placement, with stable
  soldier assignments and regiment attack strength shared among opponents.

## Presentation

- [x] Shared painterly terrain materials, crop masks and static scenery shading
  across all battle scenarios and campaigns; irregular woodland silhouettes,
  denser settlements and muted compact battle roster.
- [x] Lower adjustable camera: 35° default, 28–60° range, Q/E and toolbar buttons;
  terrain picking and sprite selection follow the actual camera angle.
- [x] Grand map pass: new 5760×3840 battlefields with five crossings and populated
  outer approaches; 17280×11520 Italy/Mantua campaigns, versioned migrations
  and unchanged active legacy battle coordinates. See
  [GRAND_LANDSCAPES.md](../godot/GRAND_LANDSCAPES.md).
- [x] Shared town layout and adjusted tactical building scale; quieter irregular
  fields on both maps and a painted hedge using the existing woodland artwork.
- [x] Authored Mincio exercise with connected village streets, garden patches,
  single church landmark, farm stores, planted orchards and irregular wood edges.
- [x] Expanded painted infantry march/passing poses and diagonal directions,
  cavalry extended/gathered charge poses and artillery swab/ram/prime stages.
- [ ] Additional directional actions and animated hit/death transitions.
- [x] Cover/passage states, clearance warnings, invalid destination preview colors,
  partial-order feedback and a defensive-position hover cursor.
- [x] Varied native sounds, camera-relative horizontal panning and voice priority.
- [x] Quiet looping wind, restrained reverb, camera-relative two-dimensional
  attenuation and distance filtering, with bounded prioritized voices.
- [ ] Recorded battlefield ambience and terrain-dependent acoustic occlusion.
- [x] Persistent prepared-art cache, cached formation footprints, contact broad
  phase and exclusion of generated screenshots from the asset import scan.
- [ ] Progressive loading feedback and tighter worst-frame budgets on larger battles.
- [x] Separate 12-versus-12 and 20-versus-20 exercises with arriving reserves,
  scalable figure/shadow batches, sleeping stationary formations, sparse route
  graphs, staggered visibility and native performance captures. See
  [battlefield polish notes](../godot/BATTLEFIELD_POLISH.md) for measured limits.
- [x] Runtime spatial indexing and transition-geometry caches, exact swept
  passage checks, budgeted route/fog work, 15 Hz visual steering with GPU
  interpolation, shader-driven reload/melee clocks and cached casualty ground
  samples. A fixed-30-Hz native benchmark replaces per-frame simulation timing;
  dedicated regressions cover cache invalidation, selection and combat safety.

## AI And Headquarters

- [x] Tactical infantry can select and occupy an appropriately facing defense.
- [x] First coordinated battle planner: shared stance and infantry sectors,
  supporting batteries, selective cavalry charges, pressure-driven reserves,
  emergency reactions, recovery and withdrawal; separate defensive exercise,
  saved decisions, diagnostic overlay and staggered planning.
- [ ] Broader terrain/encirclement planning, coordinated multi-army assaults,
  configurable difficulty and persistent strategic enemy retreats.
- [x] Persistent aggressive/cautious/opportunist preferences, relative-strength
  decisions, fatigue withdrawal and pursuit of recent sightings rather than hidden
  player coordinates. Visible inspectors expose personality, intent and fatigue.
- [ ] Campaign objective planning beyond patrol/intercept/withdraw behavior.
- [x] Officer/weapon comparisons, corps capacity feedback and eligible reassignment.
- [x] Purchase batch totals and replenishment cost/weapon/experience previews.
- [ ] Preserve uncommitted headquarters input values across window resizing.
- [ ] Richer reports and records beyond the existing battle/service history.
- [ ] Multi-level abilities, experience dilution and perk loss/reselection.
- [ ] Timed recruit/veteran replacements with money, weapons and manpower costs.
- [ ] Expanded weapon catalog and actual recovery/capture ledger.

## Campaign And Release

- [ ] Researched Northern Italy geography and encounter locations.
- [ ] Persistent supply objectives, depots, forts and supply interception.
- [ ] Physical scouts, recall, detection, capture/loss and delivered reports.
- [ ] Town loyalty and physical couriers tied to intelligence.
- [x] Previous validated save backup, recovery from missing/corrupt primary,
  and preserved files with autosaving disabled if both snapshots are invalid.
  Successful manual save/load resumes recovery-suspended autosaving.
- [ ] Configurable controls and user-adjustable UI scaling.
- [ ] Full-campaign balancing and human playthrough, including defeat/recovery.
- [ ] Packaged Windows build and exported-build verification.

## Delivery

Implement shared battlefield foundations first, then presentation/management,
then strategic expansion. Each completed system needs UI, save compatibility,
focused tests and a native graphical review. A larger map or passing isolated
tests is not completion of the historical campaign or of the visual quality goal.

Exact implemented rules and limitations are in
[Battlefield Foundations](../godot/BATTLEFIELD_FOUNDATIONS.md). Automated results
and measured frame times are maintained in [the native README](../godot/README.md#verification).

## Next Milestones

1. Complete narrow-passage and turn clearance, then multi-front melee/contact
   allocation. Validate bridge queues, two-way traffic and prolonged mixed-unit
   fighting before adding more armies.
2. Add timed replacements and manpower accounting, then level thresholds,
   selectable abilities and perk loss/reselection after experience dilution.
   Keep recruitment previews, save migration and post-battle accounting aligned.
3. Add researched Italy objectives, supply sites and forts, then physical scouts,
   delivered intelligence and town loyalty. General preferences should operate
   over those strategic goals rather than a new unrelated AI system.
4. Expand authored environment layouts and painted animation/audio coverage;
   balance a full win/loss/recovery campaign and verify an exported Windows build.
