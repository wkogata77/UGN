# Visual Demo Performance

The original performance pass was scoped to `/?demo=depth`, without changing
simulation rules, army strengths, speed settings, or formation-based firing
ranges. Subsequent demo polish adds directional sprites, revised leg meshes,
WASD, the compact roster, and artillery dispersion; see the README. The original
Phaser game's combat rules and controls remain unchanged.

## Rendering Changes

- Terrain picking uses a per-mesh bounding-volume hierarchy from
  [three-mesh-bvh](https://github.com/gkjohnson/three-mesh-bvh), pinned at 0.9.14.
  No Three.js prototypes are patched. The minimap's camera footprint is cached
  until the camera or landscape changes, eliminating repeated terrain queries
  while the camera is stationary.
- Animated sprites select 35, 77, or 187 vertices based on their projected
  screen height. The subsequent stride pass uses 49 vertices for distant
  infantry, keeping mesh boundaries between the boots. Every level retains
  weighted articulation and the same bitmap
  art. Existing instancing and population limits remain. Empty batches are
  hidden, offscreen regiments skip sprite submission, and uploads cover only
  populated instance-buffer ranges.
- The stationary landscape is cached as half-float color plus depth. Copying
  its depth before drawing units preserves terrain and scenery occlusion.
  Camera movement, resizing, changing relief, or rebuilding the map refreshes
  it. Unsupported float-color devices fall back to direct scene rendering.
  The existing antialiased main canvas is retained; cached scenery may have
  slightly different edge antialiasing from the direct render.
- Clean paused scenes stop drawing. Orders, selection, UI changes, pointer
  input, camera movement, resizing, font loading, and model notifications wake
  rendering again. Active simulation is not frame-limited by this optimization.
- All sprite-pose shaders are compiled during map loading, before the scene
  becomes ready, rather than compiling firing poses during the first volley.
- Map disposal removes subscriptions and releases terrain BVHs, cached render
  targets, textures, geometries, and instance resources.
- Individual formation following is updated by the fixed simulation clock,
  not by render frequency. Settled groups skip steering. Moving groups use
  per-regiment spatial buckets for nearby-soldier spacing instead of comparing
  every soldier against every other soldier on the battlefield. Removed groups
  are released, and existing sprite population and draw-batch limits remain.
  This adds CPU simulation work, not textures or duplicate sprite draw batches.
  The 6x close-up zoom can select higher-detail meshes; earlier timing tables
  below are historical measurements, not approval of the new maximum zoom.

## Measurements

The controlled comparison uses headless Chromium with **SwiftShader software
rendering**, a development build, 1280x800 desktop and 390x844 mobile viewports,
and 48 animation callbacks per scenario. Frame-interval statistics exclude
the first eight callbacks. Renderer-call timing includes JavaScript work and
draw submission, not the complete asynchronous GPU workload.

Initial versus optimized stationary-camera marching measurements:

| Measurement | Before | Optimized |
| --- | ---: | ---: |
| Desktop mean renderer-call time | 49.32 ms | 8.01 ms |
| Desktop mean animation-frame interval | 503.73 ms | 160.82 ms |
| Mobile mean renderer-call time | 47.23 ms | 7.08 ms |
| Mobile mean animation-frame interval | 423.73 ms | 123.75 ms |
| Desktop triangles submitted per steady frame | 247,654 | 20,522 |

Paused idle scenes submit no new frames after settling. The triangle reduction
is about 92% in the measured view with the same 396 visible troop sprites.
Camera motion refreshes the landscape, so it does not receive that full saving.
The table uses `before.json` and `final.json`. An earlier optimized run
(`cached.json`) measured 11.85 ms desktop and 9.13 ms mobile renderer-call time;
software timing varies with host load, while the submitted geometry counts
are stable. Both optimized runs were performed without concurrent test/build
jobs.

These figures demonstrate reduced work, **not a 60 FPS or real-device smoothness
guarantee**. Software rendering remains much slower than a typical hardware GPU.
Target desktop/mobile hardware testing, including sustained combat, pan/zoom,
high-DPI screens, thermal behavior, and memory usage, is still required. The
visual-depth demo has not yet met a hardware performance approval gate.

### Subsequent Polish Check

`test-results/depth-performance/polish.json` records the updated stride meshes,
directional atlas, terrain/bridge grounding, and compact roster. The same
software-rendered marching scenarios measured 5.01 ms desktop and 4.27 ms
mobile mean renderer-call time, with 28,610 and 28,034 triangles respectively.
The extra infantry mesh boundaries add geometry relative to the first optimized
pass, but steady views remain far below the original 247,654 triangles.
Clean paused scenes still submitted no frames. Host timing varies substantially;
these results are a regression check, not an additional real-device FPS claim.
The new directional atlas adds roughly 6 MiB of texture memory and no extra
troop draw batches. Resource counts remain stable across terrain rebuilds.

## Verification

With the development server running on port 5174:

```sh
npm test
npm run test:render
npm run test:animation
npm run test:polish
node tests/depth-range-browser.mjs
npm run test:demo
PERF_LABEL=final npm run test:performance
npm run build
```

Browser scripts accept `DEMO_URL` and `PLAYWRIGHT_CHROMIUM_EXECUTABLE` overrides.
The profiler writes `test-results/depth-performance/<PERF_LABEL>.json`; the label
defaults to `current`. `PERF_SCENARIOS` can select a comma-separated subset of
`paused-desktop,march-desktop,march-mobile`. Do not run other browser suites or
build jobs concurrently with profiling.

The rendering suite compares cached and uncached canvas pixels on both maps at
desktop/mobile sizes, checks idle redraw suppression and camera wake-up,
verifies minimap/cache invalidation and mesh detail changes, and checks stable
GPU resource counts across relief rebuilds plus subscription cleanup on map
switches. Screenshots and results are written to `test-results/depth-render/`.
The initial pixel comparison differed materially at less than 0.13% of pixels,
primarily scenery edges. Animation and range suites separately verify movement,
firing/reloading, paused pixels, and the formation-edge range anchors.
