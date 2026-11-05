# UGN — Field Command

A strategy game set during the Napoleonic era, taking inspiration from Total
War and Ultimate General: Civil War. This repository includes the native
Godot game and the original playable browser prototype, with persistent army
development, real-time campaigns, and tactical battles.

## Native Godot Version

The native port is in [godot/](godot/README.md). Import `godot/project.godot`
in Godot and press F5, or use `godot/Play.cmd` on Windows. It combines the
campaign, army management, and terrain-depth experience without a browser.
The browser project and its saves are preserved separately.

The Godot project uses GDScript and Godot Shader Language. See the
[Godot setup and controls](godot/README.md) for the current Northern Italy and
Mantua campaigns, battle exercises, and launch instructions. The original
browser campaign below is a condensed, fictional Danube scenario in 1805,
with one French army and three Austrian forces.

## Repository Layout

- `godot/` — native game code, scenes, shaders, original artwork, Windows
  launchers, documentation, and tests.
- `src/`, `public/`, and `tests/` — original browser prototype and its tests.
- `feature plans/` and `docs/` — roadmaps and implementation notes.

Installations, Godot import caches, exported builds, test captures, and local
inspiration recordings are ignored by Git. A fresh clone regenerates its
Godot imports when opened in the editor; browser dependencies are installed
with `npm install`.

## Run

Node.js 20.19+ or 22.12+ is required by Vite.

```sh
npm install
npm run dev
```

Open the local URL printed by Vite, normally http://localhost:5173.

```sh
npm test
npm run build
```

The production build is written to `dist/`. Assets, including fonts, are local;
the game has no backend or runtime requests to third-party services.

## Commands

### Visual Depth Demo

Open `/?demo=depth` on the running development server for the separate visual
study. The **Campaign** and **Battlefield** tabs each keep their own in-memory
session. The normal game remains at `/`; the demo never reads or overwrites its
save. Demo progress is discarded on reload.
Browser saves are specific to the server address and port; return to the original
server address to resume a campaign saved there.

Both maps use painterly bitmap art on Three.js terrain relief, with layered
scenery, grounded unit sprites, a bounded elevated camera, and a compact HUD.
The battlefield includes gradual formations, embedded corps command, an
independent general, supply, fog, firing arcs, morale, and fatigue. The mountain
tool toggles relief for comparison. Left-click inspects/selects; right-click
moves or attacks. On touch devices, the footprint tool enables order taps.
Middle-drag or Alt-drag pans the battlefield; drag pans the campaign map.
WASD pans either map, including while paused. Q/E select I/II Corps in this
demo. Keyboard panning stops for typing, dialogs, or loss of focus.

The battlefield has a compact friendly-unit strip with morale/condition bars.
Click selects, Shift/Ctrl-click adds or removes regiments, and double-click
centers the camera. The action row above it includes formations, Run, Melee Only,
Charge, Halt, Fall Back, and Rally. Melee Only suppresses ranged fire and closes
to melee distance when an enemy is explicitly attacked.

Automatic fire keeps the current opponent while it remains visible, unobstructed,
inside weapon range, and inside the current firing arc. Idle units do not turn
or chase enemies. Engage Enemy retains an eligible current opponent or selects
the nearest visible opponent, advances into range if necessary, turns only far
enough to acquire it, then holds facing. Right-clicking an enemy orders the same
behavior against that specific opponent. A target moving outside the arc while
still in range does not trigger continuous tracking; another explicit order can
reacquire it. An explicit attack follows its target if it leaves range; Halt
cancels that pursuit. Melee weapons retain their existing circular contact range.
Both maps now allow zooming in to 6x.

Fighting and receiving fire consume condition even when stationary. Reloading
does not provide a recovery window between volleys; melee costs more than ranged
combat. Marching, wheeling, and reforming also prevent recovery. Condition starts
recovering after two simulation seconds of stationary, noncombat rest.

The original painted sprites now use instanced mesh articulation for marching,
horse gaits, formation movement, and melee reactions. Infantry and mounted
cavalry have matching firing/reload poses; guns recoil and their crews work
between shots. Individual muzzle flashes and smoke follow actual volleys.
Campaign escorts, generals, and supply horses also animate while moving.
All animation follows simulation time, including pause and 0.5x speed.
Leg poses now alternate more slowly, roughly every 1-2 seconds during ordinary
marching at 0.5x. Front/rear artwork supplements the mirrored side views as
units turn. Units stand upright rather than tilting into hills with the camera;
their projected size stays unchanged. Ground support samples the actual terrain
triangles across the full animated feet/wheel width. Foreground ridges still
occlude units normally.

