# Faction Arsenal And Artillery

The native game now uses `data/arsenal.json`, independently of the unchanged
browser prototype. It contains 22 equipment entries, including ten infantry
firearms. `scripts/arsenal.gd` handles migration, equipment roles and salvage.

## Infantry Choices

| France | Role | Price per weapon |
| --- | --- | ---: |
| French reserve musket | Worn, inexpensive depot equipment | 4 F |
| Republican composite musket | Mixed-pattern emergency issue | 5 F |
| Charleville M1766 | Older service arms | 6 F |
| Charleville M1777 | Standard line musket | 8 F |
| M1777 arsenal-selected | Inspected arms with modest consistency gains | 13 F |
| Versailles specialist rifle | Scarce, slow-loading aimed-fire equipment | 26 F |

| Austria | Role | Price per weapon |
| --- | --- | ---: |
| Austrian reserve musket | Worn depot smoothbores | 4 F |
| Austrian M1784 | Standard line musket | 8 F |
| M1784 arsenal-selected | Inspected service arms | 13 F |
| Jager Stutzen | Scarce long-range specialist rifle | 27 F |

The rifle advantage is reach and aimed fire, not close-range volley throughput.
Each weapon has its own reload, accuracy rating, range falloff and firepower.
Reload figures are base simulation seconds; training still modifies actual
reload time and its animation. Accuracy is a relative rating, not hit probability.
Range uses game-world units, not a claim of measured historical effective range.

Headquarters can recruit a 100-man light company for 400 F and 100 reserve
muskets, using a normal corps slot. It is an independent persistent skirmisher
unit, not a temporary battlefield detachment. Its small strength allows either
specialist rifle stock to equip it immediately after purchase. Depot/admin rules
still apply in the operational campaign.

Cavalry can carry a French dragoon musket, French hussar carbine or Austrian
carbine. Sabres remain part of cavalry equipment regardless of firearm selection.
Mounted fire is less accurate than dismounted fire. All firearm-equipped cavalry
can dismount. Firearm price/power no longer increases melee damage.
Separate purchasable bayonet and sabre inventories are not modeled.

## Artillery And Firing Orders

France has Gribeauval 4-, 8- and 12-pounders and a 6-inch howitzer. Austria has
3-, 6- and 12-pounders and a 7-pounder howitzer. Light guns move and deploy faster;
heavy guns have greater reach and power, but longer reload/deployment and higher
supply consumption. The AI uses Austrian equipment and deployment timings.

- Direct-fire gun lanes are checked individually across the battery frontage.
  One blocked center ray no longer silences every gun; obstructed guns do not fire.
- Friendly formations, buildings and terrain still block direct fire.
- An explicit attack order deploys limbered guns after their preparation timer.
  If the target is spotted and in range but blocked, the battery searches nearby
  reachable firing positions. Searches are bounded and retried no more than once
  every three simulation seconds. It does not guarantee a route around an entire
  mountain or settlement; a manual move may still be needed.
- Idle batteries retain arc-limited automatic fire and never auto-turn to rear
  targets. Move/Halt cancels attack repositioning.
- Status reports no spotted target, out of range, outside arc, terrain/friendly
  obstruction, movement, deployment and reload instead of silently idling.
- Close-range fire automatically uses canister. Field guns otherwise use round
  shot; howitzers use shells with a checked arcing trajectory. A spotted target
  is always required. Shells can clear sufficiently low obstacles but cannot
  pass through a hill, building or friendly formation intersecting their arc.
- Shells use a larger strike area, reduced directional-cover protection and a
  distinct burst marker. Damage still resolves at volley time against the target
  formation; multi-unit blast damage, delayed flight, round-shot penetration and
  destructible scenery are not implemented. This is not a full ballistics model.

The reported saved battery at Valeggio was deployed with ammunition, facing an
enemy in range, but its terrain sightline was obstructed. The old target filter
discarded that enemy before assigning an obstruction status. The attack-order
change and status reporting address this without disabling line of sight.

## Armory And Captures

Headquarters filters by troop type and faction. The equipment inspector previews
differences before issuing arms and shows reserve requirements. Stocks are finite;
the new campaign starts with the existing owned equipment and broader dealer stock.

Both campaign modes recover the actual enemy weapon types from participating
casualties after a victory. Infantry/cavalry recover 18% of losses. Artillery
recovers 40% of whole guns represented by crew losses, rounded up. A quarter of
captured stores, rounded down, need paid refurbishment. Damaged stores cannot be
equipped or sold until repaired; the Armory's refit transaction costs 35% of the
weapon's purchase price rounded up per item. Refit is immediate in campaign mode.
Reports distinguish ready stores from those needing refit. No loot is awarded
for reinforcements that never arrived or for a defeat.

Ammunition remains an abstract shared supply stock, with per-weapon consumption.
National calibre inventories and automatic market restocking are not modeled.

## Save Compatibility

All seven legacy equipment IDs remain valid. `improved` now denotes inspected
M1777s, not an anachronistic AN IX upgrade; `cannon` denotes the French 8-pounder.
Owned stocks and player equipment are preserved. Existing enemy French/generic
issue maps to Austrian equivalents. New stock ledgers initialize once. Native
saves receive a `.pre-arsenal.bak` backup before migration; browser imports remain
read-only. Migration does not reset army positions, losses or battle progress.

## Historical Scope

Reserve, composite and arsenal-selected entries are explicit game abstractions
for condition and supply, not invented official historical model designations.
Prices, tiers and stock allocations are balance values. Exact issue to individual
1796 formations, especially specialist rifles, is not claimed to be reconstructed.

- [Smithsonian: French Model 1766 musket](https://americanhistory.si.edu/collections/object/nmah_469490)
- [French arms and the later AN IX modification](https://www.napoleon-empire.org/en/weapons-revolution-empire.php)
- [Fondation Napoleon: Gribeauval field artillery](https://www.napoleon.org/histoire-des-2-empires/articles/le-systeme-gribeauval/)
- [ASAC catalogue: Austrian M1784, entry M215](https://americansocietyofarmscollectors.org/wp-content/uploads/2025/11/FullCombinedFiles_Edit1Nov8th_Compressed.pdf)
- [Original 1796-pattern Jager rifle](https://kapszli.hu/loveszet-egy-eredeti-1796-m-jagerstutzen-kovas-puskaval/)
- [Osprey: Austrian Napoleonic Artillery 1792-1815](https://www.ospreypublishing.com/us/austrian-napoleonic-artillery-17921815-9781841764993/)

## Verification

`tests/weapons.gd` covers all weapon entries, live firing/reload, gun lanes,
arc restrictions, deployment, obstructed attack orders, howitzer trajectories,
price/stock conservation, salvage/refit, browser/native saves and headquarters.
`--saved-battery` replays a copy of the local Mantua save without changing the
original. Native `--ui-only` produces desktop/narrow armory and army captures.
Native `--battle-view` checks a firing howitzer, shell markers, inspector/command
rail separation and nonblank battlefield pixels at 1440x900 and 390x900.

September 26 verification: 1,346 headless checks passed across weapons (323),
simulation (152), operations (189), battle orders (82), expansion (42), combat
motion (87), battle AI (79), polish (153), town movement (97), terrain relief
(51) and maps (91). Native armory/army checks passed 62 assertions and the native
battle view passed eight. The separate saved-battery replay found a reachable
clear firing position and preserved the original save byte-for-byte. Full
renderer performance and the unchanged browser suite were not re-profiled.
