# Shaped Fortifications

September 25, 2026. Battle maps now contain three distinct infantry positions:

| Position | Structure | Troop layout | Capacity | Frontal protection |
| --- | --- | --- | --- | --- |
| Farm enclosure | Stone front wall, returning side walls, coping and end piers | Multiple ranks along the front and sides, open rear entrance | 900 | 45% |
| Orchard hedgerow | Curved planted hedge with a timber fence and worn ground | Curved ranks following the hedge, with outward-facing end sections | 720 | 25% |
| Field redan | Angled earth bank, timber revetment and wicker gabions | Angled ranks behind each face, open rear | 900 | 55% |

Right-click a shield marker with eligible infantry selected to reserve and man
the position. Ground clicks remain ordinary movement orders. Soldiers march to
the entry, then fill the shaped slots over time; protection is not awarded until
the living figures have actually reached their positions. Occupied positions
remain reserved to one regiment. Right-clicking the same marker again does not
restart deployment. Leave, movement, retreat and routing release the position.

The geometry, hover outline, troop slots and outward headings share the same
profile. Troops have at least two ranks, with additional ranks for larger
garrisons. Corner clearance prevents overlapping slots. Casualties leave bodies
at their actual positions, and replacements move forward within their own file
instead of reorganizing the entire garrison. Layouts and assignments survive
saving and loading, including the existing wall and hedge IDs.

Returning sides provide partial flank protection. The open rear remains
vulnerable; melee protection is reduced. Combat remains regiment-level, not
individual loophole ballistics. These are field positions, not a complete siege,
destructible-wall or player-built fortification system.

## Rendering

Native Godot batched meshes supply masonry, coping, posts, timber and gabions.
The earth bank is relief-conforming, with joined corner sections. Procedural
surface materials and the existing terrain/woodland textures retain the game's
palette without replacing the troop art or adding another sprite atlas.

## Verification

- `tests/fortifications.gd`: 228 checks covering all three maps, garrison sizes,
  slot spacing, walkable positions, outward facing, casualties, occupancy,
  directional protection and persistence.
- `--verify-cover`: 53 native graphical/input checks, with desktop and 390x844
  captures for every fortification under `test-results/fortification-*.png`.
- `tests/polish.gd`: 151 checks, including the previous fortification contract,
  map layout, movement, cover reservation, save recovery and audio.

```powershell
& $godot --headless --path $project --script res://tests/fortifications.gd
& $godot --headless --path $project --script res://tests/polish.gd
& $godot --path $project -- --verify-cover
```