Demo formations ease into and out of slower, width-dependent turns. Fatigue
reduces the turn rate, and major route changes slow forward movement until the
unit faces its path. Supply wagons and the general also turn gradually; deliberate
fallback orders still move backwards. Directional sprite changes use a small
dead band and staggered thresholds to avoid flickering or simultaneous switches
across an entire regiment. Individual soldiers now accelerate toward their own
formation positions, maintain local personal space, face their direction of
travel, and settle back into the ranks. This presentation runs on the fixed
simulation clock, including for offscreen regiments. Combat and map pathfinding
remain regimental rather than individual-soldier simulations; full eight-direction
animation is still future work. Range front edges follow the moving ranks while
maximum weapon range remains tied to the combat rules.

Demo artillery resolves a bounded, reproducible set of impact points per volley.
Range and fatigue increase spread; firearms skill reduces it. Impacts inside
the target's formation footprint contribute damage, while misses do not.
Small ground rings and dust show the resolved impacts for six simulation
seconds, with gold outlines for hits and pale outlines for misses. This is an
immediate battery-level shot abstraction, not individual projectile flight,
ricochets, or historically calibrated ballistics. Original-game artillery is
unchanged.

Rendering now uses size-based animated mesh detail, accelerated terrain picking,
and a cached landscape with depth-preserving occlusion. Paused scenes redraw
only when something changes. This keeps the painted art and combat animations
while reducing per-frame work on both maps. See [performance notes](docs/PERFORMANCE.md)
for measurements, tradeoffs, and hardware-testing limits.

This is an illustrative Italian-sector demo, not yet the researched Northern
Italy campaign. Full eight-way action frames, final historical art, hardware
performance approval, new levels/perks, and timed replacement queues remain
follow-up work. The complete roadmap is in
[feature plans](feature%20plans/visual-depth-demo-and-northern-italy-roadmap.md).

```sh
npm run dev -- --port 5174
npm run test:demo
npm run test:animation
npm run test:render
npm run test:grounding
npm run test:engagement
npm run test:performance
npm run test:polish
```

The demo browser test defaults to `http://localhost:5174/?demo=depth`; set
`DEMO_URL` to test another address. It writes screenshots and verification
results under `test-results/depth/`. Its software-rendered headless timing is
not a substitute for measuring the agreed desktop/mobile hardware.

### Original Game

The game starts paused. Time is continuous at 0.5x, 1x, 2x, or 4x.

| Action                                    | Control                                                                     |
| ----------------------------------------- | --------------------------------------------------------------------------- |
| Pause or resume                           | Play/pause button or Space                                                  |
| Change speed                              | Speed buttons; 0 for 0.5x, or 1, 2, 3 for 1x, 2x, 4x                        |
| March on the campaign map                 | Click a destination                                                         |
| Intercept the nearest enemy               | Crosshair button beside the march status                                    |
| Select a regiment                         | Click its soldiers or bottom regiment card                                  |
| Select multiple regiments                 | Shift-click or drag a box on the battlefield                                |
| Select the whole army                     | Group button or A during battle                                             |
| Select I / II Corps                       | Corps buttons or Q / W                                                      |
| Select the army general                   | Crown button or G during battle                                             |
| Select a corps commander                  | Officer button beside its corps, or its field marker                        |
| Rally nearby troops                       | Flag button or R with a commander selected                                  |
| Return a commander to automatic following | Navigation button                                                           |
| Move selected regiments                   | Click open ground, or right-click                                           |
| Queue movement waypoints                  | Shift-click successive destinations                                         |
| Draw a frontline                          | L / frontline tool, then drag; or right-drag with multiple regiments        |
| Move with a final facing                  | Right-drag from the destination toward the desired facing with one regiment |
| Deploy before battle begins               | Deployment pin, then click inside the friendly deployment zone              |
| Double time                               | Gauge button or V                                                           |
| Fall back facing the enemy                | Return-arrow button or F                                                    |
| Detach / recall skirmishers               | Split / merge button; recall within 90 m of the parent                      |
| Limber / unlimber artillery               | Artillery wagon button; preparation takes five seconds                      |
| Dismount / mount carbine cavalry          | Dismount button, with carbines equipped                                     |
| Select the supply train                   | Wagon in the command strip or T, then click to move                         |
| Send campaign scouts                      | Binoculars button; 100 francs, 45 simulation seconds, 90-second cooldown    |
| Attack a particular enemy                 | Click the enemy formation                                                   |
| Halt and hold position                    | Shield button or H                                                          |
| Line, column, square                      | Formation buttons during battle                                             |
| Hold or resume ranged fire                | Hold-fire button                                                            |
| Charge                                    | Crossed-swords button during battle                                         |
| Withdraw                                  | Left-arrow button during battle, then confirm                               |
| Pan                                       | Drag on campaign; Alt-drag or middle-drag in battle                         |
| Touch controls                            | Tap to select/order; drag to pan in either map                              |
| Zoom                                      | Mouse wheel or plus/minus buttons                                           |
| Recenter                                  | Center-map button or click the minimap                                      |
| Manage regiments and weapons              | Army camp in the top bar                                                    |
| Sound                                     | Speaker toggle; hover or focus to adjust volume                             |

