# The Mantua Operation

Operational campaign demo, September 24, 2026. Starts with one Army of Italy and
three opposing columns. The legacy illustrative Italy/Danube campaigns and
battle exercises remain available and keep their old rules.

## Launch And Saves

Run **Mantua Campaign.cmd**, or `tools/launch.ps1 -Mode Campaign`. This starts or
resumes a separate `user://mantua-operation.json` save, with temporary-file
replacement and a validated `.bak`. It does not overwrite `campaign.json`.
Settings > New Campaign > Mantua operation also works, but replaces the campaign
in that launch's active save slot after confirmation.

Select an army on the map or in the compact bottom strip. Left-drag selects
several armies; right-click moves them or intercepts a visible enemy. Marching
pace is independent of simulation speed. Army inspection shows supplies,
confidence, estimated remaining march time, and regrouping status.
Holding right-click previews each selected army's route, arrival estimate and
projected fatigue before releasing the order.
Post-battle recovery no longer immobilizes an army once its forced retreat has
finished. Right-click moves or intercepts at **70% of its otherwise applicable
marching pace** while it reorganizes. Morale losses and the recovery deadline
remain. The victorious force pauses for **two simulation seconds** before it can
pursue; pausing or changing time speed affects this delay normally.
Orders issued during a forced retreat or the victor's brief reforming pause are
queued, with a flag at the destination. They begin automatically when that
restriction ends, without waiting for the full recovery period. A newer order
replaces the queued destination, and Halt cancels it without cancelling a forced
retreat. Queued orders survive saving and loading, including orders stranded by
the earlier full-recovery movement lock. March orders do not silently unpause
the campaign; paused orders explicitly report that time is paused.

## Forces

- One starting army; at most four player forces, each up to eight regiments.
- Split Army chooses whole regiments for a named detachment. Both forces must
  retain living troops. Splitting requires a stationary, regrouped army.
- Merge Armies reunites halted forces within 100 map units and with an unobstructed
  ground connection. The resulting army must fit the eight-regiment limit.
- Troops, equipment, experience, histories, ammunition and supplies are conserved.
  Partial corps detachments get a vacant staff position; an entire transferred
  corps keeps its commander. Corps never retain units in two separate armies.
- Headquarters is scoped to the selected army and has an army selector. New
  regiments, replacements and paid resupply require a friendly depot and a
  stationary army that has finished regrouping.
- Army commanders are officer records, can be replaced with available brigadiers
  or generals from headquarters, and gain experience in battles they attend.
  Detached forces initially use an acting commander until an officer is assigned.
  Reinforcing armies bring a separate general at their scheduled arrival;
  generals follow, support and rally their own army's regiments.
- Excess supply from combining full trains is retained in the depot reserve and
  used before charging for subsequent supply purchases.

## Army Morale

Army confidence persists independently from each regiment's battlefield morale.
Both sides use the same rules:

- Normal confidence: 60/100.
- Battlefield morale-loss multiplier: `1 + (60 - army_morale) * 0.006`, bounded
  to 0.76-1.36. At 90 confidence morale damage is reduced by 18%; at 20 it is
  increased by 24%. Rallying a regiment does not remove this army-wide effect.
- Starting tactical morale: `100 + (army_morale - 60) * 0.4`, bounded to 76-100.
- A victory adds 12 confidence; defeat or withdrawal subtracts 18. Both also
  subtract `25 * casualty_fraction`. A very costly victory can reduce confidence.
- Rest at a friendly depot restores low confidence by two points per campaign
  hour, up to 60. Confidence above 60 settles by half a point per hour. No supply
  costs two confidence points per hour.
- Splits inherit confidence; merges average it by surviving troop count.
- Victors regroup for half an hour; defeated forces regroup for four hours and
  march toward a friendly depot. They cannot be immediately caught in another
  battle or split during this period. New marching orders do not interrupt the
  required retreat, but can begin at reduced pace immediately afterward. Normal
  marching speed returns at the recovery deadline. These movement rules and the
  victor's short pursuit delay apply to both sides.

## Movement, Supply And Objectives

The map is 8640x5760, four times its previous area, with a north-south Mincio corridor, four usable crossings,
ten named locations, roads, woodland and relief. Routes compare a road-network
path from Godot's AStar2D with the existing terrain-grid route. Roads are faster;
woods, slopes, fatigue and march mode affect pace. ETA samples the planned path
using those modifiers. It is an estimate, not a promise that fatigue stays fixed.
Queued-order previews include the remaining withdrawal/reforming delay and
reorganization speed penalty. Routes are checked
again from the army's actual position when the order begins. If an intercepted
enemy is no longer visible, the army heads for its last ordered location instead
of tracking it through fog of war.

