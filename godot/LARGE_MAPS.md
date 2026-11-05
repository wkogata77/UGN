# Larger Campaigns And Battlefields

## Playable Dimensions

| Map | Previous | New | Area increase |
| --- | --- | --- | --- |
| Mantua operation | 8640x5760 | 17280x11520 | 4x |
| Italy sector | 8640x5760 | 17280x11520 | 4x |
| Danube campaign | 2880x1920 | 5760x3840 | 4x |
| Valeggio, Saint Martin, The Heights | 2880x1920 | 5760x3840 | 4x |

Dimensions are game coordinates, not kilometers or historical survey data.
The campaign geography is the existing illustrative theater spread over a
larger playable space, not a new historical operation or additional provinces.

Battlefield version 3 translates the original central encounter by (2160, 1440).
Troops, buildings, fortifications, firing ranges and marching speeds retain
their physical scale. The surrounding terrain adds woodland districts, broad
ridges, six outer settlements and connecting roads. Valeggio now has five
crossings while retaining the central bridge as its capture objective. The
Mincio exercises spread their initial fronts and reserves further apart.
Delayed reinforcements enter at the actual perimeter. The shared art and
lower adjustable camera are described in [GRAND_LANDSCAPES.md](GRAND_LANDSCAPES.md).

Campaign armies and objectives are farther apart. Normal marching, route
marching and slow movement retain their existing fatigue and speed rules.
Enemy sight ranges, encounter distances and reinforcement travel limits remain
physical distances/time, so widely separated armies cannot support each other
merely because the map grew. Depot and capture footprints grow with strategic
geographic spacing. Town buildings and troop art retain their scale.

## Camera And Navigation

Overview and wheel zoom support the expanded terrain. Camera height and far
clip distance grow for wide views; terrain picking uses the same depth range.
The camera remains inside padded rendered terrain, including narrow windows.
On narrow aspect ratios, maximum zoom-out is constrained by that terrain;
pan to see the remainder instead of exposing an empty background.

Order limits, deployment bands, AI positions, withdrawal edges, pathfinding,
river crossings, bridge decks, fog and minimaps use the active map dimensions.
New battlefield fog is 120x80 cells, retaining the original 48-unit resolution.
Campaign ground meshes use coarser spacing for large-scale relief; tactical
meshes retain approximately 24-unit spacing and troop/LOS surface agreement.

## Save Compatibility

Campaign map version 4 migrates old armies, paths, queued orders, remembered
enemy positions, homes, redeployment points and operational sites once. Shared
army dictionaries are not double-scaled. Strategic battle origins migrate too.
Money, morale, strength, supplies, progression, ownership and campaign time
remain unchanged. Version-3 native files get a `.pre-grand-map.bak` backup
before migration; earlier migrations retain `.pre-large-maps.bak`. Existing
backups are never replaced.

New battles use battlefield version 3. Existing version-2 battles retain
2880x1920 and unversioned/version-1 battles retain 1440x960. Their fog,
fortifications and tactical coordinates stay in their original layout.
No mid-battle stretching or rebuilding of combat orders occurs. On returning
to the campaign, the enlarged strategic map is used for subsequent play.

## Verification

Run from the Godot project directory:

```text
godot --headless --path . --script res://tests/maps.gd
godot --headless --path . --script res://tests/regression.gd
godot --headless --path . --script res://tests/operations.gd
godot --headless --path . --script res://tests/terrain_relief.gd
godot --path . -- --verify-maps
```

Model checks cover distant orders, migration/reload, legacy battles, peripheral
movement, AI positions, deployment, retreat, fog, and each tactical crossing.
The native visual suite checks actual right-click movement, populated terrain,
camera boundaries, bridge-road heights, fog texture dimensions and desktop /
narrow-window rendering. Screenshots are written under `test-results/large-*`.
Visual test mode never enables campaign autosaving.