Orders can be issued while paused. Formation changes take simulation time:
column takes 6 seconds, line 8 seconds, and square 12 seconds before experience,
morale, and commander effects. Soldiers visibly reform, move at reduced speed,
cannot shoot or charge while reforming, and are more vulnerable to incoming
attacks. Issuing another formation order queues it behind the current change;
it does not instantly reverse or restart the animation. Pause freezes progress.

Infantry and artillery stop to fire; units
automatically engage enemies in range. March columns move faster but have less
firepower; squares resist cavalry. Woods slow movement and reduce incoming fire,
high ground improves outgoing fire, and attacks from behind increase losses and
morale damage. These are deliberately simplified prototype combat rules.

Units turn gradually, and ranged weapons need to face their targets. Hold fire
suppresses ranged volleys while allowing units to defend themselves in melee.
Regiment cards show formation progress, current orders, and command support;
selected-unit details show inflicted casualties and reload time.

## Chain Of Command

Napoleon commands the army. Each of the two corps has its own mounted field
commander and can contain up to four regiments, with an eight-regiment army
limit. Corps buttons select their assigned troops for group orders. In camp,
the full-screen Army headquarters unifies the army and command views. It shows
both corps, their officers, four regiment positions each, and a persistent detail
panel. Transfer regiments by dragging to another corps or using the detail panel.
Full destinations are disabled. New regiments join a corps with a vacant slot.

The general supports all French regiments within 220 m. Corps commanders
support only their own regiments within 175 m. Officers follow their troops
by default but can be selected and moved or halted independently. Their command
radii are visible when selected. They are support characters and are not included
in fighting strengths or victory calculations.

Nearby command reduces morale damage and restores morale gradually. I Corps'
drill specialist accelerates formation changes by 20%; II Corps' resolve
specialist improves morale recovery. Rally restores up to 18 morale to eligible
troops within command range, then needs 45 simulation seconds to recover.
Routed regiments with enough survivors can rally when enemies are not close.
Enemy proximity forces officers back and temporarily disables their support.

The Officers view supports paid recruitment and reassignment. Officers gain
service experience and automatically advance through five ranks, which affect
regiment command capacity and efficiency. An assigned officer can be wounded or
killed after heavy losses; wounded officers recover after eight campaign hours.
Unavailable or vacant commands reduce effectiveness. Officers are assigned to
only one command at a time; reassigning one leaves their old command vacant.

Regiments have firearms, melee, stamina, and discipline skills, paid training,
one veteran distinction, a configurable authorized strength, and a service
record. The Armory combines illustrated weapon patterns, reserve and dealer
stocks, custom trading quantities, comparisons, and equipment assignment.

The camera now supports a wider overview with painted terrain extending beyond
the dashed operational boundary. Zoom and panning are bounded by the rendered
terrain at each viewport size, so they do not expose the canvas background.

## Campaign Loop

The campaign pauses when armies meet, allowing deployment orders before battle
time resumes. Nearby Austrian armies can join the same battle as delayed
reinforcements. No campaign time passes while fighting a tactical battle.

Victory removes the defeated campaign army and awards money and captured
muskets. Surviving regiments retain their casualties and gain experience.
Defeat or voluntary withdrawal returns survivors to Ulm without a victory
payment. The enemy retains its surviving strength.
After-action returns list each regiment's losses, inflicted casualties, and
experience, together with officer promotions, wounds, and deaths.