New battles use 2880x1920 battlefields with additional maneuvering terrain.
Marching pace, encounter distance and reinforcement travel rules are unchanged,
so the larger campaign distances take longer to traverse. Save migration scales
armies, intelligence, orders and objectives together and preserves campaign
progress. Existing battles retain their original layouts until resolved.
See [LARGE_MAPS.md](LARGE_MAPS.md) for compatibility and verification details.

Each force has its own fatigue, supply stock and paid reconnaissance timer.
Enemy columns rest and tire under the same rules as the player. Supplies deplete
away from depots; stationary armies replenish stocks and ammunition at friendly,
uncontested depots. Enemy personality, observed player strength, recent sightings,
nearby allies, fatigue, confidence and supplies influence strategic orders.

Ordinary sites need 0.4 hours of uncontested stationary occupation by at least
100 troops. Mantua needs eight hours and at least 600 troops. Contested sites do
not progress; abandoned progress decays. A first capture pays a small reward.
Secure Mantua and Valeggio, retain a depot, and hold for two hours to win.

## Encounters And Persistence

Contact between armies requires an unobstructed connection, so opposing banks
do not trigger battles through impassable water. The encounter chooses one of
the existing crossing/village/heights tactical templates from its location.

Nearby armies are evaluated using route travel, not just a circular distance
test. Forces within 2.5 estimated campaign hours join the saved schedule; one
campaign travel hour maps to 120 tactical seconds. Reinforcements enter from the
approach edge, bring their supply, and become selectable only after arriving.
Campaign time and unrelated armies remain frozen during the tactical battle.

Enemy regiments are generated only when the operation is created. Their losses,
ammunition and experience survive subsequent encounters. Surviving defeated
armies withdraw rather than being erased. Reinforcements that actually arrived
return near the encounter; unarrived and uninvolved forces are unchanged.
Captured weapon types are based on actual enemy casualties, not the initial
size of the opposing army. Reports include each participating player's army
confidence change.

## Limits And Next Scenario Work

This is a historical-inspired operational demo, not an exact August 1796
reconstruction. Locations provide a recognizable geographic scaffold, but the
river, roads, vegetation, strengths, starting positions, siege duration and
battlefields are simplified. Mantua is a blockade objective, not a separately
modeled fortress assault. Battlefield supply is pooled into one train per side.
Scouting expands a force's observation radius; physical patrols and couriers are
not implemented by this pass. There is no concurrent tactical battle simulation.

Historical battle mode still needs researched orders of battle, purpose-built
maps and scenario deployments. Full Northern Italy, additional operations,
siege assaults, physical reconnaissance, and detailed logistical routes build
on this demo rather than being claimed as finished here.

Historical context: [Fondation Napoleon, The Sieges of Mantua](https://www.napoleon.org/en/magazine/publications/napoleon-in-italy-the-sieges-of-mantua-1796-1799/).

## Verification

September 25 movement follow-up: **189 model and 114 native campaign checks
passed**. The native runner also replays the player's
actual saved campaign in memory, issues real right-click and Play input, and
checks that the army moves without altering the saved file. Coverage includes
movement during recovery, its 30% pace penalty and ETA, both sides' two-second
pursuit delay, queue replacement/cancellation, forced retreat preservation,
mixed readiness, save validation, lost targets and desktop/narrow layouts.
Captures include `test-results/operation-regrouping-*.png` and
`test-results/operation-saved-march.png`.

```powershell
& $godot --headless --path $project --script res://tests/operations.gd
& $godot --path $project -- --verify-campaign
& $godot --path $project -- --verify-campaign --save=user://mantua-operation.json
& $godot --headless --path $project --script res://tests/campaign_movement.gd -- --save=user://mantua-operation.json
```

The first suite covers model rules, conservation, ownership, saves, malformed
data, objectives, morale, persistent defeats and arrivals. The native test covers
desktop/narrow layouts, split/merge dialogs, group selection and movement,
headquarters, map rendering, battle transition and reports. Captures use the
`test-results/operation-*.png` prefix.

September 24 verification: 142 operational model checks, all 660 existing
headless regression checks, and 77 native campaign checks passed. Native captures
cover desktop and 390x844 layouts, including
reinforcing generals before/after arrival. These focused checks are not a full
performance certification or a human playthrough of the whole operation.
