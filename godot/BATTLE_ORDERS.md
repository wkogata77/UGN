# Battle Orders, Sight, And Morale

September 10, 2026. Native Godot follow-up to [COMBAT_MOTION.md](COMBAT_MOTION.md).
The existing painted sprites and displacement-driven step frames are retained.

## Steady Troop Movement

- All figures in a regiment share its current march/run/charge speed ceiling,
  including terrain, formation, and condition modifiers. Being behind a slot
  does not unlock a faster catch-up speed.
- Short starting/stopping transitions and bounded steering remain. Inner files
  can wait during a wheel; outer files walk. The center reserves enough movement
  budget for the outer files to turn without sprinting.
- Moving slots no longer expand frontage or rotate different rows using past
  trail headings. Small fixed per-figure offsets preserve independent spacing,
  especially for cavalry, without the fan-in/fan-out effect.
- Infantry still refill casualties within their files. Repositioning at rest
  is slower than marching; bodies and soldier identities remain stable. Melee
  figures keep facing the contact front while repositioning.

## Sight And Fire Obstruction

Direct sight and firing tests sample the same cached triangular terrain surface
used to ground the figures, at intervals no greater than 12 map units. A crest
can block even a short shot; there is no blanket close-distance bypass. Deep
woodland blocks fire and observation, and distant forest occupants are concealed.
Enemy acquisition uses sightings shared by living, arrived enemy regiments,
instead of treating every player regiment as known. Player command observers
and the existing periodic fog update remain.

Friendly obstruction uses the full oriented formation footprint, not a narrow
circle around its center. Close and offset friendly formations, including
skirmisher detachments, can block fire. The selected target line is green when
clear or red with a cross when obstructed; the maximum weapon-range outline
remains separate from LOS. Obstructed shots do not spend ammunition or deal
damage. Contact melee does not require a clear firing lane.

These are direct-fire and regiment-footprint rules, not per-projectile ballistics
or per-soldier ray tracing. Decorative buildings are still not authored LOS
occluders or enterable cover; they require shared footprints with future cover
and pathing work. Campaign intelligence retains its existing reconnaissance rules.

## Retreat

- **Fall back / X** remains a short tactical withdrawal facing the threat.
- **Retreat unit / R** orders selected regiments to their own deployment edge.
  They remain visible, vulnerable, and on the battlefield until they arrive.
  Guns pack for five seconds before moving and stay limbered while retreating.
- Retreat cancels attacks and charging; withdrawing troops do not fire ranged
  weapons. They can defend themselves if still physically in melee.
- Halt or a new move order cancels withdrawal before the edge. A withdrawn unit
  cannot return during that battle; its roster card is disabled. It no longer
  supplies sight, command through a hosted commander, obstruction, or objective
  control. Survivors return to the campaign roster in the battle report.
- Withdrawing the last regiment ends the battle as a withdrawal,
  without a victory reward. The existing whole-army withdrawal dialog is separate.

## Charge

**Charge / C** orders eligible infantry or cavalry to close with a visible enemy.
Artillery cannot charge. Square formation, ongoing reform, retreat, routing,
existing contact, insufficient condition, or cooldown prevent a new charge.

| Rule | Infantry / dismounted cavalry | Mounted cavalry |
| --- | --- | --- |
| Speed relative to normal movement | 1.65x | 1.80x |
| Movement exertion per simulation second | 2.2 | 1.2 |
| Maximum single impact damage multiplier | 1.65x | 2.50x |
| Distance needed after first 12 map units for full momentum | 42 | 65 |

Ordinary running uses 1.45x speed and 0.9 exertion. Skills, perks, terrain, and
condition still modify the relevant movement or fatigue calculations. Existing
mounted melee strength and the strong square counter remain in effect.

Momentum comes from actual forward movement toward the target. Wheeling,
stalling, or insufficient speed loses momentum. Standing contact earns no bonus.
The first contact consumes momentum for one impact, independent of the previous
ranged reload. Sustained melee uses normal damage afterward. The charge times
out after 18 simulation seconds; another charge requires a 12-second cooldown
and leaving contact. Repeated clicks do not restart the run-up. Orders, target
loss, reforming, exhaustion, and routing cancel charging. Pause freezes it.

## Directional Morale

Incoming attacks are classified using the defender's actual regiment facing:

| Sector | Bearing relative to defender's front | Morale pressure per casualty |
| --- | --- | --- |
| Front | Up to 45 degrees | 1x |
| Either side | Beyond 45 and below 135 degrees | 2x |
| Rear | 135 through 180 degrees | 3x |

Rear attacks retain a separate 1.4x casualty modifier. Thus rear fire is the
most dangerous both in casualties and morale. Command support, discipline, and
the Steadfast perk still reduce morale loss. Wavering troops can rout from this
pressure; left and right flank penalties are symmetric. Brief **Flank attack!**
and **Rear attack!** warnings appear on the map and roster, with rear warnings
taking priority when hit from both directions. The same exposure rules apply
in close combat. A blocked shot or an artillery miss causes no morale loss.

## Verification

`tests/battle_orders.gd` covers actual LOS, close crests, friendly frontage,
AI knowledge, sector-specific volleys and routing, charge eligibility/impact/
fatigue/pause/save behavior, east/west retreat and survivor retention, artillery
packing, uniform cruising speed, bounded frontage, reversals, and final settling.
The native visual suite exercises the new toolbar and keyboard controls, map
warnings, blocked-fire line, withdrawal removal, and desktop/narrow layouts.
The existing simulation, motion, and campaign regressions remain part of
`Verify.cmd`. Latest verified totals are in [README.md](README.md).