In camp, buy and sell reserve weapons, issue compatible weapons to whole
regiments, and spend money and reserve arms to replace casualties. Recruit
replacements cost two francs per man and dilute skills and experience; veterans
cost six francs and preserve them. New 400-man infantry regiments cost 1,200
francs and 400 muskets. Cavalry and artillery can also be recruited, within the
same eight-regiment army limit.
Weapon-market quantities can be edited per weapon instead of using fixed lots.

The campaign autosaves to this browser's local storage, including ongoing
battles. Reloading resumes paused. The new-campaign button requires confirmation
before replacing the save. Clearing browser data removes the save.
Save schemas 1 and 2 migrate automatically to schema 3, including ongoing
battles. Formation orders, waypoints, corps assignments, officers, ammunition,
condition, supply wagons, rally recovery, and sound settings are retained.

## Battlefield Systems

Encounters choose village capture, bridge assault, or ridge defense based on
campaign location. Each uses different forests, hills, roads, and objectives.
Units and wagons route through the bridge rather than across open water.
Occupying an uncontested objective accumulates control time; either side can win
by meeting its control threshold or routing all opposing combat regiments.

Fog of war hides enemies outside friendly sight. Woodland depth and intervening
high ground block sight and firing; friendly troops can obstruct a volley.
Enemy AI advances on objectives, holds an early reserve, flanks with cavalry,
repositions obstructed units, and withdraws to recover condition or ammunition.

Moving, running, charging, and fighting consume condition. Rest restores it;
long campaign marches also tire the army. Ammunition is finite. A separate,
movable supply train distributes stores within 145 m and can be destroyed by
nearby enemy troops. Its losses and remaining ammunition persist after battle;
resupply is purchased in headquarters. Artillery automatically uses stronger
close-range canister damage. Carbine cavalry can fight dismounted.

Infantry can detach 20% of its strength as loose-order skirmishers. They move
faster, take less ranged damage, and evade close enemies. Detached survivors,
ammunition, and casualties merge back into their regiment after battle. They
do not occupy an additional corps position.

Battle sounds are synthesized locally with Web Audio, with separate musket,
cannon, order, and marching sounds. Browser audio starts after an interaction;
sound is optional and has its own volume control.

## Verification

The model tests cover formation timing and interpolation, command support,
corps capacity, rally recovery, old-save migration, real-time movement, bridge pathfinding, automatic encounters,
trade and equipment accounting, recruitment, casualties, one-time battle rewards,
reinforcements, withdrawal, and save restoration.

For browser verification, keep the Vite server running and install Chromium:

```sh
npx playwright install chromium
npm run test:browser
EXPANSION_ONLY=1 npm run test:browser
```

Linux may also need Playwright's system dependencies (`npx playwright install-deps
chromium`). The browser script supports `GAME_URL` and
`PLAYWRIGHT_CHROMIUM_EXECUTABLE` overrides. It checks the complete campaign/battle/
camp loop, rendering pixels at every map edge under extreme zoom and panning,
and desktop/tablet/mobile/ultrawide layouts. The expansion pass additionally
checks headquarters tabs at four widths, specialist controls, and all three
battlefield textures. The simulation suite includes progression, ammunition
conservation, sight obstruction, objective control, and bridge routing. Screenshots are
written to the ignored `test-results/` directory. Browser tests use a development
build; the inspection hook is not present in production.

## Implementation And Scope

- React for the command interface and headquarters.
- Phaser for the game loop, cameras, rendering, and input.
- PathFinding.js A* for campaign routes and bridge crossings.
- A deterministic simulation in `src/game/model.js` and `src/game/tactics.js`, independent of the renderer.
- Original generated terrain art and procedural map, troop, and effects layers.

This is a small prototype, not a full historical simulator or a recreation of
Ultimate General's engine. There are three reusable tactical maps and simplified
enemy AI, not a long scripted historical campaign or a full military simulation.
Scouting, logistics, ballistics, command, and officer casualties are abstractions.
There is no diplomacy, national economy, multiplayer, cloud save, or historically
accurate order of battle. Terrain and weapon statistics are gameplay values;
some related weapon patterns share a representative illustration.

Art generation provenance and prompts are recorded in `docs/ASSETS.md`.


codex resume 01a07d06-c28f-7f72-bdde-6b9ec06387ca
