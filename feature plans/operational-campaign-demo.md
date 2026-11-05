# Operational campaign demo

## Scope

Start with one player army, allow detachments and reunification, and retain the
same regiments on both sides between encounters. Existing Italy/Danube saves and
battle exercises remain separate from the new Mantua operation.

Implementation order:
1. Persistent force ownership, selection, split/merge, and save validation.
2. Army morale, supply, fatigue, movement estimates, scouting, and enemy orders.
3. Geographic Mantua/Mincio sector, crossings, depots, and capture objectives.
4. Encounter rosters, route-based reinforcement schedules, and persistent retreat.
5. Compact campaign controls, headquarters integration, and regression tests.

## Demo Status: September 24, 2026

- [x] One starting player army, up to four forces, whole-regiment splits and
  nearby merges without resetting troops, equipment, supply or experience.
- [x] Persistent army morale for both sides, victory/defeat effects, depot
  recovery, and battlefield morale resilience. Casualties can offset victory.
- [x] Independent marching modes, fatigue, supplies, route/arrival previews,
  road-aware navigation and personality-driven enemy objective selection.
- [x] Mantua/Mincio sector with four crossings, ten named locations, capturable
  depots, blockade progress and a sustained-occupation victory condition.
- [x] Persistent enemy regiments, encounter-based tactical rosters, approach-edge
  reinforcements, captured weapons and surviving armies that withdraw.
- [x] Army-scoped headquarters, recruitable/reassignable army officers and
  battle experience. Reinforcing generals arrive with their own troops and
  only command and rally their own army.
- [x] Compact army strip, multi-army selection/orders, split/merge dialogs,
  objective status, army inspection and battle morale reports.
- [x] Separate Mantua launcher/save slot, model tests and native UI coverage.
- [ ] Human full-operation playthrough and tuning of movement, reinforcement
  timing, casualties, recovery, supply costs and difficulty.

Launch [Mantua Campaign.cmd](../godot/Mantua%20Campaign.cmd). The exact demo rules
and controls are in [OPERATIONAL_CAMPAIGN.md](../godot/OPERATIONAL_CAMPAIGN.md).

## Rules

- Campaign time pauses during tactical combat. Reinforcement travel is snapshotted
  once; uninvolved forces do not move while a battle is being played.
- Army morale is 0-100, with 60 as ordinary confidence. Battlefield morale damage
  scales with army confidence; victories improve confidence and defeats reduce it.
  Heavy casualties can offset a victory bonus. Rest at a friendly depot restores
  low confidence slowly. High confidence gradually settles toward normal.
- Splits inherit confidence and divide supply by troop strength. Merges use
  troop-weighted confidence and condition. Neither action resets battle history,
  losses, ammunition, or retreat immunity.
- Detachments require at least one living regiment to remain in each force.
  Transfers and merges require nearby, stationary forces on a connected route.
- Enemies retain their own regiments, ammunition, supplies, morale, and losses.
  A tactical defeat causes a strategic withdrawal, not automatic destruction.
- Objectives require sustained uncontested occupation. The fort requires a longer
  blockade. Depots restore supply; an exhausted force cannot capture a site by
  merely passing through it.

## Historical fidelity

The demo is a compressed, historical-inspired Mantua operation, not a certified
reconstruction of a particular day's order of battle. Settlement placement and
the Mincio corridor provide a geographic scaffold; roads, river widths, woods,
troop numbers, objectives, and the siege timescale are gameplay abstractions.
Historical battle deployments and full-strength researched rosters remain a
separate scenario-authoring task after the operational mechanics are tested.

## Expansion Order

1. Playtest this operation through victory and defeat/recovery; profile larger
   encounters before raising army and regiment limits.
2. Author a researched historical battle: date, orders of battle, commander
   identities, terrain, starting deployment, objectives and reinforcement entry.
   Validate both standalone play and campaign-derived casualties/conditions.
3. Replace the three reused battlefield templates with location-specific maps,
   including purpose-built crossing, settlement and fortress approaches.
4. Expand the operational geography into Northern Italy with additional
   operations, supply routes and scenario selection. Maintain separate scenario
   data so later campaigns do not require a new simulation implementation.
5. Complete physical scouts/couriers, town loyalty, supply interception and the
   fort blockade/relief/assault sequence. Current scouts are observation-radius
   reconnaissance; current Mantua is a blockade objective, not an assault map.
6. Complete the progression/replenishment systems in the original roadmap:
   multi-level abilities, timed replacement queues, veteran money/manpower costs,
   recruit experience dilution, and loss/reselection of perks after level loss.
7. Finish authored art/animation, accessibility, performance, export testing and
   whole-campaign balance. Campaign time remains paused during tactical play;
   concurrent tactical battles require a separate design and testing pass.

Background: [Fondation Napoleon, Napoleon in Italy: The Sieges of Mantua](https://www.napoleon.org/en/magazine/publications/napoleon-in-italy-the-sieges-of-mantua-1796-1799/).

## Verification

Cover conservation of troops/equipment/supply across splits and merges; reject
remote merges and malformed saves; round-trip campaign and battle saves; verify
morale buffs/debuffs for both sides, fatigue, objectives, delayed arrivals,
uninvolved armies, retreat persistence, and native desktop/narrow controls.

September 24 results: 142 operational model checks and 77 native campaign checks
passed, including save/reload of reinforcing generals and army-scoped rallying.
All 660 existing headless regression checks also passed.
Full-performance acceptance and a human campaign playthrough remain open.
